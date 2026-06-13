# syntax=docker/dockerfile:1
FROM maven:3.9.16-eclipse-temurin-25 AS build

WORKDIR /workspace

# 国内 Maven 镜像，加速依赖下载
COPY deploy/maven/settings.xml /root/.m2/settings.xml

# 先只复制 pom，缓存依赖层
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2/repository \
    mvn -B -DskipTests dependency:go-offline

COPY src ./src
RUN --mount=type=cache,target=/root/.m2/repository \
    mvn -B -DskipTests package

FROM eclipse-temurin:25-jre-jammy

WORKDIR /app
RUN groupadd --system --gid 10001 easytrans \
    && useradd --system --uid 10001 --gid easytrans --create-home --home-dir /app --shell /usr/sbin/nologin easytrans \
    && mkdir -p /app/logs \
    && apt-get update \
    && apt-get install -y --no-install-recommends curl gosu \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/target/easytrans-java-*.jar /app/app.jar
COPY deploy/docker-entrypoint.sh /docker-entrypoint.sh
RUN chown -R easytrans:easytrans /app \
    && chmod +x /docker-entrypoint.sh

EXPOSE 9091

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS http://127.0.0.1:9091/api/v1/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
