ARG STAGE=prod
ARG BASE_IMAGE=registry.cloudogu.com/official/java:21.0.12-2

ARG SONAR_BASE_VERSION=26.2.0
ARG SONAR_VERSION=${SONAR_BASE_VERSION}.119303
ARG SONARQUBE_ZIP_SHA256=601367a97dfacf7d0ba54e23ea54d77bdeef548cd1b5a7f2378a83eea931efa1
ARG SONARQUBE_COMMUNITY_WEBAPP_ZIP_SHA256=17722659cbc27e6ee9147afdd93e22202e2899cbaa39650d3dcc5df30cdc1d11

FROM golang:1.27.2 AS compiler-prod
WORKDIR /app
COPY sonarcarp /app
COPY build /app/build
# there is a go-specific Makefile in sonarcarp. we only need the other makefile includes.

RUN make vendor compile-generic

FROM golang:1.27.2-alpine3.23 AS compiler-debug
WORKDIR /app
COPY sonarcarp /app

RUN go install -ldflags "-s -w -extldflags '-static'" github.com/go-delve/delve/cmd/dlv@latest
RUN CGO_ENABLED=0 go build -gcflags "all=-N -l" -o /app/target/sonarcarp

FROM ${BASE_IMAGE} AS builder

ARG SONAR_BASE_VERSION
ARG SONAR_VERSION
ARG SONARQUBE_ZIP_SHA256
ARG SONARQUBE_COMMUNITY_WEBAPP_ZIP_SHA256

ENV BUILDER_HOME="/builder/sonar"
ENV BUILDER_WEBAPP="/builder/webapp"

WORKDIR /builder

RUN apk --update add build-base curl unzip
RUN curl --fail --remote-name --location https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip
RUN echo "${SONARQUBE_ZIP_SHA256} *sonarqube-${SONAR_VERSION}.zip" | sha256sum -c -
RUN unzip sonarqube-${SONAR_VERSION}.zip
RUN mv sonarqube-${SONAR_VERSION} ${BUILDER_HOME}
RUN rm sonarqube-${SONAR_VERSION}.zip
RUN curl --fail --output sonarqube-webapp-${SONAR_BASE_VERSION}.zip --location https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/${SONAR_BASE_VERSION}/sonarqube-webapp.zip
RUN echo "${SONARQUBE_COMMUNITY_WEBAPP_ZIP_SHA256} *sonarqube-webapp-${SONAR_BASE_VERSION}.zip" | sha256sum -c -
RUN unzip sonarqube-webapp-${SONAR_BASE_VERSION}.zip -d sonarqube-webapp-${SONAR_BASE_VERSION}
RUN mv sonarqube-webapp-${SONAR_BASE_VERSION} ${BUILDER_WEBAPP}
RUN rm sonarqube-webapp-${SONAR_BASE_VERSION}.zip


FROM ${BASE_IMAGE} AS base

LABEL NAME="official/sonar" \
    VERSION="26.2.0-0" \
    maintainer="hello@cloudogu.com"

ARG SONAR_VERSION

ENV SONARQUBE_HOME=/opt/sonar \
    SERVICE_TAGS=webapp \
    SONAR_VERSION=${SONAR_VERSION} \
    STARTUP_DIR="/"

RUN set -eux \
    && apk update \
    && apk upgrade \
    # temporarily add old repo
    && echo "https://dl-cdn.alpinelinux.org/alpine/v3.20/main" > /tmp/old-repos \
    && echo "https://dl-cdn.alpinelinux.org/alpine/v3.20/community" >> /tmp/old-repos \
    \
    && apk add --no-cache --repositories-file=/tmp/old-repos postgresql14-client \
    \
    # cleanup
    && rm -f /tmp/old-repos \
    && apk add --no-cache procps postgresql14-client curl uuidgen libstdc++ \
    && mkdir -p /opt \
    && mkdir -p /carp \
    && rm -rf /var/cache/apk/* \
    && mkdir -p /opt/sonar/lib/common \
    && addgroup -S -g 1000 sonar \
    && adduser -S -h "$SONARQUBE_HOME" -s /bin/bash -G sonar -u 1000 sonar \
    && chown -R sonar:sonar ${SONARQUBE_HOME} /carp

COPY --from=builder --chown=1000:1000 /builder/sonar ${SONARQUBE_HOME}
COPY --from=builder --chown=1000:1000 /builder/webapp /opt/sonar/web.community
COPY --chown=1000:1000 ./resources /


FROM base AS debug

ENV STAGE=DEBUG

COPY --from=compiler-debug --chown=1000:1000 /go/bin/dlv /carp/dlv
COPY --from=compiler-debug --chown=1000:1000 /app/target/sonarcarp /carp/sonarcarp


FROM base AS prod

COPY --from=compiler-prod --chown=1000:1000 /app/target/sonarcarp /carp/sonarcarp


FROM ${STAGE} AS final

RUN chmod 0744 /carp/sonarcarp

EXPOSE 8080

USER sonar

HEALTHCHECK CMD doguctl healthy sonar || exit 1

CMD ["/startup.sh"]
