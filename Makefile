MAKEFILES_VERSION=8.7.1
.DEFAULT_GOAL:=dogu-release

WORKSPACE=/workspace
BATS_LIBRARY_DIR=$(TARGET_DIR)/bats_libs
TESTS_DIR=./unitTests
BASH_TEST_REPORT_DIR=$(TARGET_DIR)/shell_test_reports
BASH_TEST_REPORTS=$(BASH_TEST_REPORT_DIR)/TestReport-*.xml
BATS_ASSERT=$(BATS_LIBRARY_DIR)/bats-assert
BATS_MOCK=$(BATS_LIBRARY_DIR)/bats-mock
BATS_SUPPORT=$(BATS_LIBRARY_DIR)/bats-support
BATS_BASE_IMAGE?=bats/bats
BATS_CUSTOM_IMAGE?=cloudogu/bats
BATS_TAG?=1.2.1

include build/make/variables.mk
include build/make/self-update.mk
include build/make/clean.mk
include build/make/release.mk
include build/make/k8s-dogu.mk

.PHONY unit-test-shell:
unit-test-shell: unit-test-shell-$(ENVIRONMENT)

$(BATS_ASSERT):
	@git clone --depth 1 https://github.com/bats-core/bats-assert $@

$(BATS_MOCK):
	@git clone --depth 1 https://github.com/grayhemp/bats-mock $@

$(BATS_SUPPORT):
	@git clone --depth 1 https://github.com/bats-core/bats-support $@

$(BASH_SRC):
	BASH_SRC:=$(shell find "${WORKDIR}" -type f -name "*.sh")

${BASH_TEST_REPORT_DIR}: $(TARGET_DIR)
	@mkdir -p $(BASH_TEST_REPORT_DIR)

unit-test-shell-ci: $(BASH_SRC) $(BASH_TEST_REPORT_DIR) $(BATS_ASSERT) $(BATS_MOCK) $(BATS_SUPPORT)
	@echo "Test shell units on CI server"
	@make unit-test-shell-generic

unit-test-shell-local: $(BASH_SRC) $(PASSWD) $(ETCGROUP) $(HOME_DIR) buildTestImage $(BASH_TEST_REPORT_DIR) $(BATS_ASSERT) $(BATS_MOCK) $(BATS_SUPPORT)
	@echo "Test shell units locally (in Docker)"
	@docker run --rm \
		-u "$(UID_NR):$(GID_NR)" \
		-v $(PASSWD):/etc/passwd:ro \
		-v $(HOME_DIR):/home/$(USER) \
		-v $(WORKDIR):$(WORKSPACE) \
		-w $(WORKSPACE) \
		--entrypoint="" \
		$(BATS_CUSTOM_IMAGE):$(BATS_TAG) \
		${TESTS_DIR}/customBatsEntrypoint.sh make unit-test-shell-generic

unit-test-shell-generic:
	@bats --formatter junit --output ${BASH_TEST_REPORT_DIR} ${TESTS_DIR}

.PHONY buildTestImage:
buildTestImage:
	@echo "Build shell test container"
	@cd ${TESTS_DIR} && docker build \
		--build-arg=BATS_BASE_IMAGE=${BATS_BASE_IMAGE} \
		--build-arg=BATS_TAG=${BATS_TAG} \
		-t ${BATS_CUSTOM_IMAGE}:${BATS_TAG} \
		.