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
  psql="$(mock_create)"
  curl="$(mock_create)"
  jq="$(mock_create)"
  export doguctl
  export psql
  ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"
  ln -s "${psql}" "${BATS_TMPDIR}/psql"
  ln -s "${curl}" "${BATS_TMPDIR}/curl"
  ln -s "${jq}" "${BATS_TMPDIR}/jq"
  export PATH="${PATH}:${BATS_TMPDIR}"
}

teardown() {
  unset SONARQUBE_HOME
  unset STARTUP_DIR
  # bats-mock/mock_create needs to be injected into the path so the production code will find the mock
  rm "${BATS_TMPDIR}/doguctl"
  rm "${BATS_TMPDIR}/psql"
  rm "${BATS_TMPDIR}/curl"
  rm "${BATS_TMPDIR}/jq"
}

@test "run_post_upgrade should db-migrate for upgrade from 7.9.4-4 to 8.9.0-1" {
  mock_set_status "${doguctl}" 0
  mock_set_output "${doguctl}" "sql-username"
  mock_set_output "${doguctl}" "sql-password"
  mock_set_output "${doguctl}" "sql-database"
  mock_set_status "${curl}" 0
  mock_set_status "${jq}" 0

  run /workspace/resources/post-upgrade.sh "7.9.4-4" "8.9.0-1"

  assert_success
  assert_line 'Running post-upgrade script...'
  assert_line --partial 'Waiting for SonarQube status endpoint to be available'
  assert_line --partial 'SonarQube status endpoint is available'
  assert_line --partial 'Checking if db migration is needed'
  assert_line --partial 'No db migration is needed'
  refute_line --partial "Database migration is required"
  refute_line --partial "Plugin"
  assert_line 'Migrating DB: Update accounts associated with identity provider CAS to SonarQube...'
  assert_equal "$(mock_get_call_num "${doguctl}")" "5"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" "config -e sa-postgresql/username"
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" "config -e sa-postgresql/password"
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" "config -e sa-postgresql/database"
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" "wait-for-http --timeout 600 --method GET http://localhost:9000/sonar/api/system/status"
  assert_equal "$(mock_get_call_args "${doguctl}" "5")" "config post_upgrade_running false"
  assert_equal "$(mock_get_call_num "${psql}")" "1"
}
