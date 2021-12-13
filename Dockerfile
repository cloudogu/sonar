FROM registry.cloudogu.com/official/java:11.0.11-2

LABEL NAME="official/sonar" \
    VERSION="8.9.2-2" \
    maintainer="hello@cloudogu.com"

ENV SONAR_VERSION=8.9.2.46101 \
    SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    CAS_PLUGIN_VERSION=4.2.0 \
    SONARQUBE_ZIP_SHA256=53389fcd52c24c6cd18dda5857863c16108b3a274eae9ab3a51080dfb6f1df1a \
    CAS_PLUGIN_JAR_SHA256=0245e7edf9bf82a3f2cae6e0e17bb204fc4fbf69174f7c6864925daaf7bcc2d3 \
    STARTUP_DIR="/"

RUN set -x \
    && apk add --no-cache procps postgresql-client \
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
