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

function add_temporary_admin_user() {
  # temporarily create admin user and add to admin groups
  TEMPORARY_ADMIN_USER=${1}
  TEMPORARY_ADMIN_PASSWORD=${2}
  SALT=$(doguctl random)
  HASHED_PW=$(getSHA1PW "${TEMPORARY_ADMIN_PASSWORD}" "${SALT}")
  execute_sql_statement_on_database "INSERT INTO users (login, name, crypted_password, salt, hash_method, active, external_login, external_identity_provider, user_local, is_root, onboarded, uuid, external_id)
  VALUES ('${TEMPORARY_ADMIN_USER}', 'Temporary Administrator', '${HASHED_PW}', '${SALT}', 'SHA1', true, '${TEMPORARY_ADMIN_USER}', 'sonarqube', true, true, true, '${TEMPORARY_ADMIN_USER}', '${TEMPORARY_ADMIN_USER}');"

  ADMIN_ID_PSQL_OUTPUT=$(PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "SELECT uuid FROM users WHERE login='${TEMPORARY_ADMIN_USER}';")
  ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | awk 'NR==3' | cut -d " " -f 2)
  if [[ -z ${ADMIN_ID} ]]; then
    # id has only one digit
    ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | awk 'NR==3' | cut -d " " -f 3)
  fi
  execute_sql_statement_on_database "INSERT INTO groups_users (user_uuid, group_uuid) VALUES (${ADMIN_ID}, 1);"
  execute_sql_statement_on_database "INSERT INTO groups_users (user_uuid, group_uuid) VALUES (${ADMIN_ID}, 2);"
}

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

function create_temporary_admin_user_with_temporary_admin_group() {
  # create temporary admin user
  local TEMPORARY_ADMIN_USER=${1}
  local PASSWORD=${2}
  local TEMPORARY_ADMIN_GROUP=${3}
  local SALT
  local HASHED_PW
  SALT=$(doguctl random)
  HASHED_PW=$(getSHA1PW "${PASSWORD}" "${SALT}")
  execute_sql_statement_on_database "INSERT INTO users (login, name, reset_password, crypted_password, salt, hash_method, active, external_login, external_identity_provider, user_local, is_root, onboarded, uuid, external_id)
  VALUES ('${TEMPORARY_ADMIN_USER}', 'Temporary Administrator', false, '${HASHED_PW}', '${SALT}', 'SHA1', true, '${TEMPORARY_ADMIN_USER}', 'sonarqube', true, true, true, '${TEMPORARY_ADMIN_USER}', '${TEMPORARY_ADMIN_USER}');"
  # add temporary admin user to temporary admin group
  local ADMIN_ID_QUERY="SELECT uuid from users WHERE login='${TEMPORARY_ADMIN_USER}'"
  local GROUP_ID_QUERY="SELECT uuid from groups WHERE name='${TEMPORARY_ADMIN_GROUP}'"
  execute_sql_statement_on_database "INSERT INTO groups_users (user_uuid, group_uuid) VALUES ((${ADMIN_ID_QUERY}), (${GROUP_ID_QUERY}));"
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
