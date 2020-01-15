#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# import util functions:
# execute_sql_statement_on_database()
# add_temporary_admin_user()
# getSHA1PW()
# remove_temporary_admin_user functions()
# wait_for_sonar_status_endpoint()
# wait_for_sonar_to_get_up()
# wait_for_sonar_to_get_healthy()
# create_dogu_admin_and_deactivate_default_admin()
# set_successful_first_start_flag()
# shellcheck disable=SC1091
source util.sh

FROM_VERSION="${1}"
TO_VERSION="${2}"
WAIT_TIMEOUT=600
CURL_LOG_LEVEL="--silent"

echo "Running post-upgrade script..."

# Migrate saved extensions folder to its own volume
if [[ ${FROM_VERSION} == "6.7.6-1" ]]; then
  mkdir -p /opt/sonar/extensions
  cp -R /opt/sonar/data/extensions/* /opt/sonar/extensions/
  rm -rf /opt/sonar/data/extensions
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

if [[ ${FROM_VERSION} == "6"* ]] && [[ ${TO_VERSION} == "7.9"* ]]; then
  TEMPORARY_ADMIN_USER=$(doguctl random)
  PW=$(doguctl random)
  SALT=$(doguctl random)
  HASH=$(getSHA1PW "${PW}" "${SALT}")
  add_temporary_admin_user "${TEMPORARY_ADMIN_USER}" "${HASH}" "${SALT}"
  # reinstall missing plugins if there are any
  if doguctl config install_plugins > /dev/null; then

    echo "Waiting for SonarQube to get up (max ${WAIT_TIMEOUT} seconds)..."
    wait_for_sonar_to_get_up ${WAIT_TIMEOUT}

    echo "Waiting for SonarQube to get healthy (max. ${WAIT_TIMEOUT} seconds)..."
    # default admin credentials (admin, admin) are used
    wait_for_sonar_to_get_healthy ${WAIT_TIMEOUT} "${TEMPORARY_ADMIN_USER}" "${PW}" ${CURL_LOG_LEVEL}

    reinstall_plugins "$(doguctl config install_plugins)" "${TEMPORARY_ADMIN_USER}" "${PW}"

    doguctl config --remove install_plugins
  fi

  remove_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
fi

if [[ ${FROM_VERSION} == "6.7.6-1" ]]; then
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
