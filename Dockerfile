FROM registry.cloudogu.com/official/java:17.0.6-1 as BASE

ENV SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    SONAR_VERSION=9.9.1.69595 \
    CAS_PLUGIN_VERSION=5.0.2 \
    STARTUP_DIR="/"

FROM BASE as builder

ENV SONARQUBE_ZIP_SHA256=40bb45f551c7959ba1d3a5ff7b5432a558a5b2ad2efa5e9e1fcf52b83142897b \
    CAS_PLUGIN_JAR_SHA256=82f9fd7f65c9ce255f4f1dd6649a65a1f7eaf2acbc6a54f2c8103cbc2a42010f \
    BUILDER_HOME="/builder/sonar"

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
    VERSION="9.9.1-3" \
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
