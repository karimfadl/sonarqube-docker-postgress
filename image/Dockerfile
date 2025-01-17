# Stage 1: Build the plugin
FROM gradle:8.5-jdk17-alpine AS builder

COPY . /home/build/project
WORKDIR /home/build/project
RUN gradle build -x test

# Stage 2: SonarQube with Plugin
FROM sonarqube:10.3-community

# Copy the built plugin
COPY --from=builder --chown=sonarqube:sonarqube /home/build/project/build/libs/sonarqube-community-branch-plugin-*.jar /opt/sonarqube/extensions/plugins/

# Environment Variables
ENV PLUGIN_VERSION=1.19.0-SNAPSHOT
ENV SONAR_WEB_JAVAADDITIONALOPTS="-javaagent:./extensions/plugins/sonarqube-community-branch-plugin-${PLUGIN_VERSION}.jar=web"
ENV SONAR_CE_JAVAADDITIONALOPTS="-javaagent:./extensions/plugins/sonarqube-community-branch-plugin-${PLUGIN_VERSION}.jar=ce"
