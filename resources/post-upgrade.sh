#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

FROM_VERSION="${1}"
TO_VERSION="${2}"

if [[ ${FROM_VERSION} == *"5.6.6"* ]]; then
  echo "You have upgraded from SonarQube 5.6.6. This may lead to unexpected behavior!"
  echo "See https://docs.sonarqube.org/latest/setup/upgrading/"
fi

WAIT_TIMEOUT=300
echo "waiting until sonar passes all health checks (max. ${WAIT_TIMEOUT} seconds)..."
if ! doguctl healthy --wait --timeout ${WAIT_TIMEOUT} sonar; then
  echo "timeout of ${WAIT_TIMEOUT} seconds reached by waiting of sonar to get healthy"
  exit 1
else
  echo "sonar is healthy"
fi

echo "Checking if db migration is needed..."
DB_MIGRATION_STATUS=$(curl --silent --insecure -X GET https://$(doguctl config --global fqdn)/sonar/api/system/db_migration_status | jq -r '.state')
if [[ "${DB_MIGRATION_STATUS}" = "MIGRATION_REQUIRED" ]]; then
  echo "Database migration is required. Migrating database now..."
  curl --silent --insecure -X POST https://$(doguctl config --global fqdn)/sonar/api/system/migrate_db
  printf "\nwaiting for db migration to succeed (max. ${WAIT_TIMEOUT} seconds)...\n"
  for i in $(seq 1 "${WAIT_TIMEOUT}"); do
    DB_MIGRATION_STATE=$(curl --silent --insecure -X GET https://$(doguctl config --global fqdn)/sonar/api/system/db_migration_status | jq -r '.state')
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
fi