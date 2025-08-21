ARTIFACT_ID=sonarcarp
MAKEFILES_VERSION=10.2.1
VERSION=25.1.0-5

TARGET_DIR=../target
BINARY=${TARGET_DIR}/${ARTIFACT_ID}
GOTAG="1.24.5"
GO_ENV_VARS=CGO_ENABLED=0 GOOS=linux

include build/make/variables.mk
include build/make/clean.mk
include build/make/release.mk
include build/make/dependencies-gomod.mk
include build/make/build.mk
include build/make/test-common.mk
include build/make/test-unit.mk
include build/make/mocks.mk
