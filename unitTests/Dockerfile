ARG BATS_BASE_IMAGE
ARG BATS_TAG

FROM ${BATS_BASE_IMAGE}:${BATS_TAG}

# Make bash more findable by scripts and tests
RUN ln -s /usr/bin/bash /bin/bash
RUN apk add make git
