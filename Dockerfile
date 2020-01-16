FROM registry.cloudogu.com/official/java:11.0.4-2

LABEL NAME="official/sonar" \
    VERSION="7.9.1-2" \
    maintainer="robert.auer@cloudogu.com"

ENV SONAR_VERSION=7.9.1 \
    SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    CAS_PLUGIN_VERSION=2.0.1 \
    SONARQUBE_ZIP_SHA256=67f3ccae79245397480b0947d7a0b5661dc650b87f368b39365044ebcc88ada0 \
    CAS_PLUGIN_JAR_SHA256=c0df47e82e888d44b5e08bb407f6f2c95ae5b64ed53fa8526db4b387da071acc

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
    && adduser -S -h "$SONARQUBE_HOME" -s /bin/bash -G sonar -u 1000 sonar

COPY ./resources /

RUN chown -R sonar:sonar ${SONARQUBE_HOME}

EXPOSE 9000

USER sonar

HEALTHCHECK CMD [ $(doguctl healthy sonar; echo $?) == 0 ]

CMD ["/startup.sh"]
