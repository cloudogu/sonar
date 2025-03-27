#!/usr/bin/env bash
# Bind an unbound BATS variable that fails all tests when combined with 'set -o nounset'
export BATS_TEST_START_TIME="0"

load '/workspace/target/bats_libs/bats-support/load.bash'
load '/workspace/target/bats_libs/bats-assert/load.bash'
load '/workspace/target/bats_libs/bats-mock/load.bash'

setup() {
  export SONARQUBE_HOME=/opt/sonar
  export STARTUP_DIR=/workspace/resources/
}

teardown() {
  unset SONARQUBE_HOME
  unset STARTUP_DIR
}

@test "run_upgrade_notification should fail for multi-hop upgrade from 6.7.6-1 to 9.9.1-3" {
  # note the sequence of sourcing and overwriting the map count variable
  source /workspace/resources/upgrade-notification.sh
  local CURRENT_MAX_MAP_COUNT=9999999

  run run_upgrade_notification "6.7.6-1" "9.9.1-3"

  assert_failure
  assert_line --partial 'Upgrade from version 6.7.6-1 to 9.9.1-3 is not supported'
}

@test "run_upgrade_notification should maxMapCount-fail for upgrade from 6.7.7-1 to 9.9.1-3" {
  source /workspace/resources/upgrade-notification.sh
  local CURRENT_MAX_MAP_COUNT=12345

  run run_upgrade_notification "6.7.6-1" "9.9.1-3"

  assert_failure
  assert_line --partial 'Your max virtual memory areas vm.max_map_count is too low'
}
