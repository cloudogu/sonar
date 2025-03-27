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
  export STARTUP_DIR=/workspace/resources/
  doguctl="$(mock_create)"
  export doguctl
  ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"
  export PATH="${PATH}:${BATS_TMPDIR}"
}

teardown() {
  unset STARTUP_DIR
  rm "${BATS_TMPDIR}/doguctl"
}

@test "should return 0 when admin groups should be amended" {
  mock_set_status "${doguctl}" 0
  mock_set_output "${doguctl}" '2025-03-19 11:22:33' 1
  mock_set_output "${doguctl}" '1970-01-01' 2

  source /workspace/resources/startup.sh

  run shouldAddCesAdminGroupToAllProjects

  assert_success
  assert_line "All projects should be amended with CES-Admin group permissions..."
  assert_equal "$(mock_get_call_num "${doguctl}")" "2"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" "config amend_projects_with_ces_admin_permissions --default none"
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" "config amend_projects_with_ces_admin_permissions_last_status --default 1970-01-01"
}

@test "should return 0 when admin groups should be amended even for invalid date from local-registry" {
  mock_set_status "${doguctl}" 0
  mock_set_output "${doguctl}" '2025-03-19 11:22:33' 1
  mock_set_output "${doguctl}" 'foo_bar' 2

  source /workspace/resources/startup.sh

  run shouldAddCesAdminGroupToAllProjects

  assert_success
  assert_line "All projects should be amended with CES-Admin group permissions..."
  assert_equal "$(mock_get_call_num "${doguctl}")" "2"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" "config amend_projects_with_ces_admin_permissions --default none"
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" "config amend_projects_with_ces_admin_permissions_last_status --default 1970-01-01"
}

@test "should return 1 when admin groups should not be amended" {
  mock_set_status "${doguctl}" 0
  mock_set_output "${doguctl}" '2025-03-19 11:22:33' 1
  mock_set_output "${doguctl}" '2025-03-20 11:22:33' 2

  source /workspace/resources/startup.sh

  run shouldAddCesAdminGroupToAllProjects

  assert_failure
  assert_line "Skip amending projects with CES-Admin group permissions..."
  assert_equal "$(mock_get_call_num "${doguctl}")" "2"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" "config amend_projects_with_ces_admin_permissions --default none"
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" "config amend_projects_with_ces_admin_permissions_last_status --default 1970-01-01"
}


@test "should return 1 when checking admin groups should be amended for error in registry" {
  mock_set_status "${doguctl}" 1 1
  mock_set_output "${doguctl}" '2025-03-19 11:22:33' 1

  source /workspace/resources/startup.sh

  run shouldAddCesAdminGroupToAllProjects

  assert_failure
  assert_line "ERROR: Reading the registry 'amend_projects_with_ces_admin_permissions' failed with exitCode 1."
  assert_equal "$(mock_get_call_num "${doguctl}")" "1"
}

@test "should return 1 when checking admin groups should be amended for error parsing date" {
  mock_set_status "${doguctl}" 0
  mock_set_output "${doguctl}" 'foo_bar' 1

  source /workspace/resources/startup.sh

  run shouldAddCesAdminGroupToAllProjects

  assert_failure
  assert_line "date: invalid date 'foo_bar'"
  assert_line "ERROR: Parsing timestamp from registry 'amend_projects_with_ces_admin_permissions'"
  assert_equal "$(mock_get_call_num "${doguctl}")" "1"
}

@test "should return 1 when checking admin groups should be amended for error in local-registry" {
  mock_set_status "${doguctl}" 0 1
  mock_set_output "${doguctl}" '2025-03-19 11:22:33' 1
  mock_set_status "${doguctl}" 1 2

  source /workspace/resources/startup.sh

  run shouldAddCesAdminGroupToAllProjects

  assert_failure
  assert_line "ERROR: Reading the registry 'amend_projects_with_ces_admin_permissions_last_status' failed with exitCode 1."
  assert_equal "$(mock_get_call_num "${doguctl}")" "2"
}

@test "should return 1 when checking admin groups should be amended for 'none' entry" {
  mock_set_status "${doguctl}" 0 1
  mock_set_output "${doguctl}" 'none' 1
  mock_set_output "${doguctl}" '1970-01-01' 2

  source /workspace/resources/startup.sh

  run shouldAddCesAdminGroupToAllProjects

  assert_failure
  assert_line "Skip amending projects with CES-Admin group permissions..."
  assert_equal "$(mock_get_call_num "${doguctl}")" "1"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" "config amend_projects_with_ces_admin_permissions --default none"
}

@test "should update timestamp in 'resetAddCesAdminGroupToProjectKey'" {
  mock_set_status "${doguctl}" 0 1

  source /workspace/resources/startup.sh

  run resetAddCesAdminGroupToProjectKey

  local currentDate=$(date "+%Y-%m-%d")

  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "1"
  assert_regex "$(mock_get_call_args "${doguctl}" "1")" "config amend_projects_with_ces_admin_permissions_last_status ${currentDate} .*"
}

@test "should return 1 when update timestamp in 'resetAddCesAdminGroupToProjectKey' for error in registry" {
  mock_set_status "${doguctl}" 1 1

  source /workspace/resources/startup.sh

  run resetAddCesAdminGroupToProjectKey

  local currentDate=$(date "+%Y-%m-%d")

  assert_failure
  assert_line "ERROR: Writing the registry key 'amend_projects_with_ces_admin_permissions_last_status' failed with exitCode 1."
  assert_equal "$(mock_get_call_num "${doguctl}")" "1"
  assert_regex "$(mock_get_call_args "${doguctl}" "1")" "config amend_projects_with_ces_admin_permissions_last_status ${currentDate} .*"
}