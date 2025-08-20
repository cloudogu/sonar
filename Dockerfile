FROM golang:1.24.5 AS compiler
WORKDIR /app
ADD sonarcarp /app
COPY build /app/build
COPY Makefile .

RUN make vendor compile-generic
RUN chmod 0744 /app/target/sonarcarp

FROM registry.cloudogu.com/official/java:17.0.13-1 AS base

ENV SONARQUBE_HOME=/opt/sonar \
    # mark as webapp for nginx
    SERVICE_TAGS=webapp \
    SONAR_VERSION=25.1.0.102122 \
    STARTUP_DIR="/"

FROM base AS builder

ENV SONARQUBE_ZIP_SHA256=1b37a6d6f882e32208620597706ee336e9a3495acff826421475618dc747feba \
    BUILDER_HOME="/builder/sonar"

WORKDIR /builder

RUN apk --update add build-base curl unzip
RUN curl --fail --remote-name --location https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip
RUN echo "${SONARQUBE_ZIP_SHA256} *sonarqube-${SONAR_VERSION}.zip" | sha256sum -c -
RUN unzip sonarqube-${SONAR_VERSION}.zip
RUN mv sonarqube-${SONAR_VERSION} ${BUILDER_HOME}
RUN rm sonarqube-${SONAR_VERSION}.zip

FROM base

LABEL NAME="official/sonar" \
    VERSION="25.1.0-5" \
    maintainer="hello@cloudogu.com"

RUN set -eux \
    && apk update \
    && apk upgrade \
    && apk add --no-cache procps postgresql14-client curl uuidgen \
    && mkdir -p /opt \
    && mkdir -p /carp \
    && rm -rf /var/cache/apk/* \
    && mkdir -p /opt/sonar/lib/common \
    && addgroup -S -g 1000 sonar \
    && adduser -S -h "$SONARQUBE_HOME" -s /bin/bash -G sonar -u 1000 sonar \
    && chown -R sonar:sonar ${SONARQUBE_HOME} /carp

COPY --from=builder --chown=1000:1000 /builder/sonar ${SONARQUBE_HOME}
COPY --chown=1000:1000 ./resources /
COPY --from=compiler --chown=1000:1000 /app/target/sonarcarp /carp/sonarcarp

EXPOSE 8080

USER sonar

HEALTHCHECK CMD doguctl healthy sonar || exit 1

CMD ["/startup.sh"]
