ARG STAGE=prod
ARG BASE_IMAGE=registry.cloudogu.com/official/java:21.0.10-3

ARG SONAR_VERSION=25.12.0.117093
ARG SONARQUBE_ZIP_SHA256=09215f6f6a56db484946e4355c9801fa357eb92eedc99a2bebedf1d7ae21a341

FROM golang:1.26.0 AS compiler-prod
WORKDIR /app
COPY sonarcarp /app
COPY build /app/build
# there is a go-specific Makefile in sonarcarp. we only need the other makefile includes.

RUN make vendor compile-generic

FROM golang:1.26.0-alpine3.23 AS compiler-debug
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
    VERSION="25.12.0-4" \
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
