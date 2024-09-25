FROM registry.cloudogu.com/official/java:17.0.12-3 as base

ENV SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    SONAR_VERSION=9.9.5.90363 \
    CAS_PLUGIN_VERSION=5.0.2 \
    STARTUP_DIR="/"

FROM base as builder

ENV SONARQUBE_ZIP_SHA256=17b6cfab23fcd2e74b9c44aae6455a24eff3ba990a35a14ca186ded1411eefd3 \
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

FROM base

LABEL NAME="official/sonar" \
    VERSION="9.9.5-4" \
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
