#!/usr/bin/env bash
# Bind an unbound BATS variable that fails all tests when combined with 'set -o nounset'
export BATS_TEST_START_TIME="0"

load '/workspace/target/bats_libs/bats-support/load.bash'
load '/workspace/target/bats_libs/bats-assert/load.bash'
load '/workspace/target/bats_libs/bats-mock/load.bash'

setup() {
  export SONARQUBE_HOME=/opt/sonar
  export STARTUP_DIR=/workspace/resources/

  # bats-mock/mock_create needs to be injected into the path so the production code will find the mock
  doguctl="$(mock_create)"
  export doguctl
  export PATH="${PATH}:${BATS_TMPDIR}"
  ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"
}

teardown() {
  unset SONARQUBE_HOME
  unset STARTUP_DIR
  # bats-mock/mock_create needs to be injected into the path so the production code will find the mock
  rm "${BATS_TMPDIR}/doguctl"
}

@test "run_pre_upgrade should print migration for upgrade from 7.9.4-4 to 8.9.0-1" {
  run /workspace/resources/pre-upgrade.sh "7.9.4-4" "8.9.0-1"

  assert_success
  assert_line 'Running pre-upgrade script...'
  assert_line 'Removing obsolete plugins that now come with SonarQube 8...'
  assert_line 'Finished removing obsolete plugins.'
}

#@test "upgrade-notification should not print notification for bugfix upgrade from 8.5.1-1 to 8.5.1-5" {
#  run /workspace/resources/upgrade-notification.sh "8.5.1-5" "8.5.1-8"
#
#  assert_success
#  refute_output --partial 'You are starting an upgrade of the Jira dogu'
#}
#
#@test "upgrade-notification should not print notification for downgrade from 8.5.1-2 to 8.5.1-1" {
#  run /workspace/resources/upgrade-notification.sh "8.5.1-2" "8.5.1-1"
#
#  assert_success
#  refute_output --partial 'You are starting an upgrade of the Jira dogu'
#}
