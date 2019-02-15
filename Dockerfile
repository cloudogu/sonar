FROM registry.cloudogu.com/official/java:8u171-1

LABEL NAME="official/sonar" \
    VERSION="5.6.7-2" \
    maintainer="sebastian.sdorra@cloudogu.com"

ENV SONAR_VERSION=6.7.6 \
    SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp

RUN set -x \
    && apk add --no-cache procps postgresql-client \
    && mkdir /opt \
    && cd /tmp \
    && curl -L -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip \
    && unzip sonarqube-${SONAR_VERSION}.zip \
    && mv sonarqube-${SONAR_VERSION} ${SONARQUBE_HOME} \
    && rm -rf /var/cache/apk/* \
    # create sonar user
    && addgroup -S -g 1000 sonar \
    && adduser -S -h "$SONARQUBE_HOME" -s /bin/bash -G sonar -u 1000 sonar

COPY ./resources /

RUN chown -R sonar:sonar ${SONARQUBE_HOME}

EXPOSE 9000

USER sonar

CMD ["/startup.sh"]
