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

@test "removeCasPlugin should delete any version of the CAS plugin jar" {
  sonarhome=$(mktemp -d)
  mkdir -p "${sonarhome}"/extensions/plugins
  file1="${sonarhome}"/extensions/plugins/sonar-cas-plugin-6.1.0.jar
  file2="${sonarhome}"/extensions/plugins/sonar-cas-plugin-5.4.3.jar
  touch ${file1}
  touch ${file2}
  assert_file_exist ${file1}
  assert_file_exist ${file2}
  export SONARQUBE_HOME="${sonarhome}"

  source /workspace/resources/post-upgrade.sh

  removeCasPlugin

  assert_success
  assert_file_not_exist ${file1}
  assert_file_not_exist ${file2}
}

@test "run_post_upgrade should delete the CAS plugin jar if dogu upgrades from version 25.0" {
  # given
  mock_set_output "${curl}" "400" 1
  mock_set_output "${jq}" "MIGRATION_SUCCEEDED" 1

  sonarhome=$(mktemp -d)
  mkdir -p "${sonarhome}"/extensions/plugins
  file1="${sonarhome}"/extensions/plugins/sonar-cas-plugin-6.1.0.jar
  file2="${sonarhome}"/extensions/plugins/sonar-cas-plugin-5.4.3.jar
  touch ${file1}
  touch ${file2}
  assert_file_exist ${file1}
  assert_file_exist ${file2}
  export SONARQUBE_HOME="${sonarhome}"

  source /workspace/resources/post-upgrade.sh
  reinstall_plugins(){
    echo "reinstall_plugins null implementation"
  }

  # when
  run run_post_upgrade 25.0.1-5 25.1.0-6

  # then
  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "5"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" 'config -e sa-postgresql/username'
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" 'config -e sa-postgresql/password'
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" 'config -e sa-postgresql/database'
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" 'wait-for-http --timeout 600 --method GET http://localhost:9000/sonar/api/system/status'
  assert_equal "$(mock_get_call_args "${doguctl}" "5")" 'config post_upgrade_running false'
  assert_equal "$(mock_get_call_num "${curl}")" "1"
  assert_equal "$(mock_get_call_args "${curl}" "1")" '--silent --fail -X GET http://localhost:9000/sonar/api/system/db_migration_status'

  assert_line "Running post-upgrade script..."
  assert_line "No db migration is needed"
  assert_line "Deleting obsolete SonarQube CAS plugins..."
}