MAKEFILES_VERSION=10.2.1
VERSION=25.1.0-5
.DEFAULT_GOAL:=dogu-release

GOTAG="1.24.5"
GO_ENV_VARS=CGO_ENABLED=0 GOOS=linux

include build/make/variables.mk
include build/make/self-update.mk
include build/make/bats.mk
include build/make/release.mk
include build/make/prerelease.mk
include build/make/k8s-dogu.mk
include build/make/dependencies-gomod.mk
include build/make/clean.mk
include build/make/build.mk
include build/make/test-unit.mk
include build/make/mocks.mk

SONARCARP_DIR=sonarcarp
SONARCARP_MAKEFILES=${SONARCARP_DIR}/build

STAGE_FLAG :=
ifeq ($(DEBUG),true)
STAGE_FLAG := --build-arg STAGE=debug
endif

unit-test: ${SONARCARP_MAKEFILES}
	@cd ${SONARCARP_DIR} && make unit-test

mocks: ${SONARCARP_MAKEFILES}
	@cd ${SONARCARP_DIR} && make mocks

compile: ${SONARCARP_MAKEFILES}
	@cd ${SONARCARP_DIR} && make compile

${SONARCARP_MAKEFILES}:
	@cp -r build $@

.PHONY: docker-build
docker-build: check-docker-credentials check-k8s-image-env-var ${BINARY_YQ} ## Builds the docker image of the K8s app.
	@echo "Building docker image $(IMAGE)..."
	@DOCKER_BUILDKIT=1 docker build . -t $(IMAGE)

.PHONY: docker-build
docker-build: check-docker-credentials check-k8s-image-env-var ${BINARY_YQ} ## Overwrite docker-build from k8s.mk to include build arguments
	@echo "Building docker image $(IMAGE)..."
	@echo "Building image with STAGE_FLAG: $(STAGE_FLAG)"
	@docker build . -t "$(IMAGE)" $(STAGE_FLAG)