
FROM eclipse-temurin:17-jre
ARG JAR=target/mzv-service-0.1.0.jar
WORKDIR /app
COPY ${JAR} app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
