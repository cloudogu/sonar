#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

echo "                                     ./////,                    "
echo "                                 ./////==//////*                "
echo "                                ////.  ___   ////.              "
echo "                         ,**,. ////  ,////A,  */// ,**,.        "
echo "                    ,/////////////*  */////*  *////////////A    "
echo "                   ////'        \VA.   '|'   .///'       '///*  "
echo "                  *///  .*///*,         |         .*//*,   ///* "
echo "                  (///  (//////)**--_./////_----*//////)   ///) "
echo "                   V///   '°°°°      (/////)      °°°°'   ////  "
echo "                    V/////(////////\. '°°°' ./////////(///(/'   "
echo "                       'V/(/////////////////////////////V'      "

# import util functions:
# execute_sql_statement_on_database()
# wait_for_sonar_status_endpoint()
# wait_for_sonar_to_get_up()
# wait_for_sonar_to_get_healthy()
# add_temporary_admin_user()
# getSHA1PW()
# create_user_via_rest_api()
# add_user_to_group_via_rest_api()
# set_successful_first_start_flag()
# remove_permission_from_group()
# shellcheck disable=SC1091
source util.sh

# export so cas-plugin can use this env variable
export SONAR_PROPERTIES_FILE=/opt/sonar/conf/sonar.properties

# get variables
CES_ADMIN_GROUP=$(doguctl config --global admin_group)
CES_ADMIN_GROUP_LAST=$(get_last_admin_group_or_global_admin_group)
FQDN=$(doguctl config --global fqdn)
DOMAIN=$(doguctl config --global domain)
MAIL_ADDRESS=$(doguctl config --default "sonar@${DOMAIN}" --global mail_address)
QUALITY_PROFILE_DIR="/var/lib/qualityprofiles"
CURL_LOG_LEVEL="--silent"
HEALTH_TIMEOUT=600
ADMIN_PERMISSIONS="admin profileadmin gateadmin provisioning"
PROJECT_PERMISSIONS="admin codeviewer issueadmin securityhotspotadmin scan user"
KEY_AMEND_PROJECTS_WITH_CESADMIN_PERMISSIONS="amend_projects_with_ces_admin_permissions"
TEMPORARY_ADMIN_GROUP=$(doguctl random)
TEMPORARY_ADMIN_USER=$(doguctl random)
TEMPORARY_ADMIN_PASSWORD=$(doguctl random)
API_ENDPOINT="http://localhost:9000/sonar/api"

function areQualityProfilesPresentToImport() {
  echo "Check for quality profiles to import..."

  local resultCode
  if [[ "$(ls -A ${QUALITY_PROFILE_DIR})" ]]; then
    echo "Quality profiles are present for import..."
    resultCode=0
  else
    echo "There are no quality profiles for import present..."
    resultCode=1
  fi

  return ${resultCode}
}

function importQualityProfiles() {
  local AUTH_USER=$1
  local AUTH_PASSWORD=$2

  # import all quality profiles that are in the suitable directory
  for file in "${QUALITY_PROFILE_DIR}"/*; do
    echo "Found quality profile ${file}"
    local importResponse=""
    local importSuccesses=0
    local importFailures=0
    # ignore CasAuthenticationExceptions in log file, because the credentials below only work locally
    importResponse=$(curl ${CURL_LOG_LEVEL} -X POST -u "${AUTH_USER}":"${AUTH_PASSWORD}" -F "backup=@${file}" ${API_ENDPOINT}/qualityprofiles/restore)

    # check if import is successful
    if ! (echo "${importResponse}" | grep -o errors); then
      importSuccesses=$(echo "${importResponse}" | jq '.ruleSuccesses')
      importFailures=$(echo "${importResponse}" | jq '.ruleFailures')

      echo "Import of quality profile for ${file} returned with: ${importSuccesses} rules okay, ${importFailures} rules failed."

      if [[ "${importSuccesses}" == "0" ]]; then
        echo "WARNING: No quality profiles could be imported from file ${file}. Import returned: '${importResponse}'"
      fi

      if [[ "${importFailures}" != "0" ]]; then
        echo "ERROR: There were quality profiles import failures from file ${file}. Import returned: '${importResponse}'"
        # do not remove file so the user has the chance to examine the file content
        continue
      fi

      # delete file if import was successful. This works also with files not owned by sonar user, f. i. root ownership.
      rm -f "${file}"
      echo "Removed quality profile file ${file}"
    else
      echo "Import of quality profile ${file} has not been successful. Import returned: '${importResponse}'"
    fi
  done

  echo "Quality profile import finished..."
}

function render_properties_template() {
  doguctl template "${SONAR_PROPERTIES_FILE}.tpl" "${SONAR_PROPERTIES_FILE}"
}

function set_property_via_rest_api() {
  PROPERTY=$1
  VALUE=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "${API_ENDPOINT}/settings/set?key=${PROPERTY}&value=${VALUE}"
}

function create_user_group_via_rest_api() {
  NAME=$1
  DESCRIPTION=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "${API_ENDPOINT}/user_groups/create?name=${NAME}&description=${DESCRIPTION}"
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
  curl ${CURL_LOG_LEVEL} --fail -u "${authUser}":"${authPassword}" -X POST "${addGroupRequest}" || exitCode=$?

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
  curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "${API_ENDPOINT}/permissions/remove_group?permission=${PERMISSION}&groupName=${GROUPNAME}"
}

function existsPermissionTemplate() {
  local permissionTemplate="default_template"
  local authUser=${1}
  local authPassword=${2}

  local searchResult
  local exitCode=0
  local templateSearchRequest="${API_ENDPOINT}/permissions/search_templates?q=${permissionTemplate}"
  searchResult=$(curl ${CURL_LOG_LEVEL} --fail -u "${authUser}":"${authPassword}" "${templateSearchRequest}") || exitCode=$?

  if [[ "${exitCode}" != "0" ]]; then
    echo "ERROR: Permission template search request failed with exit code ${exitCode}. SonarQube's API may not be ready, or the credentials may not be sufficient."
    return 1
  fi

  local jqGetTemplateOrFalse=".permissionTemplates[] | select(.id==\"${permissionTemplate}\") // false"
  local templateJsonOrFalse
  templateJsonOrFalse=$(echo "${searchResult}" | jq "${jqGetTemplateOrFalse}")

  if [[ "${templateJsonOrFalse}" == "" || "${templateJsonOrFalse}" == "false" ]]; then
    echo "Skip updating permission template..."
    return 1
  else
    return 0
  fi
}

function addCesAdminGroupToPermissionTemplate() {
  local groupToAdd="${CES_ADMIN_GROUP}"
  local permissionTemplate="default_template"
  local authUser=${1}
  local authPassword=${2}

  echo "Adding group '${groupToAdd}' to permission template '${permissionTemplate}'..."

  for projectPermissionToGrant in ${PROJECT_PERMISSIONS}; do
    addGroupToPermissionTemplateViaRestAPI "${groupToAdd}" "${permissionTemplate}" "${projectPermissionToGrant}" "${authUser}" "${authPassword}"
  done
}

function addGroupToPermissionTemplateViaRestAPI() {
  local groupToAdd="${1}"
  local permissionTemplate="${2}"
  local projectPermissionToGrant="${3}"
  local authUser=${4}
  local authPassword=${5}

  local addGroupRequest="${API_ENDPOINT}/permissions/add_group_to_template?templateId=${permissionTemplate}&groupName=${groupToAdd}&permission=${projectPermissionToGrant}"
  local exitCode=0
  curl ${CURL_LOG_LEVEL} -f -u "${authUser}":"${authPassword}" -X POST "${addGroupRequest}" || exitCode=$?

  if [[ "${exitCode}" != "0" ]]; then
    echo "ERROR: Permission template add group request failed with exit code ${exitCode}. SonarQube's API may not be ready, or the credentials may not be sufficient."
  fi
}

function shouldCesAdminGroupToAllProjects() {
  local result
  local exitCode=0
  result=$(doguctl config "${KEY_AMEND_PROJECTS_WITH_CESADMIN_PERMISSIONS}" --default "none") || exitCode=$?

  if [[ "${exitCode}" != "0" ]]; then
    echo "ERROR: Reading the registry '${KEY_AMEND_PROJECTS_WITH_CESADMIN_PERMISSIONS}' failed with exitCode ${exitCode}."
    return 1
  fi

  if [[ "${result}" == "all" ]] ;  then
    echo "All projects should amended with CES-Admin group permissions..."
    return 0
  fi

  echo "Skip amending projects with CES-Admin group permissions..."
  return 1
}

function addCesAdminGroupToProject() {
  local groupToAdd="${CES_ADMIN_GROUP}"
  local authUser=${1}
  local authPassword=${2}
  local projects=""
  local getProjectsRequest="${API_ENDPOINT}/projects/search?ps=500"

  local exitCode=0
  projects=$(curl ${CURL_LOG_LEVEL} -f -u  "${authUser}":"${authPassword}" "${getProjectsRequest}" | jq '.components[] | .id + "=" + .key' | sed 's/"//g') || exitCode=$?
  if [[ "${exitCode}" != "0" ]]; then
    echo "ERROR: Fetching projects failed with code ${exitCode}. Abort granting project permissions to group ${groupToAdd}..."
    return
  fi

  local projectKey
  local projectId

  for project in ${projects}; do
    projectKey="${project#*=}"
    projectId="${project%=*}"
    echo "Adding group ${groupToAdd} to project ${projectKey}..."
    # use projectKey for logging (easy to find in UI) and projectId for requests (projectKey may contain nasty special characters)
    addCesAdminGroupToProjectWithPermissions "${groupToAdd}" "${projectId}" "${authUser}" "${authPassword}"
  done
}

function addCesAdminGroupToProjectWithPermissions() {
  local groupToAdd=${1}
  local projectId=${2}
  local authUser=${3}
  local authPassword=${4}
  local additionalParams="projectId=${projectId}"

  for projectPermissionToGrant in ${PROJECT_PERMISSIONS}; do
    grant_permission_to_group_via_rest_api "${groupToAdd}" "${projectPermissionToGrant}" "${additionalParams}" "${authUser}" "${authPassword}"
  done
}

function resetAddCesAdminGroupToProjectKey() {
  local exitCode=0
  KEY_AMEND_PROJECTS_WITH_CESADMIN_PERMISSIONS="amend_projects_with_ces_admin_permissions"
  result=$(doguctl config "${KEY_AMEND_PROJECTS_WITH_CESADMIN_PERMISSIONS}" "none") || exitCode=$?

  if [[ "${exitCode}" != "0" ]]; then
    echo "ERROR: Writing the registry key '${KEY_AMEND_PROJECTS_WITH_CESADMIN_PERMISSIONS}' failed with exitCode ${exitCode}."
    return 1
  fi
}

function get_out_of_date_plugins_via_rest_api() {
  AUTH_USER=$1
  AUTH_PASSWORD=$2
  OUT_OF_DATE_PLUGINS=$(curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X GET "${API_ENDPOINT}/plugins/updates" | jq '.plugins' | jq '.[]' | jq -r '.key')
}

function set_updatecenter_url_if_configured_in_registry() {
  AUTH_USER=$1
  AUTH_PASSWORD=$2
  if doguctl config sonar.updatecenter.url > /dev/null; then
    UPDATECENTER_URL=$(doguctl config sonar.updatecenter.url)
    echo "Setting sonar.updatecenter.url to ${UPDATECENTER_URL}"
    set_property_via_rest_api "sonar.updatecenter.url" "${UPDATECENTER_URL}" "${AUTH_USER}" "${AUTH_PASSWORD}"
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

function run_first_start_tasks() {
  echo "Adding CES admin group '${CES_ADMIN_GROUP}'..."
  create_user_group_via_rest_api "${CES_ADMIN_GROUP}" "CESAdministratorGroup" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  grant_admin_group_permissions "${CES_ADMIN_GROUP}" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  set_updatecenter_url_if_configured_in_registry "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  echo "Setting email configuration..."
  set_property_via_rest_api "email.smtp_host.secured" "postfix" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  set_property_via_rest_api "email.smtp_port.secured" "25" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  set_property_via_rest_api "email.prefix" "[SONARQUBE]" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"

  get_out_of_date_plugins_via_rest_api "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  if [[ -n "${OUT_OF_DATE_PLUGINS}" ]]; then
    echo "The following plugins are not up-to-date:"
    echo "${OUT_OF_DATE_PLUGINS}"
    while read -r PLUGIN; do
      echo "Updating plugin ${PLUGIN}..."
      curl ${CURL_LOG_LEVEL} --fail -u "${TEMPORARY_ADMIN_USER}":"${TEMPORARY_ADMIN_PASSWORD}" -X POST "localhost:9000/sonar/api/plugins/update?key=${PLUGIN}"
      echo "Plugin ${PLUGIN} updated"
    done <<< "${OUT_OF_DATE_PLUGINS}"
  fi
}

function startSonarQubeInBackground() {
  local reason="${1}"

  if [[ "$(doguctl config "container_config/memory_limit" -d "empty")" == "empty" ]];  then
    echo "Starting SonarQube without memory limits for ${reason}... "
    java -jar /opt/sonar/lib/sonar-application-"${SONAR_VERSION}".jar \
       & SONAR_PROCESS_ID=$!
  else
    MEMORY_LIMIT_MAX_PERCENTAGE=$(doguctl config "container_config/java_sonar_main_max_ram_percentage")
    MEMORY_LIMIT_MIN_PERCENTAGE=$(doguctl config "container_config/java_sonar_main_min_ram_percentage")

    echo "Starting SonarQube with memory limits MaxRAMPercentage: ${MEMORY_LIMIT_MAX_PERCENTAGE} and MinRAMPercentage: ${MEMORY_LIMIT_MIN_PERCENTAGE} for ${reason}..."
    java -XX:MaxRAMPercentage="${MEMORY_LIMIT_MAX_PERCENTAGE}" \
         -XX:MinRAMPercentage="${MEMORY_LIMIT_MIN_PERCENTAGE}" \
         -jar /opt/sonar/lib/sonar-application-"${SONAR_VERSION}".jar \
         & SONAR_PROCESS_ID=$!
  fi

  wait_for_sonar_status_endpoint "${HEALTH_TIMEOUT}"

  wait_for_sonar_to_get_up "${HEALTH_TIMEOUT}"
}

# parameter: process-id of sonar
function stopSonarQube() {
  local PID="${1}"
  # kill SonarQube and all child processes
  kill "${PID}"
  # In some cases the underlying webserver and elasticsearch are not exiting immediately. The wrapper will kill them after 5 minutes.
  echo "Wait for SonarQube exit. This can take up to 5 minutes."
  wait "${PID}" || true
  echo "SonarQube was stopped."
}

function create_temporary_admin_for_first_start() {
  echo "Adding temporary admin group..."
  add_temporary_admin_group_via_rest_api_with_default_credentials "${TEMPORARY_ADMIN_GROUP}" ${CURL_LOG_LEVEL}

  echo "Adding temporary admin user..."
  create_temporary_admin_user_via_rest_api_with_default_credentials "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}" "${TEMPORARY_ADMIN_GROUP}" ${CURL_LOG_LEVEL}

  echo "Adding temporary admin user to temporary admin group..."
  add_user_to_group_via_rest_api "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_GROUP}" admin admin "${CURL_LOG_LEVEL}"
}

function first_sonar_start() {
  echo "First start of SonarQube dogu"

  echo "Waiting for SonarQube to get healthy (max. ${HEALTH_TIMEOUT} seconds)..."
  wait_for_sonar_to_get_healthy ${HEALTH_TIMEOUT} "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}" ${CURL_LOG_LEVEL}

  echo "Deactivating default admin user..."
  deactivate_default_admin_user "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}" "${CURL_LOG_LEVEL}"

  run_first_start_tasks

  set_successful_first_start_flag
}

function create_temporary_admin_for_subsequent_start(){
  echo "Creating Temporary admin user..."
  # Create temporary admin only in database
  add_temporary_admin_group "${TEMPORARY_ADMIN_GROUP}"
  create_temporary_admin_user_with_temporary_admin_group "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}" "${TEMPORARY_ADMIN_GROUP}"
}

function subsequent_sonar_start() {
  echo "Subsequent start of SonarQube dogu"

  echo "Waiting for SonarQube to get healthy (max. ${HEALTH_TIMEOUT} seconds)..."
  wait_for_sonar_to_get_healthy ${HEALTH_TIMEOUT} "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}" ${CURL_LOG_LEVEL}

  set_updatecenter_url_if_configured_in_registry "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"

  resetCesAdmin "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
}

function resetCesAdmin() {
  echo "Ensure that CES admin exists and has sufficient privileges..."

  local TEMPORARY_ADMIN_USER="${1}"
  local TEMPORARY_ADMIN_PASSWORD="${2}"

  # Create CES admin group if not existent or if it has changed
  GROUP_NAME=$(curl ${CURL_LOG_LEVEL} --fail -u "${TEMPORARY_ADMIN_USER}":"${TEMPORARY_ADMIN_PASSWORD}" -X GET "${API_ENDPOINT}/user_groups/search" | jq ".groups[] | select(.name==\"${CES_ADMIN_GROUP}\")" | jq '.name')

  if [[ -z "${GROUP_NAME}" ]]; then
    echo "Adding CES admin group '${CES_ADMIN_GROUP}'..."
    create_user_group_via_rest_api "${CES_ADMIN_GROUP}" "CESAdministratorGroup" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  fi
  # Grant the right permissions to the new or existing group
  grant_admin_group_permissions "${CES_ADMIN_GROUP}" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
}

function remove_temporary_admin_user_and_group(){
  remove_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
  remove_temporary_admin_group "${TEMPORARY_ADMIN_GROUP}"
}

function remove_permissions_from_last_admin_group() {
  local admin_group=${CES_ADMIN_GROUP_LAST}
  printf "Remove admin privileges from previous CES admin group '%s'...\\n" "${admin_group}"

  for permission in ${ADMIN_PERMISSIONS}
  do
    printf "remove permission '%s' from group '%s'...\\n" "${permission}" "${admin_group}"
    remove_permission_from_group "${admin_group}" "${permission}"
  done
}

# It returns 0 if the admin group names differs from each other. Otherwise, it returns the value 1.
function has_admin_group_changed() {
  if [[ "$CES_ADMIN_GROUP" = "$CES_ADMIN_GROUP_LAST" ]];
  then
    return 1
  else
    return 0
  fi
}

function install_default_plugins() {
  echo "Installing preconfigured plugins..."
  local PLUGINS

  if PLUGINS=$(doguctl config sonar.plugins.default); then
    echo "found plugins '${PLUGINS}' to be installed on startup"
    local USER=${1}
    local PASSWORD=${2}

    local storedIFS="${IFS}"
    IFS=','

    for plugin in $PLUGINS; do
      install_plugin_via_api "$plugin" "$USER" "$PASSWORD"
    done

    IFS="${storedIFS}"
    echo "finished installation of default plugins"
  else
    echo "no key sonar.plugins.default found"
  fi
}

function ensure_correct_branch_plugin_state() {
  EXTENSIONS_FOLDER="${SONARQUBE_HOME}/extensions"
  COMMON_FOLDER="${SONARQUBE_HOME}/lib/common"
  PLUGIN_NAME="sonarqube-community-branch-plugin"

  if [[ -e "${COMMON_FOLDER}/${PLUGIN_NAME}.jar" ]]; then
    echo "Remove community branch plugin from ${COMMON_FOLDER}"
    rm "${COMMON_FOLDER}/${PLUGIN_NAME}.jar"
  fi

  BRANCH_PLUGIN_WEB_OPTS=""
  BRANCH_PLUGIN_CE_OPTS=""
  # the branch plugin could be in the plugins dir or in the downloads dir if it is new
  for f in "${EXTENSIONS_FOLDER}"/{plugins,downloads}/sonarqube-community-branch-plugin*.jar
  do
    if [[  -e "$f" ]]; then
      echo "Copy community branch plugin ${f} to ${COMMON_FOLDER}"
      cp "$f" "${COMMON_FOLDER}/${PLUGIN_NAME}.jar"
      BRANCH_PLUGIN_FILENAME="-javaagent:./extensions/plugins/$(basename "${f}")"
      BRANCH_PLUGIN_WEB_OPTS="${BRANCH_PLUGIN_FILENAME}=web \\"
      BRANCH_PLUGIN_CE_OPTS="${BRANCH_PLUGIN_FILENAME}=ce \\"
    fi
  done
  export BRANCH_PLUGIN_WEB_OPTS
  export BRANCH_PLUGIN_CE_OPTS
}

### End of function declarations, work is done now

if [[ -e ${SONARQUBE_HOME}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar ]]; then
  echo "Moving cas plugin to plugins folder..."
  mkdir -p "${SONARQUBE_HOME}/extensions/plugins"
  if ls "${SONARQUBE_HOME}"/extensions/plugins/sonar-cas-plugin-*.jar 1> /dev/null 2>&1; then
    rm "${SONARQUBE_HOME}"/extensions/plugins/sonar-cas-plugin-*.jar
  fi
  mv "${SONARQUBE_HOME}/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar" "${SONARQUBE_HOME}/extensions/plugins/sonar-cas-plugin-${CAS_PLUGIN_VERSION}.jar"
fi

doguctl state "waitingForPostgreSQL"

echo "Waiting until postgresql passes all health checks..."
if ! doguctl healthy --wait --timeout ${HEALTH_TIMEOUT} postgresql; then
  echo "Timeout reached by waiting of postgresql to get healthy"
  exit 1
else
  echo "Postgresql is healthy"
fi

echo "Creating truststore..."
# Using non-default truststore, because sonar user has no write permissions to /etc/ssl
# The path is configured in sonar.properties
create_truststore.sh "${SONARQUBE_HOME}"/truststore.jks > /dev/null

doguctl state "configuring..."

echo "Ensure correct branch plugin state"
ensure_correct_branch_plugin_state

echo "Rendering sonar properties template..."
render_properties_template

startSonarQubeInBackground "configuration api"

# check whether post-upgrade script is still running
while [[ "$(doguctl config post_upgrade_running)" == "true" ]]; do
  echo "Post-upgrade script is running. Waiting..."
  sleep 3
done

# add temporary admin to to configuration
remove_last_temp_admin
update_last_temp_admin_in_registry "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_GROUP}"

# check whether firstSonarStart has already been performed
if [[ "$(doguctl config successfulFirstStart)" != "true" ]]; then
  IS_FIRST_START="true"
  create_temporary_admin_for_first_start
  first_sonar_start
else
  IS_FIRST_START="false"
  create_temporary_admin_for_subsequent_start
  subsequent_sonar_start
fi

if has_admin_group_changed
then
  remove_permissions_from_last_admin_group
else
  echo "Did not detect a change of the admin group. Continue as usual..."
fi

update_last_admin_group_in_registry "${CES_ADMIN_GROUP}"

if existsPermissionTemplate "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}" ; then
  addCesAdminGroupToPermissionTemplate "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
fi

if shouldCesAdminGroupToAllProjects ; then
  addCesAdminGroupToProject "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  # adding a group is a time-expensive action (~2 sec per project). Resetting the key avoids unnecessary downtime.
  resetAddCesAdminGroupToProjectKey
fi

echo "Setting sonar.core.serverBaseURL..."
set_property_via_rest_api "sonar.core.serverBaseURL" "https://${FQDN}/sonar" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"

echo "Setting email.from configuration..."
set_property_via_rest_api "email.from" "${MAIL_ADDRESS}" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"

install_default_plugins "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"

echo "Configuration done, stopping SonarQube..."
stopSonarQube ${SONAR_PROCESS_ID}

if [[ "${IS_FIRST_START}" == "true" ]]; then
  # remove the es6 cache since it contains leftovers of the default admin
  echo "Removing es6 cache..."
#  rm -r /opt/sonar/data/es6
fi

echo "Removing temporary admin..."
remove_temporary_admin_user_and_group

# in order to import quality profiles the plugin installation must be finished along with a sonar restart
if areQualityProfilesPresentToImport; then
  # the temporary admin has different permissions during first start and subsequent start
  # only the subsequent temporary admin has sufficient privileges to import quality profiles
  create_temporary_admin_for_subsequent_start
  startSonarQubeInBackground "importing quality profiles"

  importQualityProfiles "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"

  stopSonarQube "${SONAR_PROCESS_ID}"
  remove_temporary_admin_user_and_group
fi

doguctl state "ready"

exec tail -F /opt/sonar/logs/es.log & # this tail on the elasticsearch logs is a temporary workaround, see https://github.com/docker-library/official-images/pull/6361#issuecomment-516184762

if [[ "$(doguctl config "container_config/memory_limit" -d "empty")" == "empty" ]];  then
  echo "Starting SonarQube without memory limits..."
  exec java -jar /opt/sonar/lib/sonar-application-"${SONAR_VERSION}".jar
else
  # Retrieve configurable java limits from etcd, valid default values exist
  MEMORY_LIMIT_MAX_PERCENTAGE=$(doguctl config "container_config/java_sonar_main_max_ram_percentage")
  MEMORY_LIMIT_MIN_PERCENTAGE=$(doguctl config "container_config/java_sonar_main_min_ram_percentage")

  echo "Starting SonarQube with memory limits MaxRAMPercentage: ${MEMORY_LIMIT_MAX_PERCENTAGE} and MinRAMPercentage: ${MEMORY_LIMIT_MIN_PERCENTAGE}..."
  exec java -XX:MaxRAMPercentage="${MEMORY_LIMIT_MAX_PERCENTAGE}" \
            -XX:MinRAMPercentage="${MEMORY_LIMIT_MIN_PERCENTAGE}" \
            -jar /opt/sonar/lib/sonar-application-"${SONAR_VERSION}".jar
fi
