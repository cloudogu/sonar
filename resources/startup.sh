#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# import util functions:
# execute_sql_statement_on_database()
# wait_for_sonar_status_endpoint()
# wait_for_sonar_to_get_up()
# wait_for_sonar_to_get_healthy()
# create_dogu_admin_user_and_save_password()
# create_user_via_rest_api()
# add_user_to_group_via_rest_api()
# create_dogu_admin_and_deactivate_default_admin()
# set_successful_first_start_flag()
# DOGU_ADMIN variable
# shellcheck disable=SC1091
source util.sh

# export so cas-plugin can use this env variable
export SONAR_PROPERTIES_FILE=/opt/sonar/conf/sonar.properties

# get variables
CES_ADMIN_GROUP=$(doguctl config --global admin_group)
FQDN=$(doguctl config --global fqdn)
DOMAIN=$(doguctl config --global domain)
MAIL_ADDRESS=$(doguctl config --default "sonar@${DOMAIN}" --global mail_address)
QUALITY_PROFILE_DIR="/var/lib/qualityprofiles"
CURL_LOG_LEVEL="--silent"
HEALTH_TIMEOUT=600

function import_quality_profiles_if_present {
  AUTH_USER=$1
  AUTH_PASSWORD=$2
  echo "Check for quality profiles to import..."
  # only import profiles if quality profiles are present
  if [[ "$(ls -A "${QUALITY_PROFILE_DIR}")" ]];
  then
    # import all quality profiles that are in the suitable directory
    for file in "${QUALITY_PROFILE_DIR}"/*
    do
      # ignore CasAuthenticationExceptions in log file, because the credentials below only work locally
      RESPONSE_IMPORT=$(curl ${CURL_LOG_LEVEL} --fail -X POST -u "${AUTH_USER}":"${AUTH_PASSWORD}" -F "backup=@$file" localhost:9000/sonar/api/qualityprofiles/restore)
      # check if import is successful
      if ! ( echo "${RESPONSE_IMPORT}" | grep -o errors);
      then
        echo "Import of quality profile $file was successful"
        # delete file if import was successful
        rm -f "$file"
        echo "Removed $file file"
      else
        echo "Import of quality profile $file has not been successful"
        echo "${RESPONSE_IMPORT}"
      fi;
    done;
  else
    echo "No quality profiles to import"
  fi;
}

function setProxyConfiguration(){
  removeProxyRelatedEntriesFrom ${SONAR_PROPERTIES_FILE}
  # Write proxy settings if enabled in etcd
  if [[ "true" == "$(doguctl config --global proxy/enabled)" ]]; then
    if PROXYSERVER=$(doguctl config --global proxy/server) && PROXYPORT=$(doguctl config --global proxy/port); then
      writeProxyCredentialsTo ${SONAR_PROPERTIES_FILE}
      if PROXYUSER=$(doguctl config --global proxy/username) && PROXYPASSWORD=$(doguctl config --global proxy/password); then
        writeProxyAuthenticationCredentialsTo ${SONAR_PROPERTIES_FILE}
      else
        echo "Proxy authentication credentials are incomplete or not existent."
      fi
    else
      echo "Proxy server or port configuration missing in etcd."
    fi
  fi
}

function removeProxyRelatedEntriesFrom() {
  sed -i '/http.proxyHost=.*/d' "$1"
  sed -i '/http.proxyPort=.*/d' "$1"
  sed -i '/http.proxyUser=.*/d' "$1"
  sed -i '/http.proxyPassword=.*/d' "$1"
}

function writeProxyCredentialsTo(){
  echo http.proxyHost="${PROXYSERVER}" >> "$1"
  echo http.proxyPort="${PROXYPORT}" >> "$1"
}

function writeProxyAuthenticationCredentialsTo(){
  # Check for java option and add it if not existent
  if ! grep sonar.web.javaAdditionalOpts= "$1" | grep -q Djdk.http.auth.tunneling.disabledSchemes= ; then
    sed -i '/^sonar.web.javaAdditionalOpts=/ s/$/ -Djdk.http.auth.tunneling.disabledSchemes=/' "$1"
  fi
  # Add proxy authentication credentials
  echo http.proxyUser="${PROXYUSER}" >> ${SONAR_PROPERTIES_FILE}
  echo http.proxyPassword="${PROXYPASSWORD}" >> ${SONAR_PROPERTIES_FILE}
}

function render_properties_template() {
  doguctl template "${SONAR_PROPERTIES_FILE}.tpl" "${SONAR_PROPERTIES_FILE}"
}

function set_property_via_rest_api() {
  PROPERTY=$1
  VALUE=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/settings/set?key=${PROPERTY}&value=${VALUE}"
}

function create_user_group_via_rest_api() {
  NAME=$1
  DESCRIPTION=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/user_groups/create?name=${NAME}&description=${DESCRIPTION}"
}

function grant_permission_to_group_via_rest_api() {
  GROUPNAME=$1
  PERMISSION=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/permissions/add_group?permission=${PERMISSION}&groupName=${GROUPNAME}"
}

function get_out_of_date_plugins_via_rest_api() {
  AUTH_USER=$1
  AUTH_PASSWORD=$2
  OUT_OF_DATE_PLUGINS=$(curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X GET "http://localhost:9000/sonar/api/plugins/updates" | jq '.plugins' | jq '.[]' | jq -r '.key')
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
  echo  "Adding CES admin group..."
  create_user_group_via_rest_api "${CES_ADMIN_GROUP}" "CESAdministratorGroup" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

  printf "\\nAdding admin privileges to CES admin group...\\n"
  grant_permission_to_group_via_rest_api "${CES_ADMIN_GROUP}" "admin" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
  grant_permission_to_group_via_rest_api "${CES_ADMIN_GROUP}" "profileadmin" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
  grant_permission_to_group_via_rest_api "${CES_ADMIN_GROUP}" "gateadmin" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
  grant_permission_to_group_via_rest_api "${CES_ADMIN_GROUP}" "provisioning" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

  set_updatecenter_url_if_configured_in_registry "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

  echo "Setting email configuration..."
  set_property_via_rest_api "email.smtp_host.secured" "postfix" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
  set_property_via_rest_api "email.smtp_port.secured" "25" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
  set_property_via_rest_api "email.prefix" "[SONARQUBE]" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

  get_out_of_date_plugins_via_rest_api "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
  if [[ -n "${OUT_OF_DATE_PLUGINS}" ]]; then
    echo "The following plugins are not up-to-date:"
    echo "${OUT_OF_DATE_PLUGINS}"
    while read -r PLUGIN; do
      echo "Updating plugin ${PLUGIN}..."
      curl ${CURL_LOG_LEVEL} --fail -u "${DOGU_ADMIN}":"${DOGU_ADMIN_PASSWORD}" -X POST "localhost:9000/sonar/api/plugins/update?key=${PLUGIN}"
      echo "Plugin ${PLUGIN} updated"
    done <<< "${OUT_OF_DATE_PLUGINS}"
  fi
}

# parameter: process-id of sonar
function stopSonarQube() {
    # kill SonarQube and all child processes
    kill "${1}"
    # wait for processes to finish
    wait "${1}" || true
}

function firstSonarStart() {
  echo "First start of SonarQube dogu"

  create_dogu_admin_and_deactivate_default_admin ${CURL_LOG_LEVEL}

  echo "Waiting for SonarQube to get healthy (max. ${HEALTH_TIMEOUT} seconds)..."
  wait_for_sonar_to_get_healthy ${HEALTH_TIMEOUT} "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}" ${CURL_LOG_LEVEL}

  run_first_start_tasks

  set_successful_first_start_flag
}

function subsequentSonarStart() {
  echo "Subsequent start of SonarQube dogu"
  DOGU_ADMIN_PASSWORD=$(doguctl config -e dogu_admin_password)

  echo "Removing and re-creating ${DOGU_ADMIN} user..."
  # Remove dogu admin user, because it may have been changed by logging in with the same name
  execute_sql_statement_on_database "DELETE FROM users WHERE login='${DOGU_ADMIN}';"
  # Re-create dogu admin user
  TEMPORARY_ADMIN_USER=$(doguctl random)
  add_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
  create_dogu_admin_user_and_save_password "${TEMPORARY_ADMIN_USER}" admin ${CURL_LOG_LEVEL}
  remove_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
  DOGU_ADMIN_PASSWORD=$(doguctl config -e dogu_admin_password)

  echo "Waiting for SonarQube to get healthy (max. ${HEALTH_TIMEOUT} seconds)..."
  wait_for_sonar_to_get_healthy ${HEALTH_TIMEOUT} "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}" ${CURL_LOG_LEVEL}

  set_updatecenter_url_if_configured_in_registry "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

  # Creating CES admin group if not existent or if it has changed
  ADMIN_GROUP_COUNT=$(curl ${CURL_LOG_LEVEL} --fail -u "${DOGU_ADMIN}":"${DOGU_ADMIN_PASSWORD}" -X GET "http://localhost:9000/sonar/api/user_groups/search?q=${CES_ADMIN_GROUP}" | jq '.paging' | jq -r '.total')
  if [[ ${ADMIN_GROUP_COUNT} == 0 ]]; then
    echo  "Adding CES admin group..."
    create_user_group_via_rest_api "${CES_ADMIN_GROUP}" "CESAdministratorGroup" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

    printf "\\nAdding admin privileges to CES admin group...\\n"
    grant_permission_to_group_via_rest_api "${CES_ADMIN_GROUP}" "admin" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
  fi
}

function getLastAdminGroupOrGlobalAdminGroup() {
    if CES_ADMIN_GROUP_LAST=$(doguctl config admin_group_last) ;
    then
        return ${CES_ADMIN_GROUP_LAST}
    else
        # this group name is used either way to check if it is equal with the global admin group
        # instead of unnecessarily check for empty strings we return a valid value for the equal-check
        return $(doguctl config --global admin_group)
    fi
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
create_truststore.sh "${SONARQUBE_HOME}"/truststore.jks > /dev/null

doguctl state "configuring..."

echo "Rendering sonar properties template..."
render_properties_template

echo "Setting proxy configuration, if existent..."
setProxyConfiguration

echo "Starting SonarQube... "
java -jar /opt/sonar/lib/sonar-application-"${SONAR_VERSION}".jar &
SONAR_PROCESS_ID=$!

echo "Waiting for SonarQube status endpoint to be available (max. ${HEALTH_TIMEOUT} seconds)..."
wait_for_sonar_status_endpoint ${HEALTH_TIMEOUT}

echo "Waiting for SonarQube to get up (max. ${HEALTH_TIMEOUT} seconds)..."
wait_for_sonar_to_get_up ${HEALTH_TIMEOUT}

# check whether post-upgrade script is still running
while [[ "$(doguctl config post_upgrade_running)" == "true" ]]; do
  echo "Post-upgrade script is running. Waiting..."
  sleep 3
done

# check whether firstSonarStart has already been performed
if [ "$(doguctl config successfulFirstStart)" != "true" ]; then
  firstSonarStart
else
  subsequentSonarStart
fi

if [[ ${CES_ADMIN_GROUP} == $(getLastAdminGroupOrGlobalAdminGroup) ]];
then
    echo "Did not detect a change of the admin group. Continue as usual"
else
    remove_permissions_from_last_admin_group
fi

echo "Setting sonar.core.serverBaseURL..."
set_property_via_rest_api "sonar.core.serverBaseURL" "https://${FQDN}/sonar" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

import_quality_profiles_if_present "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

echo "Setting email.from configuration..."
set_property_via_rest_api "email.from" "${MAIL_ADDRESS}" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

echo "Configuration done, stopping SonarQube..."
stopSonarQube ${SONAR_PROCESS_ID}

doguctl state "ready"

echo "Starting SonarQube..."
exec java -jar /opt/sonar/lib/sonar-application-"${SONAR_VERSION}".jar
