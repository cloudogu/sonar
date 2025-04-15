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

  curl="$(mock_create)"
  export curl
  ln -s "${curl}" "${BATS_TMPDIR}/curl"

  sha256sum="$(mock_create)"
  export sha256sum
  ln -s "${sha256sum}" "${BATS_TMPDIR}/sha256sum"

  awk="$(mock_create)"
  export awk
  ln -s "${awk}" "${BATS_TMPDIR}/awk"

  unzip="$(mock_create)"
  export unzip
  ln -s "${unzip}" "${BATS_TMPDIR}/unzip"

  rm="$(mock_create)"
  export rm
  ln -s "${rm}" "${BATS_TMPDIR}/rm"

  export PATH="${BATS_TMPDIR}:${PATH}"
}

teardown() {
  unset STARTUP_DIR
  /bin/rm "${BATS_TMPDIR}/doguctl"
  /bin/rm "${BATS_TMPDIR}/curl"
  /bin/rm "${BATS_TMPDIR}/sha256sum"
  /bin/rm "${BATS_TMPDIR}/awk"
  /bin/rm "${BATS_TMPDIR}/unzip"
  /bin/rm "${BATS_TMPDIR}/rm"
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

  local currentDate
  currentDate=$(date "+%Y-%m-%d")

  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "1"
  assert_regex "$(mock_get_call_args "${doguctl}" "1")" "config amend_projects_with_ces_admin_permissions_last_status ${currentDate} .*"
}

@test "should return 1 when update timestamp in 'resetAddCesAdminGroupToProjectKey' for error in registry" {
  mock_set_status "${doguctl}" 1 1

  source /workspace/resources/startup.sh

  run resetAddCesAdminGroupToProjectKey

  local currentDate
  currentDate=$(date "+%Y-%m-%d")

  assert_failure
  assert_line "ERROR: Writing the registry key 'amend_projects_with_ces_admin_permissions_last_status' failed with exitCode 1."
  assert_equal "$(mock_get_call_num "${doguctl}")" "1"
  assert_regex "$(mock_get_call_args "${doguctl}" "1")" "config amend_projects_with_ces_admin_permissions_last_status ${currentDate} .*"
}

@test "should not download any profile resource if no profile url was configured" {
  mock_set_status "${doguctl}" 0 1
  mock_set_output "${doguctl}" "empty" 1

  source /workspace/resources/startup.sh

  run downloadQualityProfiles

  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "1"
  assert_line "No profile URLs to import."
}

@test "should fetch configured profile url and extract it" {
  mock_set_status "${doguctl}" 0 1
  mock_set_output "${doguctl}" "cloudogu.com/nexus/profiles.zip" 1

  # Skip credentials
  mock_set_status "${doguctl}" 0 2
  mock_set_output "${doguctl}" "empty" 2
  mock_set_status "${doguctl}" 0 3
  mock_set_output "${doguctl}" "empty" 3
  mock_set_status "${doguctl}" 0 4
  mock_set_output "${doguctl}" "empty" 4

  # Skip proxy
  mock_set_status "${doguctl}" 0 5
  mock_set_output "${doguctl}" "empty" 5

  # Retry limit
  mock_set_status "${doguctl}" 0 6
  mock_set_output "${doguctl}" "5" 6

  # Old hash
  mock_set_status "${doguctl}" 0 7
  mock_set_output "${doguctl}" "empty" 7

  # Flag Force upload
  mock_set_status "${doguctl}" 0 8
  mock_set_output "${doguctl}" "false" 8

  mock_set_status "${curl}" 0 1
  mock_set_output "${curl}" "200" 1

  mock_set_status "${sha256sum}" 0 1
  mock_set_output "${sha256sum}" "205b16da72842143a6fa1849126b7bd74b5d12a609387d3d037fb104440ea349  /var/lib/qualityprofiles/profiles.zip" 1

  mock_set_status "${awk}" 0 1
  mock_set_output "${awk}" "205b16da72842143a6fa1849126b7bd74b5d12a609387d3d037fb104440ea349" 1

  mock_set_status "${unzip}" 0 1

  mock_set_status "${rm}" 0 1
  mock_set_output "${rm}" "" 1

  source /workspace/resources/startup.sh

  run downloadQualityProfiles

  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "8"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" 'config --default empty profiles/url'
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" 'config --default empty profiles/user'
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" 'config -e --default empty profiles/password'
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" 'config profiles/allow_insecure'
  assert_equal "$(mock_get_call_args "${doguctl}" "5")" 'config --global proxy/enabled'
  assert_equal "$(mock_get_call_args "${doguctl}" "6")" 'config profiles/retry_limit'
  assert_equal "$(mock_get_call_args "${doguctl}" "7")" 'config --default empty profiles/archive_sum'
  assert_equal "$(mock_get_call_args "${doguctl}" "8")" 'config profiles/force_upload'
  assert_equal "$(mock_get_call_args "${curl}" "1")" '-w %{http_code} --silent --retry 5 -o /var/lib/qualityprofiles/profiles.zip cloudogu.com/nexus/profiles.zip'
  assert_equal "$(mock_get_call_args "${sha256sum}" "1")" '/var/lib/qualityprofiles/profiles.zip'
  assert_equal "$(mock_get_call_args "${awk}" "1")" '{print ""$1""}'
  assert_equal "$(mock_get_call_args "${unzip}" "1")" '/var/lib/qualityprofiles/profiles.zip -d /var/lib/qualityprofiles'
  assert_equal "$(mock_get_call_args "${rm}" "1")" '/var/lib/qualityprofiles/profiles.zip'
  assert_line "Download URL: cloudogu.com/nexus/profiles.zip"
  assert_line "Retry limit: 5"
  assert_line "Determine quality profiles hash"
  assert_line "Extract quality profiles archive"
}

@test "should do nothing if checksums are equal" {
  mock_set_status "${doguctl}" 0 1
  mock_set_output "${doguctl}" "cloudogu.com/nexus/profiles.zip" 1

  # Skip credentials
  mock_set_status "${doguctl}" 0 2
  mock_set_output "${doguctl}" "empty" 2
  mock_set_status "${doguctl}" 0 3
  mock_set_output "${doguctl}" "empty" 3
  mock_set_status "${doguctl}" 0 4
  mock_set_output "${doguctl}" "empty" 4

  # Skip proxy
  mock_set_status "${doguctl}" 0 5
  mock_set_output "${doguctl}" "empty" 5

  # Retry limit
  mock_set_status "${doguctl}" 0 6
  mock_set_output "${doguctl}" "5" 6

  # Old hash
  mock_set_status "${doguctl}" 0 7
  mock_set_output "${doguctl}" "205b16da72842143a6fa1849126b7bd74b5d12a609387d3d037fb104440ea349" 7

  # Flag Force upload
  mock_set_status "${doguctl}" 0 8
  mock_set_output "${doguctl}" "false" 8

  mock_set_status "${curl}" 0 1
  mock_set_output "${curl}" "200" 1

  mock_set_status "${sha256sum}" 0 1
  mock_set_output "${sha256sum}" "205b16da72842143a6fa1849126b7bd74b5d12a609387d3d037fb104440ea349  /var/lib/qualityprofiles/profiles.zip" 1

  mock_set_status "${awk}" 0 1
  mock_set_output "${awk}" "205b16da72842143a6fa1849126b7bd74b5d12a609387d3d037fb104440ea349" 1

  mock_set_status "${rm}" 0 1
  mock_set_output "${rm}" "" 1

  source /workspace/resources/startup.sh

  run downloadQualityProfiles

  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "8"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" 'config --default empty profiles/url'
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" 'config --default empty profiles/user'
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" 'config -e --default empty profiles/password'
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" 'config profiles/allow_insecure'
  assert_equal "$(mock_get_call_args "${doguctl}" "5")" 'config --global proxy/enabled'
  assert_equal "$(mock_get_call_args "${doguctl}" "6")" 'config profiles/retry_limit'
  assert_equal "$(mock_get_call_args "${doguctl}" "7")" 'config --default empty profiles/archive_sum'
  assert_equal "$(mock_get_call_args "${doguctl}" "8")" 'config profiles/force_upload'
  assert_equal "$(mock_get_call_args "${curl}" "1")" '-w %{http_code} --silent --retry 5 -o /var/lib/qualityprofiles/profiles.zip cloudogu.com/nexus/profiles.zip'
  assert_equal "$(mock_get_call_args "${sha256sum}" "1")" '/var/lib/qualityprofiles/profiles.zip'
  assert_equal "$(mock_get_call_args "${awk}" "1")" '{print ""$1""}'
  assert_equal "$(mock_get_call_args "${rm}" "1")" '/var/lib/qualityprofiles/profiles.zip'
  assert_line "Download URL: cloudogu.com/nexus/profiles.zip"
  assert_line "Retry limit: 5"
  assert_line "Determine quality profiles hash"
  assert_line "Quality profiles archive did not change."
}

@test "should upload if checksums are equal and force upload flag is true" {
  mock_set_status "${doguctl}" 0 1
  mock_set_output "${doguctl}" "cloudogu.com/nexus/profiles.zip" 1

  # Skip credentials
  mock_set_status "${doguctl}" 0 2
  mock_set_output "${doguctl}" "empty" 2
  mock_set_status "${doguctl}" 0 3
  mock_set_output "${doguctl}" "empty" 3
  mock_set_status "${doguctl}" 0 4
  mock_set_output "${doguctl}" "empty" 4

  # Skip proxy
  mock_set_status "${doguctl}" 0 5
  mock_set_output "${doguctl}" "empty" 5

  # Retry limit
  mock_set_status "${doguctl}" 0 6
  mock_set_output "${doguctl}" "5" 6

  # Old hash
  mock_set_status "${doguctl}" 0 7
  mock_set_output "${doguctl}" "205b16da72842143a6fa1849126b7bd74b5d12a609387d3d037fb104440ea349" 7

  # Flag Force upload
  mock_set_status "${doguctl}" 0 8
  mock_set_output "${doguctl}" "true" 8

  mock_set_status "${curl}" 0 1
  mock_set_output "${curl}" "200" 1

  mock_set_status "${sha256sum}" 0 1
  mock_set_output "${sha256sum}" "205b16da72842143a6fa1849126b7bd74b5d12a609387d3d037fb104440ea349  /var/lib/qualityprofiles/profiles.zip" 1

  mock_set_status "${awk}" 0 1
  mock_set_output "${awk}" "205b16da72842143a6fa1849126b7bd74b5d12a609387d3d037fb104440ea349" 1

  mock_set_status "${unzip}" 0 1

  mock_set_status "${rm}" 0 1
  mock_set_output "${rm}" "" 1

  source /workspace/resources/startup.sh

  run downloadQualityProfiles

  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "8"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" 'config --default empty profiles/url'
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" 'config --default empty profiles/user'
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" 'config -e --default empty profiles/password'
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" 'config profiles/allow_insecure'
  assert_equal "$(mock_get_call_args "${doguctl}" "5")" 'config --global proxy/enabled'
  assert_equal "$(mock_get_call_args "${doguctl}" "6")" 'config profiles/retry_limit'
  assert_equal "$(mock_get_call_args "${doguctl}" "7")" 'config --default empty profiles/archive_sum'
  assert_equal "$(mock_get_call_args "${doguctl}" "8")" 'config profiles/force_upload'
  assert_equal "$(mock_get_call_args "${curl}" "1")" '-w %{http_code} --silent --retry 5 -o /var/lib/qualityprofiles/profiles.zip cloudogu.com/nexus/profiles.zip'
  assert_equal "$(mock_get_call_args "${sha256sum}" "1")" '/var/lib/qualityprofiles/profiles.zip'
  assert_equal "$(mock_get_call_args "${awk}" "1")" '{print ""$1""}'
  assert_equal "$(mock_get_call_args "${unzip}" "1")" '/var/lib/qualityprofiles/profiles.zip -d /var/lib/qualityprofiles'
  assert_equal "$(mock_get_call_args "${rm}" "1")" '/var/lib/qualityprofiles/profiles.zip'
  assert_line "Download URL: cloudogu.com/nexus/profiles.zip"
  assert_line "Retry limit: 5"
  assert_line "Determine quality profiles hash"
  assert_line "Flag force_upload is true. Keep in mind to turn this configuration to false after using it."
  assert_line "Extract quality profiles archive"
}

@test "should do nothing on error http code" {
  mock_set_status "${doguctl}" 0 1
  mock_set_output "${doguctl}" "cloudogu.com/nexus/profiles.zip" 1

  # Skip credentials
  mock_set_status "${doguctl}" 0 2
  mock_set_output "${doguctl}" "empty" 2
  mock_set_status "${doguctl}" 0 3
  mock_set_output "${doguctl}" "empty" 3
  mock_set_status "${doguctl}" 0 4
  mock_set_output "${doguctl}" "empty" 4

  # Skip proxy
  mock_set_status "${doguctl}" 0 5
  mock_set_output "${doguctl}" "empty" 5

  # Retry limit
  mock_set_status "${doguctl}" 0 6
  mock_set_output "${doguctl}" "5" 6

  mock_set_status "${curl}" 0 1
  mock_set_output "${curl}" "400" 1

  mock_set_status "${rm}" 0 1
  mock_set_output "${rm}" "" 1

  source /workspace/resources/startup.sh

  run downloadQualityProfiles

  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "6"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" 'config --default empty profiles/url'
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" 'config --default empty profiles/user'
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" 'config -e --default empty profiles/password'
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" 'config profiles/allow_insecure'
  assert_equal "$(mock_get_call_args "${doguctl}" "5")" 'config --global proxy/enabled'
  assert_equal "$(mock_get_call_args "${doguctl}" "6")" 'config profiles/retry_limit'
  assert_equal "$(mock_get_call_args "${curl}" "1")" '-w %{http_code} --silent --retry 5 -o /var/lib/qualityprofiles/profiles.zip cloudogu.com/nexus/profiles.zip'
  assert_equal "$(mock_get_call_args "${rm}" "1")" '/var/lib/qualityprofiles/profiles.zip'
  assert_line "Download URL: cloudogu.com/nexus/profiles.zip"
  assert_line "Retry limit: 5"
  assert_line "Returned http code 400 on getting profiles archive. Return"
}

@test "should use configured credentials and proxy settings" {
  mock_set_status "${doguctl}" 0 1
  mock_set_output "${doguctl}" "cloudogu.com/nexus/profiles.zip" 1

  # Credentials
  mock_set_status "${doguctl}" 0 2
  mock_set_output "${doguctl}" "user" 2
  mock_set_status "${doguctl}" 0 3
  mock_set_output "${doguctl}" "password" 3
  mock_set_status "${doguctl}" 0 4
  mock_set_output "${doguctl}" "true" 4

  # proxy
  mock_set_status "${doguctl}" 0 5
  mock_set_output "${doguctl}" "true" 5
  mock_set_status "${doguctl}" 0 6
  mock_set_output "${doguctl}" "domain.com,cloudogu.com" 6
  mock_set_status "${doguctl}" 0 7
  mock_set_output "${doguctl}" "proxyHost" 7
  mock_set_status "${doguctl}" 0 8
  mock_set_output "${doguctl}" "3128" 8
  mock_set_status "${doguctl}" 0 9
  mock_set_output "${doguctl}" "proxyUser" 9
  mock_set_status "${doguctl}" 0 10
  mock_set_output "${doguctl}" "proxyPw" 10

  # Retry limit
  mock_set_status "${doguctl}" 0 11
  mock_set_output "${doguctl}" "5" 11

  mock_set_status "${curl}" 0 1
  mock_set_output "${curl}" "400" 1

  mock_set_status "${rm}" 0 1
  mock_set_output "${rm}" "" 1

  source /workspace/resources/startup.sh

  run downloadQualityProfiles

  assert_success
  assert_equal "$(mock_get_call_num "${doguctl}")" "11"
  assert_equal "$(mock_get_call_args "${doguctl}" "1")" 'config --default empty profiles/url'
  assert_equal "$(mock_get_call_args "${doguctl}" "2")" 'config --default empty profiles/user'
  assert_equal "$(mock_get_call_args "${doguctl}" "3")" 'config -e --default empty profiles/password'
  assert_equal "$(mock_get_call_args "${doguctl}" "4")" 'config profiles/allow_insecure'
  assert_equal "$(mock_get_call_args "${doguctl}" "5")" 'config --global proxy/enabled'
  assert_equal "$(mock_get_call_args "${doguctl}" "6")" 'config --global proxy/no_proxy_hosts'
  assert_equal "$(mock_get_call_args "${doguctl}" "7")" 'config --default empty --global proxy/server'
  assert_equal "$(mock_get_call_args "${doguctl}" "8")" 'config --default empty --global proxy/port'
  assert_equal "$(mock_get_call_args "${doguctl}" "9")" 'config --global --default empty proxy/user'
  assert_equal "$(mock_get_call_args "${doguctl}" "10")" 'config --global --default empty proxy/password'
  assert_equal "$(mock_get_call_args "${doguctl}" "11")" 'config profiles/retry_limit'
  assert_equal "$(mock_get_call_args "${curl}" "1")" '-u user:password -k -x proxyHost:3128 --proxy-user proxyUser:proxyPw -w %{http_code} --silent --retry 5 -o /var/lib/qualityprofiles/profiles.zip cloudogu.com/nexus/profiles.zip'
  assert_equal "$(mock_get_call_args "${rm}" "1")" '/var/lib/qualityprofiles/profiles.zip'
  assert_line "Download URL: cloudogu.com/nexus/profiles.zip"
  assert_line "Retry limit: 5"
  assert_line "Returned http code 400 on getting profiles archive. Return"
}