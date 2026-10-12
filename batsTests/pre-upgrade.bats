#!/usr/bin/env bash
# Bind an unbound BATS variable that fails all tests when combined with 'set -o nounset'
export BATS_TEST_START_TIME="0"

load '/workspace/target/bats_libs/bats-support/load.bash'
load '/workspace/target/bats_libs/bats-assert/load.bash'
load '/workspace/target/bats_libs/bats-mock/load.bash'

setup() {
  export STARTUP_DIR=/workspace/resources/
  # create mocks
  doguctl="$(mock_create)"
  export doguctl
  ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"

  # put mocked command in front of PATH to avoid calling existing commands
  export PATH="${BATS_TMPDIR}:${PATH}"
}

teardown() {
  unset STARTUP_DIR
  rm "${BATS_TMPDIR}/doguctl"
}

@test "run_pre_upgrade should fail for upgrade from 25.12.0-16 to 26.5.0-0" {
  source /workspace/resources/pre-upgrade.sh

  run run_pre_upgrade "25.12.0-16" "26.5.0-0"

  assert_failure
  assert_line --partial 'Upgrade from version 25.12.0-16 to 26.5.0-0 is not supported. Upgrade to version 26.2.0 before.'
  assert_equal "$(mock_get_call_num "${doguctl}")" "0"
}

@test "run_pre_upgrade should succeed for upgrade from 25.12.0-16 to 26.2.0-0" {
  source /workspace/resources/pre-upgrade.sh

  run run_pre_upgrade "25.12.0-16" "26.2.0-0"

  assert_success
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" "config post_upgrade_running true"
}

@test "run_pre_upgrade should succeed for upgrade from 26.2.0-0 to 26.5.0-0" {
  source /workspace/resources/pre-upgrade.sh

  run run_pre_upgrade "26.2.0-0" "26.5.0-0"

  assert_success
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" "config post_upgrade_running true"
}
