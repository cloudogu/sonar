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

FROM_VERSION="${1}"
TO_VERSION="${2}"
DATABASE_IP=postgresql
DATABASE_USER=$(doguctl config -e sa-postgresql/username)
DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
DATABASE_DB=$(doguctl config -e sa-postgresql/database)
WAIT_TIMEOUT=120

if [[ ${FROM_VERSION} == *"5.6.6"* ]]; then
  echo "You have upgraded from SonarQube 5.6.6. This may lead to unexpected behavior!"
  echo "See https://docs.sonarqube.org/latest/setup/upgrading/"
fi

# At LTS upgrade from 5.6.7 to 6.7.6, the data volume has been switched from /var/lib/sonar/ to ${SONARQUBE_HOME}/data/
# Move data from old 5.6.7 data volume to new 6.7.x data volume
if [[ ${FROM_VERSION} == *"5.6.7"* ]] && [[ ${TO_VERSION} == *"6.7."* ]]; then
  echo "Moving old SonarQube 5.6.7 data to current data folder"
  mv ${SONARQUBE_HOME}/data/data/* ${SONARQUBE_HOME}/data
  echo "Removing old SonarQube 5.6.7 files and folders"
  rm -rf ${SONARQUBE_HOME}/data/conf ${SONARQUBE_HOME}/data/extensions ${SONARQUBE_HOME}/data/logs ${SONARQUBE_HOME}/data/temp ${SONARQUBE_HOME}/data/data
fi

echo "Waiting for SonarQube status endpoint to be available (max. ${WAIT_TIMEOUT} seconds)..."
wait_for_sonar_status_endpoint ${WAIT_TIMEOUT}

echo "Checking if db migration is needed..."
DB_MIGRATION_STATUS=$(curl --silent --insecure -X GET https://"$(doguctl config --global fqdn)"/sonar/api/system/db_migration_status | jq -r '.state')
if [[ "${DB_MIGRATION_STATUS}" = "MIGRATION_REQUIRED" ]]; then
  echo "Database migration is required. Migrating database now..."
  curl --silent --insecure -X POST https://"$(doguctl config --global fqdn)"/sonar/api/system/migrate_db
  printf "\\nwaiting for db migration to succeed (max. %s seconds)...\\n" ${WAIT_TIMEOUT}
  for i in $(seq 1 "${WAIT_TIMEOUT}"); do
    DB_MIGRATION_STATE=$(curl --silent --insecure -X GET https://"$(doguctl config --global fqdn)"/sonar/api/system/db_migration_status | jq -r '.state')
    if [[ "${DB_MIGRATION_STATE}" = "MIGRATION_SUCCEEDED" ]]; then
      echo "db migration has been successful: ${DB_MIGRATION_STATE}"
      break
    fi
    if [[ "$i" -eq ${WAIT_TIMEOUT} ]] ; then
      echo "db migration did not succeed within ${WAIT_TIMEOUT} seconds; status is ${DB_MIGRATION_STATE}."
      exit 1
    fi
    # waiting for db migration
    sleep 1
  done
else
  echo "No db migration is needed"
fi

# install missing plugins if there are any
if doguctl config install_plugins > /dev/null; then
  # temporarily create admin user
  TEMPORARY_ADMIN_USER=$(doguctl random)
  add_temporary_admin_user "${TEMPORARY_ADMIN_USER}"

  echo "Waiting for SonarQube to get up (max ${WAIT_TIMEOUT} seconds)..."
  wait_for_sonar_to_get_up ${WAIT_TIMEOUT}

  while IFS=',' read -ra ADDR; do
    for PLUGIN in "${ADDR[@]}"; do
      printf "\\nInstalling plugin %s...\\n" "${PLUGIN}"
      curl --silent -u "${TEMPORARY_ADMIN_USER}":admin -X POST localhost:9000/sonar/api/plugins/install?key="${PLUGIN}"
    done
  done <<< "$(doguctl config install_plugins)"

  # remove temporary admin user
  remove_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
fi