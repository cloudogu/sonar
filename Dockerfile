FROM registry.cloudogu.com/official/java:11.0.18-1 as BASE

ENV SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    SONAR_VERSION=8.9.8.54436 \
    CAS_PLUGIN_VERSION=4.2.1 \
    STARTUP_DIR="/"

FROM BASE as builder

ENV SONARQUBE_ZIP_SHA256=a491240b2066222680d9770c6da4d5f0cf9873c86e0d0e3fbe4d1383bbf3ce85 \
    CAS_PLUGIN_JAR_SHA256=9b78f59f2c58221ea79a0b161bc2a9ed77ad5202bc615750cce1be7540bc2c8c
ENV BUILDER_HOME="/builder/sonar"

WORKDIR /builder

RUN apk --update add build-base curl unzip
RUN curl --fail --remote-name --location https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip
RUN echo "${SONARQUBE_ZIP_SHA256} *sonarqube-${SONAR_VERSION}.zip" | sha256sum -c -
RUN unzip sonarqube-${SONAR_VERSION}.zip
RUN mv sonarqube-${SONAR_VERSION} ${BUILDER_HOME}
RUN rm sonarqube-${SONAR_VERSION}.zip
RUN curl --fail --location "https://github.com/cloudogu/sonar-cas-plugin/releases/download/v${CAS_PLUGIN_VERSION}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar" --output "${BUILDER_HOME}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar"
RUN echo "${CAS_PLUGIN_JAR_SHA256} *${BUILDER_HOME}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar" | sha256sum -c -

FROM BASE

LABEL NAME="official/sonar" \
    VERSION="8.9.8-2" \
    maintainer="hello@cloudogu.com"

RUN set -eux \
    && apk update \
    && apk upgrade \
    && apk add --no-cache procps postgresql14-client curl \
    && mkdir -p /opt \
    && rm -rf /var/cache/apk/* \
    && mkdir -p /opt/sonar/lib/common \
    && addgroup -S -g 1000 sonar \
    && adduser -S -h "$SONARQUBE_HOME" -s /bin/bash -G sonar -u 1000 sonar \
    && chown -R sonar:sonar ${SONARQUBE_HOME}

COPY --from=builder --chown=1000:1000 /builder/sonar ${SONARQUBE_HOME}
COPY --chown=1000:1000 ./resources /

EXPOSE 9000

USER sonar

HEALTHCHECK CMD doguctl healthy sonar || exit 1

CMD ["/startup.sh"]
