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

@test "run_upgrade_notification should fail for upgrade for unsupported 5.1.0-1 to 10.11.12-13" {
  run /workspace/resources/upgrade-notification.sh "5.1.0-1" "10.11.12-13"

  assert_failure
  assert_line --partial 'Upgrade from version 5.1.0-1 to 10.11.12-13 is not supported'
}

@test "run_upgrade_notification should do fail for upgrade from specially unsupported version 6.7.6-1" {
  run /workspace/resources/upgrade-notification.sh "6.7.6-1" "10.11.12-13"

  assert_failure
  assert_line --partial 'Upgrade from version 6.7.6-1 to 10.11.12-13 is not supported'
}

@test "run_upgrade_notification should fail for multi-hop upgrade from 6.7.6-1 to 8.9.0-1" {
  run /workspace/resources/upgrade-notification.sh "6.7.6-1" "8.9.0-1"

  assert_failure
  assert_line --partial 'Upgrade from version 6.7.6-1 to 8.9.0-1 is not supported'
}

@test "run_upgrade_notification should maxMapCount-fail for upgrade from 6.7.7-1 to 7.9.2-3" {
  run /workspace/resources/upgrade-notification.sh "6.7.7-1" "7.9.2-3"

  assert_failure
  assert_line --partial 'Your max virtual memory areas vm.max_map_count is too low'
}

@test "run_upgrade_notification should print notification from 6.7.7-1 to 7.9.2-3" {
  # note the sequence of sourcing and overwriting the map count variable
  source /workspace/resources/upgrade-notification.sh
  export CURRENT_MAX_MAP_COUNT=9999999

  actual=$(run_upgrade_notification "6.7.7-1" "7.9.2-3")

  assert_equal $? 0
  [[ "${actual}" =~ 'You are upgrading your SonarQube instance from 6.7.x LTS to 7.9.x LTS'* ]]
}

@test "run_upgrade_notification should print notification from 7.9.2-3 to 8.9.0-1" {
  # note the sequence of sourcing and overwriting the map count variable
  source /workspace/resources/upgrade-notification.sh
  export CURRENT_MAX_MAP_COUNT=9999999

  actual=$(run_upgrade_notification "7.9.2-3" "8.9.0-1")

  assert_equal $? 0
  [[ "${actual}" =~ 'You are upgrading your SonarQube instance from 7.9.x LTS to 8.9.x LTS'* ]]
}


