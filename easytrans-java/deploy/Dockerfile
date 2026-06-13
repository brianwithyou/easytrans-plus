FROM maven:3.9.16-eclipse-temurin-25 AS build

WORKDIR /workspace

# 国内 Maven 镜像，加速依赖下载
COPY deploy/maven/settings.xml /root/.m2/settings.xml

# 先只复制 pom，缓存依赖层
COPY pom.xml .
RUN mvn -B -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -B -DskipTests package

FROM eclipse-temurin:25-jre-jammy

WORKDIR /app
RUN useradd --system --create-home --home-dir /app --shell /usr/sbin/nologin easytrans \
    && mkdir -p /app/logs \
    && apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/target/easytrans-java-*.jar /app/app.jar
RUN chown -R easytrans:easytrans /app

USER easytrans
EXPOSE 9091

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS http://127.0.0.1:9091/api/v1/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
