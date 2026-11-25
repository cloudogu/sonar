#! /bin/bash
export BATS_TEST_START_TIME="0"
export BATSLIB_FILE_PATH_REM=""
export BATSLIB_FILE_PATH_ADD=""
export output=""
export status=""

load '/workspace/target/bats_libs/bats-support/load.bash'
load '/workspace/target/bats_libs/bats-assert/load.bash'
load '/workspace/target/bats_libs/bats-mock/load.bash'
load '/workspace/target/bats_libs/bats-file/load.bash'

setup() {
  # overwrite Dockerfile env vars
  export STARTUP_DIR=/workspace/resources/
  # create mocks
  doguctl="$(mock_create)"
  export doguctl
  ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"

  curl="$(mock_create)"
  export curl
  ln -s "${curl}" "${BATS_TMPDIR}/curl"

  jq="$(mock_create)"
  export jq
  ln -s "${jq}" "${BATS_TMPDIR}/jq"

  # put mocked command in front of PATH to avoid calling existing commands
  export PATH="${BATS_TMPDIR}:${PATH}"
}

teardown() {
  unset STARTUP_DIR
  /bin/rm "${BATS_TMPDIR}/doguctl"
  /bin/rm "${BATS_TMPDIR}/curl"
  /bin/rm "${BATS_TMPDIR}/jq"
}

@test "run_post_upgrade should succeed for upgrade from 25.0.1-5 to 25.1.0-6" {
  # given
  mock_set_output "${doguctl}" "600" 4
  mock_set_output "${curl}" "400" 1
  mock_set_output "${jq}" "MIGRATION_SUCCEEDED" 1

  source /workspace/resources/post-upgrade.sh
  reinstall_plugins(){
    echo "reinstall_plugins null implementation"
  }

  # when
  run run_post_upgrade 25.0.1-5 25.1.0-6

  # then
  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "15"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" 'config -e sa-postgresql/username'
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" 'config -e sa-postgresql/password'
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" 'config -e sa-postgresql/database'
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" 'config --default 600 health_timeout_seconds'
  assert_equal "$(mock_get_call_args "${doguctl}" "5")" 'wait-for-http --timeout 600 --method GET http://localhost:9000/sonar/api/system/status'
  assert_equal "$(mock_get_call_args "${doguctl}" "15")" 'config post_upgrade_running false'
  assert_equal "$(mock_get_call_num "${curl}")" "1"
  assert_equal "$(mock_get_call_args "${curl}" "1")" '--silent --fail -X GET http://localhost:9000/sonar/api/system/db_migration_status'

  assert_line "Running post-upgrade script..."
  assert_line "No db migration is needed"
}

@test "run_post_upgrade should reinstall plugins for upgrade from 25.12.0-16 to 26.2.0-4" {
  # given
  mock_set_output "${doguctl}" "600" 4
  mock_set_output "${curl}" "400" 1
  mock_set_output "${jq}" "MIGRATION_SUCCEEDED" 1

  source /workspace/resources/post-upgrade.sh
  reinstall_plugins(){
    echo "reinstall_plugins null implementation"
  }
  update_plugins(){
    echo "update_plugins null implementation"
  }

  # when
  run run_post_upgrade 25.12.0-16 26.2.0-4

  # then
  assert_success
  assert_line "reinstall_plugins null implementation"
  refute_line "update_plugins null implementation"
  assert_equal "$(mock_get_call_num "${doguctl}")" "6"
  assert_equal "$(mock_get_call_args "${doguctl}" "6")" 'config post_upgrade_running false'
}

@test "run_post_upgrade should update plugins but not reinstall them for upgrade from 26.2.0-3 to 26.2.0-4" {
  # given
  mock_set_output "${doguctl}" "600" 4
  mock_set_output "${curl}" "400" 1
  mock_set_output "${jq}" "MIGRATION_SUCCEEDED" 1

  source /workspace/resources/post-upgrade.sh
  reinstall_plugins(){
    echo "reinstall_plugins null implementation"
  }
  update_plugins(){
    echo "update_plugins null implementation"
  }

  # when
  run run_post_upgrade 26.2.0-3 26.2.0-4

  # then
  assert_success
  refute_line "reinstall_plugins null implementation"
  assert_line "update_plugins null implementation"
  assert_equal "$(mock_get_call_num "${doguctl}")" "6"
  assert_equal "$(mock_get_call_args "${doguctl}" "6")" 'config post_upgrade_running false'
}

@test "run_post_upgrade should not update plugins for upgrade from 26.2.0-4 to 26.2.0-5" {
  # given
  mock_set_output "${doguctl}" "600" 4
  mock_set_output "${curl}" "400" 1
  mock_set_output "${jq}" "MIGRATION_SUCCEEDED" 1

  source /workspace/resources/post-upgrade.sh
  reinstall_plugins(){
    echo "reinstall_plugins null implementation"
  }
  update_plugins(){
    echo "update_plugins null implementation"
  }

  # when
  run run_post_upgrade 26.2.0-4 26.2.0-5

  # then
  assert_success
  refute_line "reinstall_plugins null implementation"
  refute_line "update_plugins null implementation"
}

@test "is_affected_by_missing_plugin_update should only match v26.2.0-1 to v26.2.0-3" {
  source /workspace/resources/post-upgrade.sh

  run is_affected_by_missing_plugin_update 26.2.0-1
  assert_success
  run is_affected_by_missing_plugin_update 26.2.0-2
  assert_success
  run is_affected_by_missing_plugin_update 26.2.0-3
  assert_success

  run is_affected_by_missing_plugin_update 26.2.0-4
  assert_failure
  run is_affected_by_missing_plugin_update 26.2.0-13
  assert_failure
  run is_affected_by_missing_plugin_update 25.12.0-17
  assert_failure
}

@test "update_plugins should not fail if plugin updates fail" {
  # given
  source /workspace/resources/post-upgrade.sh
  HEALTH_TIMEOUT=600
  CURL_LOG_LEVEL="--silent"
  wait_for_sonar_to_get_up(){ :; }
  wait_for_sonar_to_get_healthy(){ :; }
  create_temporary_admin(){ :; }
  check_for_updates(){ return 5; }
  remove_all_temporary_admins_users_and_groups(){
    echo "remove_all_temporary_admins_users_and_groups called"
  }

  # when
  run update_plugins

  # then
  assert_success
  assert_line "WARNING: Could not update plugins. Please update them manually via Administration -> Marketplace."
  assert_line "remove_all_temporary_admins_users_and_groups called"
}

@test "run_post_upgrade should succeed for upgrade from 5.1.2-3 to 6.25.0.0-6" {
  # given
  mock_set_output "${doguctl}" "600" 4
  mock_set_output "${curl}" "400" 1
  mock_set_output "${jq}" "MIGRATION_SUCCEEDED" 1

  source /workspace/resources/post-upgrade.sh
  reinstall_plugins(){
    echo "reinstall_plugins null implementation"
  }

  # when
  run run_post_upgrade 5.1.2-3 6.25.0.0-6

  # then
  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "6"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" 'config -e sa-postgresql/username'
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" 'config -e sa-postgresql/password'
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" 'config -e sa-postgresql/database'
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" 'config --default 600 health_timeout_seconds'
  assert_equal "$(mock_get_call_args "${doguctl}" "5")" 'wait-for-http --timeout 600 --method GET http://localhost:9000/sonar/api/system/status'
  assert_equal "$(mock_get_call_args "${doguctl}" "6")" 'config post_upgrade_running false'
  assert_equal "$(mock_get_call_num "${curl}")" "1"
  assert_equal "$(mock_get_call_args "${curl}" "1")" '--silent --fail -X GET http://localhost:9000/sonar/api/system/db_migration_status'

  assert_line "Running post-upgrade script..."
  assert_line "No db migration is needed"
}