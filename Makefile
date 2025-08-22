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

unit-test: ${SONARCARP_MAKEFILES}
	@cd ${SONARCARP_DIR} && make unit-test

mocks: ${SONARCARP_MAKEFILES}
	@cd ${SONARCARP_DIR} && make mocks

compile: ${SONARCARP_MAKEFILES}
	@cd ${SONARCARP_DIR} && make compile

${SONARCARP_MAKEFILES}:
	@cp -r build $@
