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
# create_user_via_rest_api()
# add_user
# add_user_to_group_via_rest_api()
# set_successful_first_start_flag()
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
CURL_LOG_LEVEL="--silent"
API_ENDPOINT="http://localhost:9000/sonar/api"
HEALTH_TIMEOUT=600
ADMIN_PERMISSIONS="admin profileadmin gateadmin provisioning"
PROJECT_PERMISSIONS="admin codeviewer issueadmin securityhotspotadmin scan user"
DEFAULT_PERMISSION_TEMPLATE_NAME="Default template"
KEY_AMEND_PROJECTS_WITH_CESADMIN_PERMISSIONS="amend_projects_with_ces_admin_permissions"
TEMPORARY_ADMIN_GROUP=$(doguctl random)
TEMPORARY_ADMIN_USER=$(doguctl random)
TEMPORARY_ADMIN_PASSWORD=$(doguctl random)
QUALITY_PROFILE_DIR="/var/lib/qualityprofiles"
TEMPORARY_PROFILE_ADMIN_GROUP=$(doguctl random)
TEMPORARY_PROFILE_ADMIN_USER=$(doguctl random)
TEMPORARY_PROFILE_ADMIN_PASSWORD=$(doguctl random)

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
    importResponse=$(curl "${CURL_LOG_LEVEL}" -X POST -u "${AUTH_USER}":"${AUTH_PASSWORD}" -F "backup=@${file}" "${API_ENDPOINT}"/qualityprofiles/restore)

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
  echo "Setting configuration property ${PROPERTY}..."
  curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "${API_ENDPOINT}/settings/set?key=${PROPERTY}&value=${VALUE}"
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
    echo "All projects should be amended with CES-Admin group permissions..."
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
  projects=$(curl ${CURL_LOG_LEVEL} -f -u  "${authUser}":"${authPassword}" "${getProjectsRequest}" | jq -r '.components[] | .key') || exitCode=$?
  if [[ "${exitCode}" != "0" ]]; then
    echo "ERROR: Fetching projects failed with code ${exitCode}. Abort granting project permissions to group ${groupToAdd}..."
    return
  fi

  for projectKey in ${projects}; do
    echo "Adding group ${groupToAdd} to project ${projectKey}..."
    # use projectKey for logging (easy to find in UI) and projectId for requests (projectKey may contain nasty special characters)
    addCesAdminGroupToProjectWithPermissions "${groupToAdd}" "${projectKey}" "${authUser}" "${authPassword}"
  done
}

# Adds a group with permissions defined by the variable 'PROJECT_PERMISSIONS' to a specific project identified by its key
#
# usage: addCesAdminGroupToProjectWithPermissions <group> <project key> <user> <password>
function addCesAdminGroupToProjectWithPermissions() {
  local groupToAdd=${1}
  local projectKey=${2}
  local authUser=${3}
  local authPassword=${4}
  local additionalParams="projectKey=${projectKey}"

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

function run_first_start_tasks() {
  echo "Adding CES admin group '${CES_ADMIN_GROUP}'..."
  create_user_group_via_rest_api "${CES_ADMIN_GROUP}" "CESAdministratorGroup" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  grant_admin_group_permissions "${CES_ADMIN_GROUP}" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  set_updatecenter_url_if_configured_in_registry "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  echo "Setting email configuration..."
  set_property_via_rest_api "email.smtp_host.secured" "postfix" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  set_property_via_rest_api "email.smtp_port.secured" "25" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  set_property_via_rest_api "email.prefix" "\[SONARQUBE\]" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  echo "Getting out-of-date plugins..."
  get_out_of_date_plugins_via_rest_api "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  if [[ -n "${OUT_OF_DATE_PLUGINS}" ]]; then
    echo "The following plugins are not up-to-date:"
    echo "${OUT_OF_DATE_PLUGINS}"
    while read -r PLUGIN; do
      echo "Updating plugin ${PLUGIN}..."
      curl ${CURL_LOG_LEVEL} --fail -u "${TEMPORARY_ADMIN_USER}":"${TEMPORARY_ADMIN_PASSWORD}" -X POST "localhost:9000/sonar/api/plugins/update?key=${PLUGIN}"
      echo "Plugin ${PLUGIN} updated"
    done <<< "${OUT_OF_DATE_PLUGINS}"
  else
    echo "There are no out-of-date plugins"
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

function create_temporary_admin() {
  echo "Creating Temporary admin user..."
  # Create temporary admin only in database
  echo "Adding temporary admin group..."
  add_temporary_admin_group "${TEMPORARY_ADMIN_GROUP}"
  echo "Adding temporary admin user..."
  add_user "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  echo "Adding temporary admin user to temporary admin group..."
  assign_group "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_GROUP}"
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

function remove_permissions_from_last_admin_group() {
  local admin_group=${CES_ADMIN_GROUP_LAST}
  printf "Remove admin privileges from previous CES admin group '%s'...\\n" "${admin_group}"

  for permission in ${ADMIN_PERMISSIONS}
  do
    printf "remove permission '%s' from group '%s'...\\n" "${permission}" "${admin_group}"
    remove_group "${admin_group}"
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

function setDoguLogLevel() {
  local currentLogLevel SONAR_LOGLEVEL
  currentLogLevel=$(doguctl config "logging/root")

  if ! doguctl validate logging/root --silent ; then
    echo "WARNING: Found invalid value in logging/root. Resetting it to INFO"
    doguctl config logging/root INFO
  fi

  echo "Mapping configured log level to available log levels..."
  case "${currentLogLevel}" in
    "TRACE")
      export SONAR_LOGLEVEL="TRACE"
    ;;
    "DEBUG")
      export SONAR_LOGLEVEL="DEBUG"
    ;;
    *)
      export SONAR_LOGLEVEL="INFO"
    ;;
  esac
  echo "Log level is now: ${SONAR_LOGLEVEL}"
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

echo "Configuring log level..."
setDoguLogLevel

echo "Rendering sonar properties template..."
render_properties_template

startSonarQubeInBackground "configuration api"

# check whether post-upgrade script is still running
while [[ "$(doguctl config post_upgrade_running)" == "true" ]]; do
  echo "Post-upgrade script is running. Waiting..."
  sleep 3
done

# add temporary admin to configuration
remove_last_temp_admin
update_last_temp_admin_in_registry "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_GROUP}"

echo "Creating Temporary admin user..."
create_temporary_admin

# check whether firstSonarStart has already been performed
if [[ "$(doguctl config successfulFirstStart)" != "true" ]]; then
  IS_FIRST_START="true"
  first_sonar_start
else
  IS_FIRST_START="false"
  subsequent_sonar_start
fi

if has_admin_group_changed
then
  remove_permissions_from_last_admin_group
else
  echo "Did not detect a change of the admin group. Continue as usual..."
fi

update_last_admin_group_in_registry "${CES_ADMIN_GROUP}"

if existsPermissionTemplate "${DEFAULT_PERMISSION_TEMPLATE_NAME}" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}" ; then
  addCesAdminGroupToPermissionTemplate "${DEFAULT_PERMISSION_TEMPLATE_NAME}" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
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
remove_user "${TEMPORARY_ADMIN_USER}"
remove_group "${TEMPORARY_ADMIN_GROUP}"

# in order to import quality profiles the plugin installation must be finished along with a sonar restart
if areQualityProfilesPresentToImport; then
  # the temporary admin has different permissions during first start and subsequent start
  # only the subsequent temporary admin has sufficient privileges to import quality profiles
  startSonarQubeInBackground "importing quality profiles"

  echo "Creating Temporary admin user for profile import..."
  # Create temporary admin only in database
  add_temporary_admin_group "${TEMPORARY_PROFILE_ADMIN_GROUP}" "profileadmin"
  add_user "${TEMPORARY_PROFILE_ADMIN_USER}" "${TEMPORARY_PROFILE_ADMIN_PASSWORD}"
  assign_group "${TEMPORARY_PROFILE_ADMIN_USER}" "${TEMPORARY_PROFILE_ADMIN_GROUP}"

  importQualityProfiles "${TEMPORARY_PROFILE_ADMIN_USER}" "${TEMPORARY_PROFILE_ADMIN_PASSWORD}"

  stopSonarQube "${SONAR_PROCESS_ID}"
  remove_user "${TEMPORARY_PROFILE_ADMIN_USER}"
  remove_group "${TEMPORARY_PROFILE_ADMIN_GROUP}"
fi

cp casLogoutUrl.js /opt/sonar/web/js/

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
