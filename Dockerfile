# -------------------------------
# Stage 1: Build the Application
# -------------------------------

# Use official Maven image with Eclipse Temurin JDK 21 installed.
# This image contains:
# - Maven (to build the project)
# - Java JDK 21 (required for compilation)
FROM maven:3.9.6-eclipse-temurin-21 AS build

# Set working directory inside container as /app
# All next commands will run from this path.
WORKDIR /app

# Copy all project files from local machine to container.
# Includes:
# - pom.xml
# - src/
# - mvnw (if available)
# - other project files
COPY . .

# Run Maven build command:
# clean      -> removes previous build files
# package    -> compiles code and creates JAR file
# -DskipTests -> skips unit/integration tests for faster build
RUN mvn clean package -DskipTests


# -------------------------------
# Stage 2: Run the Application
# -------------------------------

# Use lightweight Java Runtime image only.
# This image contains JRE (Java Runtime Environment),
# enough to run the application but not build it.
# Smaller than Maven/JDK image.
FROM eclipse-temurin:21-jre

# Set working directory for runtime container
WORKDIR /app

# Copy generated JAR file from build stage to runtime stage.
# Source:
# /app/target/*.jar  (from build container)
# Destination:
# /app/app.jar       (inside runtime container)
COPY --from=build /app/target/*.jar app.jar

# Inform Docker that application uses port 8080
# (Spring Boot default port)
EXPOSE 8080

# Start the Spring Boot application
# java -jar app.jar runs executable JAR file
CMD ["java","-jar","app.jar"]

