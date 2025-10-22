ARG STAGE=prod
ARG BASE_IMAGE=registry.cloudogu.com/official/java:17.0.13-1

ARG SONAR_VERSION=25.1.0.102122
ARG SONARQUBE_ZIP_SHA256=1b37a6d6f882e32208620597706ee336e9a3495acff826421475618dc747feba

FROM golang:1.24.5 AS compiler-prod
WORKDIR /app
COPY sonarcarp /app
COPY build /app/build
# there is a go-specific Makefile in sonarcarp. we only need the other makefile includes.

RUN make vendor compile-generic

FROM golang:1.25.2-alpine3.21 AS compiler-debug
WORKDIR /app
COPY sonarcarp /app

RUN go install -ldflags "-s -w -extldflags '-static'" github.com/go-delve/delve/cmd/dlv@latest
RUN CGO_ENABLED=0 go build -gcflags "all=-N -l" -o /app/target/sonarcarp

FROM ${BASE_IMAGE} AS builder

ARG SONAR_VERSION
ARG SONARQUBE_ZIP_SHA256

ENV BUILDER_HOME="/builder/sonar"

WORKDIR /builder

RUN apk --update add build-base curl unzip
RUN curl --fail --remote-name --location https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip
RUN echo "${SONARQUBE_ZIP_SHA256} *sonarqube-${SONAR_VERSION}.zip" | sha256sum -c -
RUN unzip sonarqube-${SONAR_VERSION}.zip
RUN mv sonarqube-${SONAR_VERSION} ${BUILDER_HOME}
RUN rm sonarqube-${SONAR_VERSION}.zip

FROM ${BASE_IMAGE} AS base

LABEL NAME="official/sonar" \
    VERSION="25.1.0-5" \
    maintainer="hello@cloudogu.com"

ARG SONAR_VERSION

ENV SONARQUBE_HOME=/opt/sonar \
    SERVICE_TAGS=webapp \
    SONAR_VERSION=${SONAR_VERSION} \
    STARTUP_DIR="/"

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
