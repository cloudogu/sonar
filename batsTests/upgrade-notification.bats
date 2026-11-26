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

@test "run_upgrade_notification should fail for upgrade from 8.9.8-3 to 25.1.0-1" {
  # note the sequence of sourcing and overwriting the map count variable
  source /workspace/resources/upgrade-notification.sh
  local CURRENT_MAX_MAP_COUNT=9999999

  run run_upgrade_notification "8.9.8-3" "25.1.0-1"

  assert_failure
  assert_line --partial 'Upgrade from version 8.9.8-3 to 25.1.0-1 is not supported'
}

@test "run_upgrade_notification should maxMapCount-fail for upgrade from 6.7.7-1 to 9.9.1-3" {
  source /workspace/resources/upgrade-notification.sh
  local CURRENT_MAX_MAP_COUNT=12345

  run run_upgrade_notification "6.7.6-1" "9.9.1-3"

  assert_failure
  assert_line --partial 'Your max virtual memory areas vm.max_map_count is too low'
}

@test "run_upgrade_notification should succeed for upgrade from 25.12.0-16 to 26.2.0-0" {
  # note the sequence of sourcing and overwriting the map count variable
  source /workspace/resources/upgrade-notification.sh
  local CURRENT_MAX_MAP_COUNT=9999999

  run run_upgrade_notification "25.12.0-16" "26.2.0-0"

  assert_success
}

@test "run_upgrade_notification should fail for multi-hop upgrade from 9.9.1-3 to 26.2.0-0" {
  # note the sequence of sourcing and overwriting the map count variable
  source /workspace/resources/upgrade-notification.sh
  local CURRENT_MAX_MAP_COUNT=9999999

  run run_upgrade_notification "9.9.1-3" "26.2.0-0"

  assert_failure
  assert_line --partial 'Upgrade from version 9.9.1-3 to 26.2.0-0 is not supported'
}

@test "run_upgrade_notification should fail for upgrade from 25.1.0-7 to 26.9.0-0" {
  # note the sequence of sourcing and overwriting the map count variable
  source /workspace/resources/upgrade-notification.sh
  local CURRENT_MAX_MAP_COUNT=9999999

  run run_upgrade_notification "25.1.0-7" "26.9.0-0"

  assert_failure
  assert_line --partial 'Upgrade from version 25.1.0-7 to 26.9.0-0 is not supported. Upgrade to version 25.12.0 before.'
}

@test "run_upgrade_notification should succeed for upgrade from 25.12.0-17 to 26.9.0-0" {
  # note the sequence of sourcing and overwriting the map count variable
  source /workspace/resources/upgrade-notification.sh
  local CURRENT_MAX_MAP_COUNT=9999999

  run run_upgrade_notification "25.12.0-17" "26.9.0-0"

  assert_success
}

@test "run_upgrade_notification should succeed for upgrade from 25.1.0-7 to 25.12.0-17" {
  # note the sequence of sourcing and overwriting the map count variable
  source /workspace/resources/upgrade-notification.sh
  local CURRENT_MAX_MAP_COUNT=9999999

  run run_upgrade_notification "25.1.0-7" "25.12.0-17"

  assert_success
}
