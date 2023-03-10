FROM registry.cloudogu.com/official/java:17.0.6-1

LABEL NAME="official/sonar" \
    VERSION="8.9.8-2" \
    maintainer="hello@cloudogu.com"

ENV SONAR_VERSION=9.9.0.65466 \
    SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    CAS_PLUGIN_VERSION=4.2.1 \
    SONARQUBE_ZIP_SHA256=f5b3045ac40b99dfc2ab45c0990074f4b15e426bdb91533d77f3b94b73d3d411 \
    CAS_PLUGIN_JAR_SHA256=9b78f59f2c58221ea79a0b161bc2a9ed77ad5202bc615750cce1be7540bc2c8c \
    STARTUP_DIR="/"

RUN set -e \
    && apk update \
    && apk upgrade \
    && apk add --no-cache procps postgresql14-client \
    && mkdir -p /opt \
    && cd /tmp \
    && rm -rf /var/cache/apk/* \
    # get SonarQube
    && curl --fail --remote-name --location https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip \
    && echo "${SONARQUBE_ZIP_SHA256} *sonarqube-${SONAR_VERSION}.zip" | sha256sum -c - \
    && unzip sonarqube-${SONAR_VERSION}.zip \
    && rm sonarqube-${SONAR_VERSION}.zip \
    && mv sonarqube-${SONAR_VERSION} ${SONARQUBE_HOME} \
    # get sonar-cas-plugin
    # will be moved to correct ${SONARQUBE_HOME}/extensions/plugins/ folder in startup.sh
    && curl --fail --location https://github.com/cloudogu/sonar-cas-plugin/releases/download/v${CAS_PLUGIN_VERSION}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar --output ${SONARQUBE_HOME}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar \
    && echo "${CAS_PLUGIN_JAR_SHA256} *${SONARQUBE_HOME}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar" | sha256sum -c - \
    # create sonar user
    && mkdir -p /opt/sonar/lib/common \
    && addgroup -S -g 1000 sonar \
    && adduser -S -h "$SONARQUBE_HOME" -s /bin/bash -G sonar -u 1000 sonar \
    && chown -R sonar:sonar ${SONARQUBE_HOME}

COPY --chown=1000:1000 ./resources /

EXPOSE 9000

USER sonar

HEALTHCHECK CMD doguctl healthy sonar || exit 1

CMD ["/startup.sh"]
