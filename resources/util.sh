#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail


DATABASE_IP=postgresql
DATABASE_USER
DATABASE_USER_PASSWORD
DATABASE_DB

setDbVars() {
  DATABASE_USER=$(doguctl config -e sa-postgresql/username)
  DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
  DATABASE_DB=$(doguctl config -e sa-postgresql/database)
}

# Executes the given statement on the sonar database.
# Needs 'setDbVars' to be called beforehand to have all database variables initialized
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

function set_successful_first_start_flag() {
  echo "Setting successfulFirstStart registry key..."
  doguctl config successfulFirstStart true
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
  # TODO Web service is deprecated since 10.4 and will be removed in a future version.
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/user_groups/create?description=tempadmingroup&name=${GROUP_NAME}"
}

function create_user_group_via_rest_api() {
  NAME=$1
  DESCRIPTION=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  curl "${CURL_LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "${API_ENDPOINT}/user_groups/create?name=${NAME}&description=${DESCRIPTION}"
  # for unknown reasons the curl call prints the resulting JSON without newline to stdout which disturbs logging
  printf "\\n"
}

function grant_permission_to_group_via_rest_api() {
  local groupName=${1}
  local permission=${2}
  local additionalParams=${3}
  local authUser=${4}
  local authPassword=${5}
  local addGroupRequest="${API_ENDPOINT}/permissions/add_group?permission=${permission}&groupName=${groupName}&${additionalParams}"

  local exitCode=0
  curl "${CURL_LOG_LEVEL}" --fail -u "${authUser}":"${authPassword}" -X POST "${addGroupRequest}" || exitCode=$?

  if [[ "${exitCode}" != "0" ]]; then
    echo "ERROR: Granting permission to group ${groupName} failed with code ${exitCode}."
    exit 1
  fi
}

function remove_permission_of_group_via_rest_api() {
  GROUPNAME=$1
  PERMISSION=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  curl "${CURL_LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "${API_ENDPOINT}/permissions/remove_group?permission=${PERMISSION}&groupName=${GROUPNAME}"
}

# encode special characters per RFC 3986
#
# usage: urlencode <string>
#
# taken from: https://gist.github.com/cdown/1163649?permalink_comment_id=4291617#gistcomment-4291617
urlencode() {
    local LC_ALL=C # support unicode = loop bytes, not characters
    local c i n=${#1}
    for (( i=0; i<n; i++ )); do
        c="${1:i:1}"
        case "$c" in
            [-_.~A-Za-z0-9]) # also encode ;,/?:@&=+$!*'()# == encodeURIComponent in javascript
            #[-_.~A-Za-z0-9\;,/?:@\&=+\$!*\'\(\)#]) # dont encode ;,/?:@&=+$!*'()# == encodeURI in javascript
               printf '%s' "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    echo
}

# Checks whether a permission template exists
#
# usage: existsPermissionTemplate <template name> <user> <password>
function existsPermissionTemplate() {
  local permissionTemplate="${1}"
  local authUser=${2}
  local authPassword=${3}

  local uui_or_false
  uui_or_false="$(retrieve_permission_template_uuid_via_rest_api "${authUser}" "${authPassword}" "${permissionTemplate}")"
  if [[ "${uui_or_false}" == "" || "${uui_or_false}" == "false" ]]; then
    echo "Skip updating permission template..."
    return 1
  else
    return 0
  fi
}

# Adds the configured admin group to a permission template
#
# usage: addCesAdminGroupToPermissionTemplate <template name> <user> <password>
function addCesAdminGroupToPermissionTemplate() {
  local groupToAdd="${CES_ADMIN_GROUP}"
  local permissionTemplate="${1}" permissionTemplateUuid
  local authUser=${2}
  local authPassword=${3}

  permissionTemplateUuid="$(retrieve_permission_template_uuid_via_rest_api "${authUser}" "${authPassword}" "${permissionTemplate}")"
  if [[ "${permissionTemplateUuid}" == "" || "${permissionTemplateUuid}" == "false" ]]; then
    echo "Skip adding group '${groupToAdd}' to permission template '${permissionTemplate}'..."
    echo "Cause: The template uuid could not be retrieved"
    return 1
  fi

  echo "Adding group '${groupToAdd}' to permission template '${permissionTemplate}'..."
  for projectPermissionToGrant in ${PROJECT_PERMISSIONS}; do
    addGroupToPermissionTemplateViaRestAPI "${groupToAdd}" "${permissionTemplateUuid}" "${projectPermissionToGrant}" "${authUser}" "${authPassword}"
  done
}

# Retrieves the uuid for a given permission template via an api request
#
# usage: retrieve_permission_template_uuid_via_rest_api <username> <password> <template name>
#
# - <template name> will be automatically url encoded
function retrieve_permission_template_uuid_via_rest_api() {
  local permissionTemplate="${3}" permissionTemplateEncoded searchResult exitCode=0 authUser="${1}" authPassword="${2}"
  permissionTemplateEncoded="$(urlencode "${permissionTemplate}")"

  local templateSearchRequest="${API_ENDPOINT}/permissions/search_templates?q=${permissionTemplateEncoded}"
  searchResult=$(curl "${CURL_LOG_LEVEL}" --fail -u "${authUser}":"${authPassword}" "${templateSearchRequest}") || exitCode=$?
  if [[ "${exitCode}" != "0" ]]; then
    echo "ERROR: Permission template search request failed with exit code ${exitCode}. SonarQube's API may not be ready, or the credentials may not be sufficient."
    return 1
  fi
  local jqGetTemplateOrFalse=".permissionTemplates[] | select(.name==\"${permissionTemplate}\").id // false"
  # use '-r' to get the raw string without quotes
  echo "${searchResult}" | jq -r "${jqGetTemplateOrFalse}"
}

# Adds the group with the given permission to the permission template identified by the templates uuid
#
# usage: addGroupToPermissionTemplateViaRestAPI <group> <template uuid> <permission name> <username> <password>
function addGroupToPermissionTemplateViaRestAPI() {
  local groupToAdd="${1}"
  local permissionTemplateId="${2}"
  local projectPermissionToGrant="${3}"
  local authUser=${4}
  local authPassword=${5}

  local addGroupRequest="${API_ENDPOINT}/permissions/add_group_to_template?templateId=${permissionTemplateId}&groupName=${groupToAdd}&permission=${projectPermissionToGrant}"
  local exitCode=0
  echo "Grant permission '${projectPermissionToGrant}' to group '${groupToAdd}' for template with uuid '${permissionTemplateId}'"
  curl "${CURL_LOG_LEVEL}" -f -u "${authUser}":"${authPassword}" -X POST "${addGroupRequest}" || exitCode=$?

  if [[ "${exitCode}" != "0" ]]; then
    echo "ERROR: Permission template add group request failed with exit code ${exitCode}. SonarQube's API may not be ready, or the credentials may not be sufficient."
  fi
}

function grant_admin_group_permissions() {
  local ADMIN_GROUP=${1}
  local ADMIN_USER=${2}
  local ADMIN_PASSWORD=${3}
  local noAdditionalParams=""

  printf "Adding admin privileges to CES admin group...\\n"
    for permission in ${ADMIN_PERMISSIONS}
    do
    printf "grant permission '%s' to group '%s'...\\n" "${permission}" "${ADMIN_GROUP}"
    grant_permission_to_group_via_rest_api "${ADMIN_GROUP}" "${permission}" "${noAdditionalParams}" "${ADMIN_USER}" "${ADMIN_PASSWORD}"
  done
}

function grant_admin_permissions_to_group() {
  GROUP_NAME=$1
  AUTH_USER=$2
  AUTH_PASSWORD=$3
  LOG_LEVEL=$4
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/permissions/add_group?groupName=${GROUP_NAME}&permission=admin"
}

function deactivate_default_admin_user() {
  AUTH_USER=$1
  AUTH_PASSWORD=$2
  LOG_LEVEL=$3
  # sonar requires a special character in the admin password
  RANDOM_PASSWORD=$(doguctl random --withSpecialChars | jq "@uri" -jRr)
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/change_password?login=admin&password=${RANDOM_PASSWORD}&previousPassword=admin"
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/deactivate?login=admin"
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

  remove_user "${ADMIN_USERNAME}"
  remove_group "${ADMIN_GROUP}"
}

function add_user() {
  local username=${1} password=${2} password_hashed salt salt_base64

  salt="$(doguctl random)"
  salt_base64="$(echo "$salt" | base64)"
  password_hashed="$(echo -n "$(java /PasswordHasher.java "${salt_base64}" "${password}")")"

  execute_sql_statement_on_database "INSERT INTO users (login, name, reset_password, crypted_password, salt, hash_method, active, external_login, external_identity_provider, user_local, uuid, external_id)
    VALUES ('${username}', 'Temporary System Administrator', false, '${password_hashed}', '${salt_base64}', 'PBKDF2', true, '${username}', 'sonarqube', true, '${username}', '${username}');"
}

function add_temporary_admin_group() {
  GROUP_NAME=${1}
  GROUP_ROLE=${2:-admin}
  # Add group to "groups" table
  local group_uuid group_role_uuid
  group_uuid="$(doguctl random)"
  group_role_uuid="$(doguctl random)"
  execute_sql_statement_on_database "INSERT INTO groups (name, description, uuid) VALUES ('${GROUP_NAME}', 'Temporary admin group', '${group_uuid}');"
  local GROUP_ID_QUERY="SELECT uuid from groups WHERE name='${GROUP_NAME}'"
  # Grant admin permissions in "group_roles" table
  execute_sql_statement_on_database "INSERT INTO group_roles (group_uuid, role, uuid) VALUES ((${GROUP_ID_QUERY}), '${GROUP_ROLE}', '${group_role_uuid}');"
}

function assign_group() {
  local user=${1} group=${2}
  execute_sql_statement_on_database "INSERT INTO groups_users (group_uuid, user_uuid, uuid) VALUES ((SELECT uuid FROM groups where name='${group}'),(SELECT uuid FROM users where login='${user}'),'$(uuidgen)');"
}

function remove_user() {
  local username=${1}
  execute_sql_statement_on_database "DELETE FROM groups_users WHERE user_uuid=(SELECT uuid FROM users WHERE login='${username}');"
  execute_sql_statement_on_database "DELETE FROM users WHERE login='${username}';"
}

function remove_group() {
  local GROUP_NAME=${1}
  # Remove group entry from "group_roles" table
  execute_sql_statement_on_database "DELETE FROM group_roles WHERE group_uuid=(SELECT uuid from groups WHERE name='${GROUP_NAME}');"
  # Remove group from "groups" table
  execute_sql_statement_on_database "DELETE FROM groups WHERE name='${GROUP_NAME}';"
}