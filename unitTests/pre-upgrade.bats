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
  export doguctl
  export psql
  ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"
  ln -s "${psql}" "${BATS_TMPDIR}/psql"
  export PATH="${PATH}:${BATS_TMPDIR}"
}

teardown() {
  unset SONARQUBE_HOME
  unset STARTUP_DIR
  # bats-mock/mock_create needs to be injected into the path so the production code will find the mock
  rm "${BATS_TMPDIR}/doguctl"
  rm "${BATS_TMPDIR}/psql"
}

@test "run_pre_upgrade should print migration for upgrade from 7.9.4-4 to 8.9.0-1" {
  mock_set_status "${doguctl}" 0
  mock_set_output "${doguctl}" "sql-username"
  mock_set_output "${doguctl}" "sql-password"
  mock_set_output "${doguctl}" "sql-database"

  run /workspace/resources/pre-upgrade.sh "7.9.4-4" "8.9.0-1"

  assert_success
  assert_line 'Running pre-upgrade script...'
  assert_line 'Moving obsolete plugins that now come with SonarQube 8...'
  assert_line 'Finished moving obsolete plugins.'
  assert_equal "$(mock_get_call_num "${doguctl}")" "4"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" "config -e sa-postgresql/username"
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" "config -e sa-postgresql/password"
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" "config -e sa-postgresql/database"
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" "config post_upgrade_running true"
  assert_equal "$(mock_get_call_num "${psql}")" "0"
}

@test "run_pre_upgrade should remove deprecated admin and cache for upgrade from 7.9.1-1 to 7.9.4-4" {
  mkdir -p ${SONARQUBE_HOME}/data/es6
  touch ${SONARQUBE_HOME}/data/es6/aCacheFile.tmp
  mock_set_status "${doguctl}" 0
  mock_set_output "${doguctl}" "sql-username"
  mock_set_output "${doguctl}" "sql-password"
  mock_set_output "${doguctl}" "sql-database"
  mock_set_status "${psql}" 0
  mock_set_output "${psql}" "sql-username"

  run /workspace/resources/pre-upgrade.sh "7.9.1-1" "7.9.4-4"

  assert_success
  assert_line 'Running pre-upgrade script...'
  assert_line 'Removing deprecated sonarqubedoguadmin...'
  assert_line 'Removing es6 cache...'
  assert_equal "$(mock_get_call_num "${doguctl}")" "4"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" "config -e sa-postgresql/username"
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" "config -e sa-postgresql/password"
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" "config -e sa-postgresql/database"
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" "config post_upgrade_running true"
  assert_equal "$(mock_get_call_num "${psql}")" "1"
  assert_equal "$(mock_get_call_args "${psql}" "1")" "--host postgresql --username sql-database --dbname sql-database -1 -c DELETE FROM users WHERE login='sonarqubedoguadmin';"
}

