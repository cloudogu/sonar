#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

DATABASE_IP=postgresql
DATABASE_USER=$(doguctl config -e sa-postgresql/username)
DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
DATABASE_DB=$(doguctl config -e sa-postgresql/database)
DOGU_ADMIN="sonarqubedoguadmin"

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
  HASHED_PW=${2}
  SALT=${3}
  execute_sql_statement_on_database "INSERT INTO users (login, name, crypted_password, salt, hash_method, active, external_login, external_identity_provider, user_local, is_root, onboarded, uuid, external_id)
  VALUES ('${TEMPORARY_ADMIN_USER}', 'Temporary Administrator', '${HASHED_PW}', '${SALT}', 'SHA1', true, '${TEMPORARY_ADMIN_USER}', 'sonarqube', true, true, true, '${TEMPORARY_ADMIN_USER}', '${TEMPORARY_ADMIN_USER}');"
 
  ADMIN_ID_PSQL_OUTPUT=$(PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "SELECT id FROM users WHERE login='${TEMPORARY_ADMIN_USER}';")
  ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | awk 'NR==3' | cut -d " " -f 2)
  if [[ -z ${ADMIN_ID} ]]; then
    # id has only one digit
    ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | awk 'NR==3' | cut -d " " -f 3)
  fi
  execute_sql_statement_on_database "INSERT INTO groups_users (user_id, group_id) VALUES (${ADMIN_ID}, 1);"
  execute_sql_statement_on_database "INSERT INTO groups_users (user_id, group_id) VALUES (${ADMIN_ID}, 2);"
}

function getSHA1PW() {
    PW="${1}"
    SALT="${2}"
    echo -n "--${SALT}--${PW}--" | sha1sum | awk '{print $1}'
}

function remove_temporary_admin_user() {
  TEMPORARY_ADMIN_USER=${1}
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

function create_dogu_admin_user_and_save_password() {
  AUTH_USER=$1
  AUTH_PASSWORD=$2
  LOG_LEVEL=$3
  echo "Creating ${DOGU_ADMIN} and granting admin permissions..."
  DOGU_ADMIN_PASSWORD=$(doguctl random)
  create_user_via_rest_api "${DOGU_ADMIN}" "SonarQubeDoguAdmin" "${DOGU_ADMIN_PASSWORD}" "${AUTH_USER}" "${AUTH_PASSWORD}" "${LOG_LEVEL}"
  add_user_to_group_via_rest_api "${DOGU_ADMIN}" "sonar-administrators" "${AUTH_USER}" "${AUTH_PASSWORD}" "${LOG_LEVEL}"
  # saving dogu admin password in registry
  doguctl config -e dogu_admin_password "${DOGU_ADMIN_PASSWORD}"
  printf "\\n"
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

function create_dogu_admin_and_deactivate_default_admin() {
  LOG_LEVEL=$1

  # default admin credentials (admin, admin) are used
  create_dogu_admin_user_and_save_password admin admin "${LOG_LEVEL}"

  echo "Deactivating default admin account..."
  DOGU_ADMIN_PASSWORD=$(doguctl config -e dogu_admin_password)
  deactivate_default_admin_user "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}" "${LOG_LEVEL}"
  printf "\\n"

  echo "Waiting for configuration changes to be internally executed..."
  sleep 3
}

function set_successful_first_start_flag() {
  echo "Setting successfulFirstStart registry key..."
  doguctl config successfulFirstStart true
}


# getLastAdminGroupOrGlobalAdminGroup echoes admin_group__last value from the registry if it was set, otherwise
# it echoes the current (global) admin_group.
#
# Store the result in a variable like this:
#  myAdminGroup=$(getLastAdminGroupOrGlobalAdminGroup)
#
# note that 'echo' returns the string to the caller and _does not_ print the value to stdout. It is also not possible
# to add debug echo's/printf's/etc.
# see https://stackoverflow.com/questions/14482943/
function getLastAdminGroupOrGlobalAdminGroup() {
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

FAILED_PLUGIN_NAMES=""

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

function reinstall_plugins() {
  PLUGINS="${1}"
  USER=${2}
  PASSWORD=${3}

  echo "Fetch already installed plugins"
  INSTALLED_PLUGINS=$(curl "${CURL_LOG_LEVEL}" --fail -u "${USER}":"${PASSWORD}" -X GET localhost:9000/sonar/api/plugins/installed | jq '.plugins' | jq '.[]' | jq -r '.key')

  IFS=','
  for PLUGIN in ${PLUGINS}; do
    echo "Checking if plugin ${PLUGIN} is installed already..."
    if [[ ${INSTALLED_PLUGINS} == *"${PLUGIN}"* ]]; then
      echo "Plugin ${PLUGIN} is installed already"
    else
      echo "Plugin ${PLUGIN} is not installed, installing it..."
      install_plugin_via_api "${PLUGIN}" "${USER}" "${PASSWORD}"
    fi
  done

  if [[ -n ${FAILED_PLUGIN_NAMES} ]]; then
    echo "### SUMMARY ###"
    echo "The following plugins could not have been re-installed: ${FAILED_PLUGIN_NAMES}"
    echo ""
  fi
}
