#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

DATABASE_IP=postgresql
DATABASE_USER=$(doguctl config -e sa-postgresql/username)
DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
DATABASE_DB=$(doguctl config -e sa-postgresql/database)

function execute_sql_statement_on_database(){
  PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "${1}"
  return $?
}

function wait_for_sonar_status_endpoint() {
  WAIT_TIMEOUT=${1}
  if ! doguctl wait-for-http --timeout "${WAIT_TIMEOUT}" --method GET http://localhost:9000/sonar/api/system/status; then
    echo "timeout reached while waiting for SonarQube status endpoint to be available"
    exit 1
  else
    echo "SonarQube status endpoint is available"
  fi
}

function wait_for_sonar_to_get_up() {
  WAIT_TIMEOUT=${1}
  for i in $(seq 1 "${WAIT_TIMEOUT}"); do
    SONAR_STATUS=$(curl -s http://localhost:9000/sonar/api/system/status | jq -r '.status')
    if [[ "${SONAR_STATUS}" = "UP" ]]; then
      echo "SonarQube status is ${SONAR_STATUS}"
      break
    fi
    if [[ "$i" -eq ${WAIT_TIMEOUT} ]] ; then
      echo "SonarQube did not get up within ${WAIT_TIMEOUT} seconds; status is ${SONAR_STATUS}. Dogu exits now"
      exit 1
    fi
    # waiting for SonarQube to get up
    sleep 1
  done
}

# DEPRECATED - Since SonarQube 9.4 the support for SHA1 hashed password has been removed.
function getSHA1PW() {
    PW="${1}"
    SALT="${2}"
    echo -n "--${SALT}--${PW}--" | sha1sum | awk '{print $1}'
}

function remove_temporary_admin_user() {
  local TEMPORARY_ADMIN_USER=${1}
  execute_sql_statement_on_database "DELETE FROM groups_users WHERE user_uuid=(SELECT uuid FROM users WHERE login='${TEMPORARY_ADMIN_USER}');"
  execute_sql_statement_on_database "DELETE FROM users WHERE login='${TEMPORARY_ADMIN_USER}';"
}

function wait_for_sonar_to_get_healthy() {
  WAIT_TIMEOUT=${1}
  USER=$2
  PASSWORD=$3
  LOG_LEVEL=$4
  for i in $(seq 1 "${WAIT_TIMEOUT}"); do
    SONAR_HEALTH_STATUS=$(curl "${LOG_LEVEL}" --fail -u "${USER}":"${PASSWORD}" http://localhost:9000/sonar/api/system/health | jq -r '.health')
    if [[ "${SONAR_HEALTH_STATUS}" = "GREEN" ]]; then
      echo "SonarQube health status is ${SONAR_HEALTH_STATUS}"
      break
    fi
    if [[ "$i" -eq ${WAIT_TIMEOUT} ]] ; then
      echo "SonarQube did not get healthy within ${WAIT_TIMEOUT} seconds; health status is ${SONAR_HEALTH_STATUS}. Dogu exits now"
      exit 1
    fi
    # waiting for SonarQube to get healthy
    sleep 1
  done
}

function create_user_via_rest_api() {
  LOGIN=$1
  NAME=$2
  PASSWORD=$3
  AUTH_USER=$4
  AUTH_PASSWORD=$5
  LOG_LEVEL=$6
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/create?login=${LOGIN}&name=${NAME}&password=${PASSWORD}&local=true"
}

function deactivate_user_via_rest_api() {
  LOGIN=$1
  AUTH_USER=$2
  AUTH_PASSWORD=$3
  LOG_LEVEL=$4
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/deactivate?login=${LOGIN}"
}

function create_group_via_rest_api() {
  GROUP_NAME=$1
  AUTH_USER=$2
  AUTH_PASSWORD=$3
  LOG_LEVEL=$4
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/user_groups/create?description=tempadmingroup&name=${GROUP_NAME}"
}

function grant_admin_permissions_to_group() {
  GROUP_NAME=$1
  AUTH_USER=$2
  AUTH_PASSWORD=$3
  LOG_LEVEL=$4
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/permissions/add_group?groupName=${GROUP_NAME}&permission=admin"
}

function add_user_to_group_via_rest_api() {
  USERNAME=$1
  GROUPNAME=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  LOG_LEVEL=$5
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/user_groups/add_user?name=${GROUPNAME}&login=${USERNAME}"
}

function deactivate_default_admin_user() {
  AUTH_USER=$1
  AUTH_PASSWORD=$2
  LOG_LEVEL=$3
  RANDOM_PASSWORD=$(doguctl random)
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/change_password?login=admin&password=${RANDOM_PASSWORD}&previousPassword=admin"
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/deactivate?login=admin"
}

function set_successful_first_start_flag() {
  echo "Setting successfulFirstStart registry key..."
  doguctl config successfulFirstStart true
}

# get_last_admin_group_or_global_admin_group echoes admin_group__last value from the registry if it was set, otherwise
# it echoes the current (global) admin_group.
#
# Store the result in a variable like this:
#  myAdminGroup=$(get_last_admin_group_or_global_admin_group)
#
# note that 'echo' returns the string to the caller and _does not_ print the value to stdout. It is also not possible
# to add debug echo's/printf's/etc.
# see https://stackoverflow.com/questions/14482943/
function get_last_admin_group_or_global_admin_group() {
    local admin_group_last=""

    if admin_group_last=$(doguctl config admin_group_last) ;
    then
        printf "%s" "${admin_group_last}"
    else
        # this group name is used either way to check if it is equal with the global admin group
        # instead of unnecessarily check for empty strings we return a valid value for the equal-check
        printf "%s" "$(doguctl config --global admin_group)"
    fi
}

function update_last_admin_group_in_registry() {
    echo "Update SonarQube admin group in registry..."

    local newAdminGroup=$1
    doguctl config admin_group_last "${newAdminGroup}"
}

function update_last_temp_admin_in_registry() {
  ADMIN_USERNAME=${1}
  ADMIN_GROUP=${2}
  doguctl config "last_tmp_admin_name" "${ADMIN_USERNAME}"
  doguctl config "last_tmp_admin_group" "${ADMIN_GROUP}"
}

function remove_last_temp_admin() {
  echo "Removing last tmp admin..."
  ADMIN_USERNAME=$(doguctl config "last_tmp_admin_name" --default " ")
  ADMIN_GROUP=$(doguctl config "last_tmp_admin_group" --default " ")

  remove_temporary_admin_user "${ADMIN_USERNAME}"
  remove_temporary_admin_group "${ADMIN_GROUP}"
}

function install_plugin_via_api() {
  PLUGIN=${1}
  USER=${2}
  PASSWORD=${3}
  INSTALL_RESPONSE=$(curl "${CURL_LOG_LEVEL}" -u "${USER}":"${PASSWORD}" -X POST http://localhost:9000/sonar/api/plugins/install?key="${PLUGIN}")
  # check response for error messages
  if [[ -n ${INSTALL_RESPONSE} ]]; then
    ERROR_MESSAGE=$(echo "${INSTALL_RESPONSE}"|jq '.errors[0]'|jq '.msg')
    if [[ ${ERROR_MESSAGE} == *"No plugin with key '${PLUGIN}' or plugin '${PLUGIN}' is already installed in latest version"* ]]; then
      echo "Plugin ${PLUGIN} is not available at all or already installed in latest version."
      FAILED_PLUGIN_NAMES+=${PLUGIN},
    fi
  else
    echo "Plugin ${PLUGIN} installed."
  fi
}

function add_temporary_admin_group() {
  GROUP_NAME=${1}
  # Add group to "groups" table
  local group_uuid group_role_uuid
  group_uuid="$(doguctl random)"
  group_role_uuid="$(doguctl random)"
  execute_sql_statement_on_database "INSERT INTO groups (name, description, uuid) VALUES ('${GROUP_NAME}', 'Temporary admin group', '${group_uuid}');"
  local GROUP_ID_QUERY="SELECT uuid from groups WHERE name='${GROUP_NAME}'"
  # Grant admin permissions in "group_roles" table
  execute_sql_statement_on_database "INSERT INTO group_roles (group_uuid, role, uuid) VALUES ((${GROUP_ID_QUERY}), 'admin', '${group_role_uuid}');"
}

function add_temporary_admin_group_via_rest_api_with_default_credentials() {
  local GROUP_NAME=${1}
  local LOGLEVEL=${2}
  create_group_via_rest_api "${GROUP_NAME}" admin admin "${LOGLEVEL}"
  grant_admin_permissions_to_group "${GROUP_NAME}" admin admin "${LOGLEVEL}"
}

function remove_temporary_admin_group() {
  local GROUP_NAME=${1}
  # Remove group entry from "group_roles" table
  execute_sql_statement_on_database "DELETE FROM group_roles WHERE group_uuid=(SELECT uuid from groups WHERE name='${GROUP_NAME}');"
  # Remove group from "groups" table
  execute_sql_statement_on_database "DELETE FROM groups WHERE name='${GROUP_NAME}';"
}

function remove_permission_from_group() {
  local GROUP_NAME=${1}
  local PERMISSION=${2}
  # Remove group entry from "group_roles" table
  execute_sql_statement_on_database "DELETE FROM group_roles WHERE group_uuid=(SELECT uuid from groups WHERE name='${GROUP_NAME}' and role='${PERMISSION}');"
  # Remove group from "groups" table
  execute_sql_statement_on_database "DELETE FROM groups WHERE name='${GROUP_NAME}';"
}

function create_temporary_system_admin_user_with_default_password() {
  local TEMP_SYSTEM_ADMIN=${1}
  # shellcheck disable=SC2016
  local SALT='k9x9eN127/3e/hf38iNiKwVfaVk='
  # shellcheck disable=SC2016
  local HASHED_PW='100000$t2h8AtNs1AlCHuLobDjHQTn9XppwTIx88UjqUm4s8RsfTuXQHSd/fpFexAnewwPsO6jGFQUv/24DnO55hY6Xew=='

  execute_sql_statement_on_database "INSERT INTO users (login, name, reset_password, crypted_password, salt, hash_method, active, external_login, external_identity_provider, user_local, uuid, external_id)
    VALUES ('${TEMP_SYSTEM_ADMIN}', 'Temporary System Administrator', false, '${HASHED_PW}', '${SALT}', 'PBKDF2', true, '${TEMP_SYSTEM_ADMIN}', 'sonarqube', true, '${TEMP_SYSTEM_ADMIN}', '${TEMP_SYSTEM_ADMIN}');"
  execute_sql_statement_on_database "INSERT INTO user_roles(uuid, user_uuid, role) VALUES ('$(doguctl random)', (SELECT uuid from users WHERE login='${TEMP_SYSTEM_ADMIN}'), 'admin');"
}

function delete_temporary_system_admin_user() {
  local TEMP_SYSTEM_ADMIN=${1}

  execute_sql_statement_on_database "DELETE FROM user_roles where user_uuid=(SELECT uuid from users WHERE login='${TEMP_SYSTEM_ADMIN}');"
  execute_sql_statement_on_database "DELETE FROM users where login='${TEMP_SYSTEM_ADMIN}';"
}

function create_temporary_admin_user_with_temporary_admin_group() {
  local TEMPORARY_ADMIN_USER=${1}
  local PASSWORD=${2}
  local TEMPORARY_ADMIN_GROUP=${3}
  local LOGLEVEL=${4}
  local TEMP_SYSTEM_ADMIN
  TEMP_SYSTEM_ADMIN="$(doguctl random)"

  create_temporary_system_admin_user_with_default_password "${TEMP_SYSTEM_ADMIN}"

  create_user_via_rest_api "${TEMPORARY_ADMIN_USER}" "TemporaryAdministrator" "${PASSWORD}" "${TEMP_SYSTEM_ADMIN}" "admin" "${LOGLEVEL}"
  add_user_to_group_via_rest_api "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_GROUP}" "${TEMP_SYSTEM_ADMIN}" "admin" "${LOGLEVEL}"

  delete_temporary_system_admin_user "${TEMP_SYSTEM_ADMIN}"
}

function create_temporary_admin_user_via_rest_api_with_default_credentials() {
  # create temporary admin user
  local TEMPORARY_ADMIN_USER=${1}
  local PASSWORD=${2}
  local TEMPORARY_ADMIN_GROUP=${3}
  local LOGLEVEL=${4}
  create_user_via_rest_api "${TEMPORARY_ADMIN_USER}" "TemporaryAdministrator" "${PASSWORD}" admin admin "${LOGLEVEL}"
  add_user_to_group_via_rest_api "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_GROUP}" "admin" "admin" "${LOGLEVEL}"
}
