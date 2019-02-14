#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# import util functions:
# sql()
# add_temporary_admin_user()
# remove_temporary_admin_user functions()
# wait_for_sonar_status_endpoint()
# wait_for_sonar_to_get_up()
source util.sh

SONAR_PROPERTIES_FILE=/opt/sonar/conf/sonar.properties

# get variables
ADMIN_GROUP=$(doguctl config --global admin_group)
FQDN=$(doguctl config --global fqdn)
DOMAIN=$(doguctl config --global domain)
MAIL_ADDRESS=$(doguctl config --default "sonar@${DOMAIN}" --global mail_address)
DATABASE_IP=postgresql
DATABASE_USER=$(doguctl config -e sa-postgresql/username)
DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
DATABASE_DB=$(doguctl config -e sa-postgresql/database)
QUALITY_PROFILE_DIR="/var/lib/qualityprofiles"

function import_quality_profiles_if_present {
    echo "check for quality profiles to import..."
    # only import profiles if quality profiles are present
    if [[ "$(ls -A "${QUALITY_PROFILE_DIR}")" ]];
    then
      # temporarily create admin user
      TEMPORARY_ADMIN_USER=$(doguctl random)
      add_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
      # import all quality profiles that are in the suitable directory
      for file in "${QUALITY_PROFILE_DIR}"/*
      do
        # ignore CasAuthenticationExceptions in log file, because the credentials below only work locally
        RESPONSE_IMPORT=$(curl --silent -X POST -u "${TEMPORARY_ADMIN_USER}":admin -F "backup=@$file" localhost:9000/sonar/api/qualityprofiles/restore)
        # check if import is successful
        if ! ( echo "${RESPONSE_IMPORT}" | grep -o errors);
        then
          echo "import of quality profile $file was successful"
          # delete file if import was successful
          rm -f "$file"
          echo "removed $file file"
        else
          echo "import of quality profile $file has not been successful"
          echo "${RESPONSE_IMPORT}"
        fi;
      done;
      remove_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
    else
      echo "no quality profiles to import"
    fi;
}

function move_sonar_dir(){
  DIR="$1"
  if [[ ! -d "/var/lib/sonar/$DIR" ]]; then
    mv "/opt/sonar/$DIR" /var/lib/sonar
    ln -s "/var/lib/sonar/$DIR" "/opt/sonar/$DIR"
  elif [[ ! -L "/opt/sonar/$DIR" ]] && [[ -d "/opt/sonar/$DIR" ]]; then
    rm -rf "/opt/sonar/$DIR"
    ln -s "/var/lib/sonar/$DIR" "/opt/sonar/$DIR"
  fi
}

function wait_for_sonar_to_get_healthy_with_default_admin_credentials() {
  WAIT_TIMEOUT=${1}
  for i in $(seq 1 "${WAIT_TIMEOUT}"); do
    SONAR_HEALTH_STATUS=$(curl -s -u admin:admin http://localhost:9000/sonar/api/system/health | jq -r '.health')
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
  if [[ -z "$(grep sonar.web.javaAdditionalOpts= "$1" | grep Djdk.http.auth.tunneling.disabledSchemes=)" ]]; then
    sed -i '/^sonar.web.javaAdditionalOpts=/ s/$/ -Djdk.http.auth.tunneling.disabledSchemes=/' "$1"
  fi
  # Add proxy authentication credentials
  echo http.proxyUser="${PROXYUSER}" >> ${SONAR_PROPERTIES_FILE}
  echo http.proxyPassword="${PROXYPASSWORD}" >> ${SONAR_PROPERTIES_FILE}
}

function set_property_with_default_admin_credentials() {
  PROPERTY=$1
  VALUE=$2
  curl -s -u admin:admin -X POST "http://localhost:9000/sonar/api/settings/set?key=${PROPERTY}&value=${VALUE}"
}

function create_user_group_with_default_admin_credentials() {
  NAME=$1
  DESCRIPTION=$2
  curl -s -u admin:admin -X POST "http://localhost:9000/sonar/api/user_groups/create?name=${NAME}&description=${DESCRIPTION}"
}

function grant_permission_to_group_with_default_admin_credentials() {
  GROUPNAME=$1
  PERMISSION=$2
  curl -s -u admin:admin -X POST "http://localhost:9000/sonar/api/permissions/add_group?permission=${PERMISSION}&groupName=${GROUPNAME}"
}

function change_password_with_default_admin_credentials() {
  LOGIN=$1
  PREVIOUS_PASSWORD=$2
  NEW_PASSWORD=$3
  curl -s -u admin:admin -X POST "http://localhost:9000/sonar/api/users/change_password?login=${LOGIN}&password=${NEW_PASSWORD}&previousPassword=${PREVIOUS_PASSWORD}"
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
  echo "Rendering sonar properties template "${SONAR_PROPERTIES_FILE}.tpl"..."
  doguctl template "${SONAR_PROPERTIES_FILE}.tpl" "${SONAR_PROPERTIES_FILE}"
	# move cas plugin to right folder
	if [[ -f "/opt/sonar/sonar-cas-plugin-0.3-TRIO-SNAPSHOT.jar" ]]; then
		mv /opt/sonar/sonar-cas-plugin-0.3-TRIO-SNAPSHOT.jar /var/lib/sonar/extensions/plugins/
	fi
  echo "Moving german language pack to correct folder..."
  if [[ -f "/opt/sonar/sonar-l10n-de-plugin-1.2.jar" ]]; then
    mv /opt/sonar/sonar-l10n-de-plugin-1.2.jar /var/lib/sonar/extensions/plugins/
  fi

  setProxyConfiguration

  echo "Starting SonarQube... "
  su - sonar -c "java -jar /opt/sonar/lib/sonar-application-$SONAR_VERSION.jar" &
  SONAR_PROCESS_ID=$!

  echo "Waiting for SonarQube status endpoint to be available (max. 120 seconds)..."
  wait_for_sonar_status_endpoint 120

  echo "Waiting for SonarQube to get up (max. 120 seconds)..."
  wait_for_sonar_to_get_up 120

  echo "Waiting for SonarQube to get healthy (max. 120 seconds)..."
  wait_for_sonar_to_get_healthy_with_default_admin_credentials 120

  # import quality profiles if directory is not empty
  import_quality_profiles_if_present

  echo "setting base url"
  set_property_with_default_admin_credentials "sonar.core.serverBaseURL" "https://${FQDN}/sonar"

  echo  "adding admin group"
  create_user_group_with_default_admin_credentials "${ADMIN_GROUP}" "CESAdministratorGroup"

  printf "\\nadding admin privileges to admin group\\n"
  grant_permission_to_group_with_default_admin_credentials "${ADMIN_GROUP}" "admin"

  echo "setting email configuration"
  set_property_with_default_admin_credentials "email.smtp_host.secured" "postfix"
  set_property_with_default_admin_credentials "email.smtp_port.secured" "25"
  set_property_with_default_admin_credentials "email.from" "${MAIL_ADDRESS}"
  set_property_with_default_admin_credentials "email.prefix" "[SONARQUBE]"

  echo "setting random password for default admin login"
  change_password_with_default_admin_credentials admin admin "$(doguctl random)"

  echo "waiting for configuration changes to be internally executed"
  sleep 3

  echo "stopping SonarQube to account for configuration changes"
  stopSonarQube ${SONAR_PROCESS_ID}
}

# parameter: process-id of sonar
function stopSonarQube() {
    # kill SonarQube and all child processes
    kill "${1}"
    # wait for processes to finish
    wait "${1}" || true
}

function subsequentSonarStart() {
  echo "subsequent start of SonarQube dogu"
  # refresh base url
  sql "UPDATE properties SET text_value='https://${FQDN}/sonar' WHERE prop_key='sonar.core.serverBaseURL';"

  # refresh FQDN
  sed -i "/sonar.cas.casServerLoginUrl=.*/c\sonar.cas.casServerLoginUrl=https://${FQDN}/cas/login" ${SONAR_PROPERTIES_FILE}
  sed -i "/sonar.cas.casServerUrlPrefix=.*/c\sonar.cas.casServerUrlPrefix=https://${FQDN}/cas" ${SONAR_PROPERTIES_FILE}
  sed -i "/sonar.cas.sonarServerUrl=.*/c\sonar.cas.sonarServerUrl=https://${FQDN}/sonar" ${SONAR_PROPERTIES_FILE}
  sed -i "/sonar.cas.casServerLogoutUrl=.*/c\sonar.cas.casServerLogoutUrl=https://${FQDN}/cas/logout" ${SONAR_PROPERTIES_FILE}

  setProxyConfiguration

  # import quality profiles if directory is not empty
  if [[ "$(ls -A "${QUALITY_PROFILE_DIR}")" ]];
  then
    echo "starting SonarQube for importing quality profiles..."
    su - sonar -c "java -jar /opt/sonar/lib/sonar-application-$SONAR_VERSION.jar" &
    SONAR_PROCESS_ID=$!

    echo "Waiting for SonarQube status endpoint to be available (max. 120 seconds)..."
    wait_for_sonar_status_endpoint 120

    echo "waiting for SonarQube to get up (max. 120 seconds)..."
    wait_for_sonar_to_get_up 120

    echo "importing quality profiles..."
    import_quality_profiles_if_present

    echo "stopping SonarQube after importing quality profiles"
    stopSonarQube ${SONAR_PROCESS_ID}
  fi
}



### End of function declarations, work is done now

doguctl state "internalPreparations"

move_sonar_dir conf
move_sonar_dir extensions
move_sonar_dir data
move_sonar_dir logs
move_sonar_dir temp

doguctl state "waitingForPostgreSQL"

echo "waiting until postgresql passes all health checks..."
if ! doguctl healthy --wait --timeout 120 postgresql; then
  echo "timeout reached by waiting of postgresql to get healthy"
  exit 1
else
  echo "postgresql is healthy"
fi

# create truststore, which is used in the sonar.properties file
create_truststore.sh > /dev/null

doguctl state "installing..."

# check whether initialization has already been performed
if [[ "$(grep sonar.security.realm ${SONAR_PROPERTIES_FILE})" != "sonar.security.realm=cas" ]]; then
  firstSonarStart # starts SonarQube, configures it and shuts it down afterwards
else
  subsequentSonarStart # may start SonarQube, import quality profiles and stop it afterwards
fi

configureUpdatecenterUrl

doguctl state "ready"

echo "Starting SonarQube..."
exec su - sonar -c "java -jar /opt/sonar/lib/sonar-application-$SONAR_VERSION.jar"
