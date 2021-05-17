FROM registry.cloudogu.com/official/java:11.0.5-4

LABEL NAME="official/sonar" \
    VERSION="7.9.4-4" \
    maintainer="hello@cloudogu.com"

ENV SONAR_VERSION=8.9.0.43852 \
    SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    CAS_PLUGIN_VERSION=2.0.1 \
    SONARQUBE_ZIP_SHA256=6facb9d373b0ba32b188704883ecb792135474681cb2d05ce027918a41d04623 \
    CAS_PLUGIN_JAR_SHA256=c0df47e82e888d44b5e08bb407f6f2c95ae5b64ed53fa8526db4b387da071acc \
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
    && mv sonarqube-${SONAR_VERSION} ${SONARQUBE_HOME} \
    # get sonar-cas-plugin
    # will be moved to correct ${SONARQUBE_HOME}/extensions/plugins/ folder in startup.sh
    && curl --fail --location https://github.com/cloudogu/sonar-cas-plugin/releases/download/v${CAS_PLUGIN_VERSION}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar --output ${SONARQUBE_HOME}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar \
    && echo "${CAS_PLUGIN_JAR_SHA256} *${SONARQUBE_HOME}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar" | sha256sum -c - \
    # create sonar user
    && addgroup -S -g 1000 sonar \
    && adduser -S -h "$SONARQUBE_HOME" -s /bin/bash -G sonar -u 1000 sonar \
    && chown -R sonar:sonar ${SONARQUBE_HOME}

COPY --chown=1000:1000 ./resources /

EXPOSE 9000

USER sonar

HEALTHCHECK CMD doguctl healthy sonar || exit 1

CMD ["/startup.sh"]
