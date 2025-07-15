MAKEFILES_VERSION=10.2.0
.DEFAULT_GOAL:=dogu-release

include build/make/variables.mk
include build/make/self-update.mk
include build/make/clean.mk
include build/make/bats.mk
include build/make/release.mk
include build/make/k8s-dogu.mk
