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

if [[ ${FROM_VERSION} == *"5.6.7"* ]] && [[ ${TO_VERSION} == *"6.7."* ]]; then
  # temporarily create admin user and add to admin groups
  TEMPORARY_ADMIN_USER=$(doguctl random)
  sql "INSERT INTO users (login, name, crypted_password, salt, active, external_identity, user_local) VALUES ('${TEMPORARY_ADMIN_USER}', 'Temporary Administrator', 'a373a0e667abb2604c1fd571eb4ad47fe8cc0878', '48bc4b0d93179b5103fd3885ea9119498e9d161b', true, '${TEMPORARY_ADMIN_USER}', true);"
  ADMIN_ID_PSQL_OUTPUT=$(PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "SELECT id FROM users WHERE login='${TEMPORARY_ADMIN_USER}';")
  ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | cut -d " " -f 3)
  sql "INSERT INTO groups_users (user_id, group_id) VALUES (${ADMIN_ID}, 1);"
  sql "INSERT INTO groups_users (user_id, group_id) VALUES (${ADMIN_ID}, 2);"

  # get plugins which are not up to date
  AVAILABLE_PLUGIN_UPDATES=$(curl --silent -u "${TEMPORARY_ADMIN_USER}":admin -X GET localhost:9000/sonar/api/plugins/updates | jq '.plugins' | jq '.[]' | jq -r '.key')
  # remove them
  while read -r PLUGIN; do
    echo "Removing plugin ${PLUGIN}..."
    curl --silent -u "${TEMPORARY_ADMIN_USER}":admin -X POST "localhost:9000/sonar/api/plugins/uninstall?key=${PLUGIN}"
  done <<< "${AVAILABLE_PLUGIN_UPDATES}"

  # remove temporary admin user
  sql "DELETE FROM users WHERE login='${TEMPORARY_ADMIN_USER}';"
fi




