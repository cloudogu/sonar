#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# import util functions:
# execute_sql_statement_on_database()
# wait_for_sonar_status_endpoint()
# wait_for_sonar_to_get_up()
source util.sh

# export so cas-plugin can use this env variable
export SONAR_PROPERTIES_FILE=/opt/sonar/conf/sonar.properties

# get variables
CES_ADMIN_GROUP=$(doguctl config --global admin_group)
FQDN=$(doguctl config --global fqdn)
DOMAIN=$(doguctl config --global domain)
MAIL_ADDRESS=$(doguctl config --default "sonar@${DOMAIN}" --global mail_address)
QUALITY_PROFILE_DIR="/var/lib/qualityprofiles"
DOGU_ADMIN="sonarqubedoguadmin"
CURL_LOG_LEVEL="--silent"

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

function wait_for_sonar_to_get_healthy() {
  WAIT_TIMEOUT=${1}
  USER=$2
  PASSWORD=$3
  for i in $(seq 1 "${WAIT_TIMEOUT}"); do
    SONAR_HEALTH_STATUS=$(curl ${CURL_LOG_LEVEL} --fail -u "${USER}":"${PASSWORD}" http://localhost:9000/sonar/api/system/health | jq -r '.health')
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

function create_user_via_rest_api() {
  LOGIN=$1
  NAME=$2
  PASSWORD=$3
  AUTH_USER=$4
  AUTH_PASSWORD=$5
  curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/create?login=${LOGIN}&name=${NAME}&password=${PASSWORD}&local=true"
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

function add_user_to_group_via_rest_api() {
  USERNAME=$1
  GROUPNAME=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  curl ${CURL_LOG_LEVEL} --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/user_groups/add_user?name=${GROUPNAME}&login=${USERNAME}"
}

function configureUpdatecenterUrl() {
  # remove updatecenter url configuration, if existent
  sed -i '/sonar.updatecenter.url=/d' ${SONAR_PROPERTIES_FILE}
  # set updatecenter url if configured in registry
  if doguctl config sonar.updatecenter.url > /dev/null; then
    updatecenterUrl=$(doguctl config sonar.updatecenter.url)
    echo "Setting sonar.updatecenter.url to ${updatecenterUrl}"
    echo sonar.updatecenter.url="${updatecenterUrl}" >> ${SONAR_PROPERTIES_FILE}
  fi
}

function firstSonarStart() {
  echo "First start of SonarQube dogu"

  echo "Waiting for SonarQube to get healthy (max. 120 seconds)..."
  # default admin credentials (admin, admin) are used
  wait_for_sonar_to_get_healthy 120 admin admin

  echo "Creating ${DOGU_ADMIN} and granting admin permissions..."
  DOGU_ADMIN_PASSWORD=$(doguctl random)
  # default admin credentials (admin, admin) are used
  create_user_via_rest_api "${DOGU_ADMIN}" "SonarQubeDoguAdmin" "${DOGU_ADMIN_PASSWORD}" admin admin
  add_user_to_group_via_rest_api "${DOGU_ADMIN}" sonar-administrators admin admin
  # saving dogu admin password in registry
  doguctl config -e dogu_admin_password "${DOGU_ADMIN_PASSWORD}"
  printf "\\n"

  echo  "Adding CES admin group..."
  create_user_group_via_rest_api "${CES_ADMIN_GROUP}" "CESAdministratorGroup" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

  printf "\\nAdding admin privileges to CES admin group...\\n"
  grant_permission_to_group_via_rest_api "${CES_ADMIN_GROUP}" "admin" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

  echo "Setting email configuration..."
  set_property_via_rest_api "email.smtp_host.secured" "postfix" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
  set_property_via_rest_api "email.smtp_port.secured" "25" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
  set_property_via_rest_api "email.prefix" "[SONARQUBE]" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

  echo "Removing default admin account..."
  execute_sql_statement_on_database "DELETE FROM users WHERE login='admin';"

  echo "Waiting for configuration changes to be internally executed..."
  sleep 3

  echo "Setting successfulFirstStart registry key..."
  doguctl config successfulFirstStart true
}

# parameter: process-id of sonar
function stopSonarQube() {
    # kill SonarQube and all child processes
    kill "${1}"
    # wait for processes to finish
    wait "${1}" || true
}

function subsequentSonarStart() {
  echo "Subsequent start of SonarQube dogu"
  DOGU_ADMIN_PASSWORD=$(doguctl config -e dogu_admin_password)

  # TODO: Restore sonarqubedoguadmin if it has been removed

  echo "Waiting for SonarQube to get healthy (max. 120 seconds)..."
  wait_for_sonar_to_get_healthy 120 "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"
}



### End of function declarations, work is done now

doguctl state "waitingForPostgreSQL"

echo "Waiting until postgresql passes all health checks..."
if ! doguctl healthy --wait --timeout 120 postgresql; then
  echo "Timeout reached by waiting of postgresql to get healthy"
  exit 1
else
  echo "Postgresql is healthy"
fi

# create truststore, which is used in the sonar.properties file
create_truststore.sh > /dev/null

doguctl state "configuring..."

echo "Rendering sonar properties template..."
render_properties_template

echo "Setting proxy configuration, if existent..."
setProxyConfiguration

echo "Starting SonarQube... "
java -jar /opt/sonar/lib/sonar-application-"${SONAR_VERSION}".jar &
SONAR_PROCESS_ID=$!

echo "Waiting for SonarQube status endpoint to be available (max. 120 seconds)..."
wait_for_sonar_status_endpoint 120

echo "Waiting for SonarQube to get up (max. 120 seconds)..."
wait_for_sonar_to_get_up 120

# check whether firstSonarStart has already been performed
if [ "$(doguctl config successfulFirstStart)" != "true" ]; then
  firstSonarStart
else
  subsequentSonarStart
fi

echo "Setting sonar.core.serverBaseURL..."
set_property_via_rest_api "sonar.core.serverBaseURL" "https://${FQDN}/sonar" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

import_quality_profiles_if_present "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

configureUpdatecenterUrl

echo "Setting email.from configuration..."
set_property_via_rest_api "email.from" "${MAIL_ADDRESS}" "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}"

echo "Configuration done, stopping SonarQube..."
stopSonarQube ${SONAR_PROCESS_ID}

doguctl state "ready"

echo "Starting SonarQube..."
exec java -jar /opt/sonar/lib/sonar-application-"${SONAR_VERSION}".jar
