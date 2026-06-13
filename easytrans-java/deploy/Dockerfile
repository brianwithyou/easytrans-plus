FROM maven:3.9.16-eclipse-temurin-25 AS build

WORKDIR /workspace
COPY pom.xml .
COPY src ./src

RUN mvn -q -DskipTests package

FROM eclipse-temurin:25-jre-jammy

WORKDIR /app
RUN useradd --system --create-home --home-dir /app --shell /usr/sbin/nologin easytrans \
    && apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/target/easytrans-java-*.jar /app/app.jar
RUN chown easytrans:easytrans /app/app.jar

USER easytrans
EXPOSE 9091

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS http://127.0.0.1:9091/api/v1/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
