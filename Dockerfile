FROM registry.cloudogu.com/official/java:17.0.13-1 as base

ENV SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    SONAR_VERSION=9.9.8.100196 \
    CAS_PLUGIN_VERSION=5.1.0 \
    STARTUP_DIR="/"

FROM base as builder

ENV SONARQUBE_ZIP_SHA256=07d9100c95e5c19f1785c0e9ffc7c8973ce3069a568d2500146a5111b6e966cd \
    CAS_PLUGIN_JAR_SHA256=67a127a4f8fd247b2f2c84869d62d960c97fb546083a79fbac637163123490a2 \
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
    VERSION="9.9.8-1" \
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
RUN mkdir -p /trivy/output

EXPOSE 9000

USER sonar

HEALTHCHECK CMD doguctl healthy sonar || exit 1

CMD ["/startup.sh"]
