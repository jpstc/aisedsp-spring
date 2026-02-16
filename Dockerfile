
FROM eclipse-temurin:17-jre
ARG JAR=target/stc-cdbp-0.1.0.jar
WORKDIR /app
COPY ${JAR} app.jar
EXPOSE 8081
ENTRYPOINT ["java","-jar","/app/app.jar"]
