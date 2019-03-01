#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

DATABASE_IP=postgresql
DATABASE_USER=$(doguctl config -e sa-postgresql/username)
DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
DATABASE_DB=$(doguctl config -e sa-postgresql/database)

function execute_sql_statement_on_database(){
  PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "${1}"
  return $?
}

function wait_for_sonar_status_endpoint() {
  WAIT_TIMEOUT=${1}
  if ! doguctl wait-for-http --timeout "${WAIT_TIMEOUT}" --method GET http://localhost:9000/sonar/api/system/status; then
    echo "timeout reached while waiting for SonarQube status endpoint to be available"
    exit 1
  else
    echo "SonarQube status endpoint is available"
  fi
}

function wait_for_sonar_to_get_up() {
  WAIT_TIMEOUT=${1}
  for i in $(seq 1 "${WAIT_TIMEOUT}"); do
    SONAR_STATUS=$(curl -s http://localhost:9000/sonar/api/system/status | jq -r '.status')
    if [[ "${SONAR_STATUS}" = "UP" ]]; then
      echo "SonarQube status is ${SONAR_STATUS}"
      break
    fi
    if [[ "$i" -eq ${WAIT_TIMEOUT} ]] ; then
      echo "SonarQube did not get up within ${WAIT_TIMEOUT} seconds; status is ${SONAR_STATUS}. Dogu exits now"
      exit 1
    fi
    # waiting for SonarQube to get up
    sleep 1
  done
}