#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

DATABASE_IP=postgresql
DATABASE_USER=$(doguctl config -e sa-postgresql/username)
DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
DATABASE_DB=$(doguctl config -e sa-postgresql/database)
DOGU_ADMIN="sonarqubedoguadmin"

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

function add_temporary_admin_user() {
  # temporarily create admin user and add to admin groups
  # the password is 'admin'
  TEMPORARY_ADMIN_USER=${1}
  execute_sql_statement_on_database "INSERT INTO users (login, name, crypted_password, salt, active, external_identity, user_local, is_root, onboarded)
  VALUES ('${TEMPORARY_ADMIN_USER}', 'Temporary Administrator', 'a373a0e667abb2604c1fd571eb4ad47fe8cc0878', '48bc4b0d93179b5103fd3885ea9119498e9d161b', true, '${TEMPORARY_ADMIN_USER}', true, true, true);"
  ADMIN_ID_PSQL_OUTPUT=$(PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "SELECT id FROM users WHERE login='${TEMPORARY_ADMIN_USER}';")
  ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | cut -d " " -f 3)
  execute_sql_statement_on_database "INSERT INTO groups_users (user_id, group_id) VALUES (${ADMIN_ID}, 1);"
  execute_sql_statement_on_database "INSERT INTO groups_users (user_id, group_id) VALUES (${ADMIN_ID}, 2);"
}

function remove_temporary_admin_user() {
  TEMPORARY_ADMIN_USER=${1}
  execute_sql_statement_on_database "DELETE FROM users WHERE login='${TEMPORARY_ADMIN_USER}';"
}

function wait_for_sonar_to_get_healthy() {
  WAIT_TIMEOUT=${1}
  USER=$2
  PASSWORD=$3
  LOG_LEVEL=$4
  for i in $(seq 1 "${WAIT_TIMEOUT}"); do
    SONAR_HEALTH_STATUS=$(curl "${LOG_LEVEL}" --fail -u "${USER}":"${PASSWORD}" http://localhost:9000/sonar/api/system/health | jq -r '.health')
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

function create_dogu_admin_user_and_save_password() {
  AUTH_USER=$1
  AUTH_PASSWORD=$2
  LOG_LEVEL=$3
  echo "Creating ${DOGU_ADMIN} and granting admin permissions..."
  DOGU_ADMIN_PASSWORD=$(doguctl random)
  create_user_via_rest_api "${DOGU_ADMIN}" "SonarQubeDoguAdmin" "${DOGU_ADMIN_PASSWORD}" "${AUTH_USER}" "${AUTH_PASSWORD}" "${LOG_LEVEL}"
  add_user_to_group_via_rest_api "${DOGU_ADMIN}" "sonar-administrators" "${AUTH_USER}" "${AUTH_PASSWORD}" "${LOG_LEVEL}"
  # saving dogu admin password in registry
  doguctl config -e dogu_admin_password "${DOGU_ADMIN_PASSWORD}"
  printf "\\n"
}

function create_user_via_rest_api() {
  LOGIN=$1
  NAME=$2
  PASSWORD=$3
  AUTH_USER=$4
  AUTH_PASSWORD=$5
  LOG_LEVEL=$6
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/create?login=${LOGIN}&name=${NAME}&password=${PASSWORD}&local=true"
}


function add_user_to_group_via_rest_api() {
  USERNAME=$1
  GROUPNAME=$2
  AUTH_USER=$3
  AUTH_PASSWORD=$4
  LOG_LEVEL=$5
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/user_groups/add_user?name=${GROUPNAME}&login=${USERNAME}"
}

function deactivate_default_admin_user() {
  AUTH_USER=$1
  AUTH_PASSWORD=$2
  LOG_LEVEL=$3
  RANDOM_PASSWORD=$(doguctl random)
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/change_password?login=admin&password=${RANDOM_PASSWORD}&previousPassword=admin"
  curl "${LOG_LEVEL}" --fail -u "${AUTH_USER}":"${AUTH_PASSWORD}" -X POST "http://localhost:9000/sonar/api/users/deactivate?login=admin"
}

function run_first_start_and_post_upgrade_tasks() {
  LOG_LEVEL=$1
  # default admin credentials (admin, admin) are used
  create_dogu_admin_user_and_save_password admin admin "${LOG_LEVEL}"

  echo "Deactivating default admin account..."
  DOGU_ADMIN_PASSWORD=$(doguctl config -e dogu_admin_password)
  deactivate_default_admin_user ${DOGU_ADMIN} "${DOGU_ADMIN_PASSWORD}" "${LOG_LEVEL}"
  printf "\\n"

  echo "Waiting for configuration changes to be internally executed..."
  sleep 3

  echo "Setting successfulFirstStart registry key..."
  doguctl config successfulFirstStart true
}