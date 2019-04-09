#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

FROM_VERSION="${1}"
TO_VERSION="${2}"
DATABASE_IP=postgresql
DATABASE_USER=$(doguctl config -e sa-postgresql/username)
DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
DATABASE_DB=$(doguctl config -e sa-postgresql/database)

function sql(){
  PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "${1}"
  return $?
}

function add_temporary_admin_user() {
  # temporarily create admin user and add to admin groups
  TEMPORARY_ADMIN_USER=${1}
  sql "INSERT INTO users (login, name, crypted_password, salt, active, external_identity, user_local)
  VALUES ('${TEMPORARY_ADMIN_USER}', 'Temporary Administrator', 'a373a0e667abb2604c1fd571eb4ad47fe8cc0878', '48bc4b0d93179b5103fd3885ea9119498e9d161b', true, '${TEMPORARY_ADMIN_USER}', true);"
  ADMIN_ID_PSQL_OUTPUT=$(PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "SELECT id FROM users WHERE login='${TEMPORARY_ADMIN_USER}';")
  ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | awk 'NR==3' | cut -d " " -f 2)
  if [[ -z ${ADMIN_ID} ]]; then
    # id has only one digit
    ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | awk 'NR==3' | cut -d " " -f 3)
  fi
  echo "Got temporary admin id: ${ADMIN_ID}"
  sql "INSERT INTO groups_users (user_id, group_id) VALUES (${ADMIN_ID}, 1);"
  sql "INSERT INTO groups_users (user_id, group_id) VALUES (${ADMIN_ID}, 2);"
}

function remove_temporary_admin_user() {
  TEMPORARY_ADMIN_USER=${1}
  sql "DELETE FROM users WHERE login='${TEMPORARY_ADMIN_USER}';"
}

echo "Running pre-upgrade script..."
if [[ ${FROM_VERSION} == *"5.6.7"* ]] && [[ ${TO_VERSION} == *"6.7."* ]]; then
  TEMPORARY_ADMIN_USER="admin"
  # remove user in case it already exists
  sql "DELETE FROM users WHERE login='${TEMPORARY_ADMIN_USER}';"
  echo "Creating temporary ${TEMPORARY_ADMIN_USER} user..."
  add_temporary_admin_user "${TEMPORARY_ADMIN_USER}"

  echo "Getting plugins which are not up-to-date..."
  AVAILABLE_PLUGIN_UPDATES=$(curl --silent --fail -u "${TEMPORARY_ADMIN_USER}":admin -X GET localhost:9000/sonar/api/plugins/updates | jq '.plugins' | jq '.[]' | jq -r '.key')
  echo "The following plugins are not up-to-date. They will be removed and re-installed after dogu upgrade:"
  echo "${AVAILABLE_PLUGIN_UPDATES}"
  SAVED_PLUGIN_NAMES=""
  # remove them
  while read -r PLUGIN; do
    echo "Removing plugin ${PLUGIN}..."
    curl --silent --fail -u "${TEMPORARY_ADMIN_USER}":admin -X POST "localhost:9000/sonar/api/plugins/uninstall?key=${PLUGIN}"
    SAVED_PLUGIN_NAMES+=${PLUGIN},
  done <<< "${AVAILABLE_PLUGIN_UPDATES}"

  echo "Saving plugin names to registry..."
  doguctl config install_plugins "${SAVED_PLUGIN_NAMES}"

  # Changing owner of data folder, because SonarQube 6.7 dogu user is 'sonar' and not root any more
  echo "Setting correct owner for data folder"
  chown -R sonar:sonar "/var/lib/sonar"

  # The temporary admin user is not removed; this will be done at the end of firstSonarStart() in the sonar 6.7.x dogu
fi

if [[ ${FROM_VERSION} == *"6.7.6-1"* ]]; then
  mkdir /opt/sonar/data/extensions
  cp -R /opt/sonar/extensions/* /opt/sonar/data/extensions/
fi




