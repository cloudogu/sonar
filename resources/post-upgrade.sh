#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# import util functions:
# execute_sql_statement_on_database()
# add_temporary_admin_user()
# remove_temporary_admin_user functions()
# wait_for_sonar_status_endpoint()
# wait_for_sonar_to_get_up()
# wait_for_sonar_to_get_healthy()
# create_dogu_admin_and_deactivate_default_admin()
# set_successful_first_start_flag()
source util.sh

FROM_VERSION="${1}"
TO_VERSION="${2}"
WAIT_TIMEOUT=600
CURL_LOG_LEVEL="--silent"
FAILED_PLUGIN_NAMES=""

##### functions declaration

function install_plugin_via_api() {
  PLUGIN=${1}
  INSTALL_RESPONSE=$(curl ${CURL_LOG_LEVEL} -u admin:admin -X POST http://localhost:9000/sonar/api/plugins/install?key="${PLUGIN}")
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
  while IFS=',' read -ra ADDR; do
    for PLUGIN in "${ADDR[@]}"; do
      echo "Checking if plugin ${PLUGIN} is installed already..."
      INSTALLED_PLUGINS=$(curl ${CURL_LOG_LEVEL} --fail -u admin:admin -X GET localhost:9000/sonar/api/plugins/installed | jq '.plugins' | jq '.[]' | jq -r '.key')
      if [[ ${INSTALLED_PLUGINS} == *"${PLUGIN}"* ]]; then
        echo "Plugin ${PLUGIN} is installed already"
      else
        echo "Plugin ${PLUGIN} is not installed, installing it..."
        install_plugin_via_api "${PLUGIN}"
      fi
    done
  done <<< "$(doguctl config install_plugins)"

  if [[ -n ${FAILED_PLUGIN_NAMES} ]]; then
    echo "The following plugins could not have been re-installed: ${FAILED_PLUGIN_NAMES}"
  fi
}


######

echo "Running post-upgrade script..."

doguctl config post_upgrade_running true

# Migrate saved extensions folder to its own volume
if [[ ${FROM_VERSION} == *"6.7.6-1"* ]]; then
  mkdir -p /opt/sonar/extensions
  cp -R /opt/sonar/data/extensions/* /opt/sonar/extensions/
  rm -rf /opt/sonar/data/extensions
fi

if [[ ${FROM_VERSION} == *"5.6.6"* ]]; then
  echo "You have upgraded from SonarQube 5.6.6. This may lead to unexpected behavior!"
  echo "See https://docs.sonarqube.org/latest/setup/upgrading/"
fi

# At LTS upgrade from 5.6.7 to 6.7.6, the data volume has been switched from /var/lib/sonar/ to ${SONARQUBE_HOME}/data/
# Move data from old 5.6.7 data volume to new 6.7.x data volume
if [[ ${FROM_VERSION} == *"5.6.7"* ]] && [[ ${TO_VERSION} == *"6.7."* ]]; then
  echo "Moving old SonarQube 5.6.7 data to current data folder..."
  mv "${SONARQUBE_HOME}"/data/data/* "${SONARQUBE_HOME}"/data
  echo "Removing old SonarQube 5.6.7 files and folders..."
  rm -rf "${SONARQUBE_HOME}"/data/conf "${SONARQUBE_HOME}"/data/extensions "${SONARQUBE_HOME}"/data/logs "${SONARQUBE_HOME}"/data/temp "${SONARQUBE_HOME}"/data/data
fi

echo "Waiting for SonarQube status endpoint to be available (max. ${WAIT_TIMEOUT} seconds)..."
wait_for_sonar_status_endpoint ${WAIT_TIMEOUT}

echo "Checking if db migration is needed..."
DB_MIGRATION_STATUS=$(curl "${CURL_LOG_LEVEL}" --fail -X GET http://localhost:9000/sonar/api/system/db_migration_status | jq -r '.state')
if [[ "${DB_MIGRATION_STATUS}" = "MIGRATION_REQUIRED" ]]; then
  echo "Database migration is required. Migrating database now..."
  curl "${CURL_LOG_LEVEL}" --fail -X POST http://localhost:9000/sonar/api/system/migrate_db
  printf "\\nWaiting for db migration to succeed (max. %s seconds)...\\n" ${WAIT_TIMEOUT}
  for i in $(seq 1 "${WAIT_TIMEOUT}"); do
    DB_MIGRATION_STATE=$(curl "${CURL_LOG_LEVEL}" --fail -X GET http://localhost:9000/sonar/api/system/db_migration_status | jq -r '.state')
    if [[ "${DB_MIGRATION_STATE}" = "MIGRATION_SUCCEEDED" ]]; then
      echo "Database migration has been successful: ${DB_MIGRATION_STATE}"
      break
    fi
    if [[ "$i" -eq ${WAIT_TIMEOUT} ]] ; then
      echo "Database migration did not succeed within ${WAIT_TIMEOUT} seconds; status is ${DB_MIGRATION_STATE}."
      exit 1
    fi
    # waiting for db migration
    sleep 1
  done
else
  echo "No db migration is needed"
fi

if [[ ${FROM_VERSION} == *"5.6.7"* ]] && [[ ${TO_VERSION} == *"6.7."* ]]; then
  # reinstall missing plugins if there are any
  if doguctl config install_plugins > /dev/null; then

    echo "Waiting for SonarQube to get up (max ${WAIT_TIMEOUT} seconds)..."
    wait_for_sonar_to_get_up ${WAIT_TIMEOUT}

    echo "Waiting for SonarQube to get healthy (max. ${WAIT_TIMEOUT} seconds)..."
    # default admin credentials (admin, admin) are used
    wait_for_sonar_to_get_healthy ${WAIT_TIMEOUT} admin admin ${CURL_LOG_LEVEL}

    reinstall_plugins

    # clear install_plugins key
    doguctl config install_plugins "" >> /dev/null
  fi

  # Do everything that needs to be done to get into a state that is equal to a successful first start
  create_dogu_admin_and_deactivate_default_admin ${CURL_LOG_LEVEL}
  set_successful_first_start_flag
fi

if [[ ${FROM_VERSION} == *"6.7.6-1"* ]] || [[ ${FROM_VERSION} == *"5.6"* ]]; then
  # grant further permissions to CES admin group via API
  # TODO: Extract grant_permission_to_group_via_rest_api function from startup.sh into util.sh and use it instead
  CES_ADMIN_GROUP=$(doguctl config --global admin_group)
  DOGU_ADMIN_PASSWORD=$(doguctl config -e dogu_admin_password)
  echo "Waiting for SonarQube to get up (max. ${WAIT_TIMEOUT} seconds)..."
  wait_for_sonar_to_get_up "${WAIT_TIMEOUT}"
  echo "Waiting for SonarQube to get healthy (max. ${WAIT_TIMEOUT} seconds)..."
  wait_for_sonar_to_get_healthy ${WAIT_TIMEOUT} "${DOGU_ADMIN}" "${DOGU_ADMIN_PASSWORD}" ${CURL_LOG_LEVEL}
  # grant profileadmin permission
  curl ${CURL_LOG_LEVEL} --fail -u "${DOGU_ADMIN}":"${DOGU_ADMIN_PASSWORD}" -X POST "http://localhost:9000/sonar/api/permissions/add_group?permission=profileadmin&groupName=${CES_ADMIN_GROUP}"
  # grant gateadmin permission
  curl ${CURL_LOG_LEVEL} --fail -u "${DOGU_ADMIN}":"${DOGU_ADMIN_PASSWORD}" -X POST "http://localhost:9000/sonar/api/permissions/add_group?permission=gateadmin&groupName=${CES_ADMIN_GROUP}"
  # grant provisioning permission
  curl ${CURL_LOG_LEVEL} --fail -u "${DOGU_ADMIN}":"${DOGU_ADMIN_PASSWORD}" -X POST "http://localhost:9000/sonar/api/permissions/add_group?permission=provisioning&groupName=${CES_ADMIN_GROUP}"
fi

doguctl config post_upgrade_running false