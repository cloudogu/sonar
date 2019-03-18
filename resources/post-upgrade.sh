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

echo "Running post-upgrade script..."

doguctl config post_upgrade_running true

if [[ ${FROM_VERSION} == *"5.6.6"* ]]; then
  echo "You have upgraded from SonarQube 5.6.6. This may lead to unexpected behavior!"
  echo "See https://docs.sonarqube.org/latest/setup/upgrading/"
fi

# At LTS upgrade from 5.6.7 to 6.7.6, the data volume has been switched from /var/lib/sonar/ to ${SONARQUBE_HOME}/data/
# Move data from old 5.6.7 data volume to new 6.7.x data volume
if [[ ${FROM_VERSION} == *"5.6.7"* ]] && [[ ${TO_VERSION} == *"6.7."* ]]; then
  echo "Moving old SonarQube 5.6.7 data to current data folder"
  mv "${SONARQUBE_HOME}"/data/data/* "${SONARQUBE_HOME}"/data
  echo "Removing old SonarQube 5.6.7 files and folders"
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
  # install missing plugins if there are any
  if doguctl config install_plugins > /dev/null; then

    echo "Waiting for SonarQube to get up (max ${WAIT_TIMEOUT} seconds)..."
    wait_for_sonar_to_get_up ${WAIT_TIMEOUT}

    echo "Waiting for SonarQube to get healthy (max. ${WAIT_TIMEOUT} seconds)..."
    # default admin credentials (admin, admin) are used
    wait_for_sonar_to_get_healthy ${WAIT_TIMEOUT} admin admin ${CURL_LOG_LEVEL}

    while IFS=',' read -ra ADDR; do
      for PLUGIN in "${ADDR[@]}"; do
        echo "Installing plugin ${PLUGIN}..."
        curl "${CURL_LOG_LEVEL}" --fail -u admin:admin -X POST http://localhost:9000/sonar/api/plugins/install?key="${PLUGIN}"
        echo "Plugin ${PLUGIN} installed."
      done
    done <<< "$(doguctl config install_plugins)"

    # clear install_plugins key
    doguctl config install_plugins ""
  fi

  # Do everything that needs to be done to get into a state that is equal to a successful first start
  create_dogu_admin_and_deactivate_default_admin ${CURL_LOG_LEVEL}
  set_successful_first_start_flag
fi

doguctl config post_upgrade_running false