FROM registry.cloudogu.com/official/java:8u212-1

LABEL NAME="official/sonar" \
    VERSION="6.7.7-1" \
    maintainer="robert.auer@cloudogu.com"

ENV SONAR_VERSION=6.7.7 \
    SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    CAS_PLUGIN_VERSION=1.0.5

RUN set -x \
    && apk add --no-cache procps postgresql-client \
    && mkdir -p /opt \
    && cd /tmp \
    && rm -rf /var/cache/apk/* \
    # get SonarQube
    && curl --fail --remote-name --location https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip \
    && unzip sonarqube-${SONAR_VERSION}.zip \
    && mv sonarqube-${SONAR_VERSION} ${SONARQUBE_HOME} \
    # get sonar-cas-plugin
    # will be moved to correct ${SONARQUBE_HOME}/extensions/plugins/ folder in startup.sh
    && curl --fail --location https://github.com/cloudogu/sonar-cas-plugin/releases/download/v${CAS_PLUGIN_VERSION}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar --output ${SONARQUBE_HOME}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar \
    # create sonar user
    && addgroup -S -g 1000 sonar \
    && adduser -S -h "$SONARQUBE_HOME" -s /bin/bash -G sonar -u 1000 sonar

COPY ./resources /

RUN chown -R sonar:sonar ${SONARQUBE_HOME}

EXPOSE 9000

USER sonar

HEALTHCHECK CMD [ $(curl --silent --fail -u sonarqubedoguadmin:$(doguctl config -e dogu_admin_password) http://localhost:9000/sonar/api/system/health | jq -r '.health') = "GREEN" ] && [ $(doguctl state) == "ready" ] && [ $(doguctl healthy sonar; EXIT_CODE=$?; echo ${EXIT_CODE}) == 0 ]

CMD ["/startup.sh"]
