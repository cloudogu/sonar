#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

FROM_VERSION=
TO_VERSION=
FROM_MAJOR_VERSION=
TO_MAJOR_VERSION=

DATABASE_IP=postgresql
DATABASE_USER=
DATABASE_USER_PASSWORD=
DATABASE_DB=

function run_pre_upgrade() {
  FROM_VERSION="${1}"
  TO_VERSION="${2}"
  FROM_MAJOR_VERSION=$(echo "${FROM_VERSION}" | cut -d '.' -f1)
  TO_MAJOR_VERSION=$(echo "${TO_VERSION}" | cut -d '.' -f1)

  echo "FROM_VERSION=${FROM_VERSION} TO_VERSION=${TO_VERSION} FROM_MAJOR_VERSION=${FROM_MAJOR_VERSION} TO_MAJOR_VERSION=${TO_MAJOR_VERSION}"

  DATABASE_USER=$(doguctl config -e sa-postgresql/username)
  DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
  DATABASE_DB=$(doguctl config -e sa-postgresql/database)

  echo "Running pre-upgrade script..."

  if [[ ${FROM_VERSION} == "5"* ]]; then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. Upgrade to version 6.7.7-2 before."
    exit 1
  fi

  # Save extensions folder as it henceforth gets its own volume
  if [[ ${FROM_VERSION} == "6.7.6-1" ]]; then
    mkdir /opt/sonar/data/extensions
    cp -R /opt/sonar/extensions/* /opt/sonar/data/extensions/
  fi

  if [[ ${FROM_VERSION} == "6"* ]] && [[ ${TO_VERSION} == "7.9"* ]]; then
    TEMPORARY_ADMIN_USER=$(doguctl random)
    # remove user in case it already exists
    remove_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
    echo "Creating temporary user \"${TEMPORARY_ADMIN_USER}\"..."
    PW=$(doguctl random)
    SALT=$(doguctl random)
    HASH=$(getSHA1PW "${PW}" "${SALT}")
    add_temporary_admin_user_sonar6 "${TEMPORARY_ADMIN_USER}" "${HASH}" "${SALT}"

    echo "Getting all installed plugins..."
    INSTALLED_PLUGINS=$(curl --silent --fail -u "${TEMPORARY_ADMIN_USER}":"${PW}" -X GET localhost:9000/sonar/api/plugins/installed | jq '.plugins' | jq '.[]' | jq -r '.key')
    echo "The following plugins are installed. They will be re-installed after dogu upgrade:"
    echo "${INSTALLED_PLUGINS}"
    SAVED_PLUGIN_NAMES=""
    while read -r PLUGIN; do
      SAVED_PLUGIN_NAMES+=${PLUGIN},
    done <<< "${INSTALLED_PLUGINS}"

    echo "Remove temporary admin user"
    remove_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
    echo "Saving plugin names to registry..."
    doguctl config install_plugins "${SAVED_PLUGIN_NAMES}"

    mv /opt/sonar/extensions/plugins "/opt/sonar/extensions/plugins-${FROM_VERSION}"
  fi

  if [[ ${FROM_VERSION} == "6"* || "${FROM_VERSION}" =~ ^7.9.1-[1234]$ || ${FROM_VERSION} == "7.9.3-1" ]]; then
    echo "Removing deprecated sonarqubedoguadmin..."
    remove_temporary_admin_user "sonarqubedoguadmin"

    echo "Removing es6 cache..."
    rm -r /opt/sonar/data/es6
  fi

  if [[ "${TO_MAJOR_VERSION}" -ge 8 ]] && [[ "${FROM_MAJOR_VERSION}" -lt 8 ]]; then
      echo "Removing obsolete plugins that now come with SonarQube 8..."
      echo "Finished removing obsolete plugins."
  fi

  # set this so the startup.sh waits for the post_upgrade to finish
  doguctl config post_upgrade_running true
}

function sql(){
  PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "${1}"
  return $?
}

function add_temporary_admin_user_sonar6() {
  # temporarily create admin user and add to admin groups
  TEMPORARY_ADMIN_USER=${1}
  HASHED_PW=${2}
  SALT=${3}
  sql "INSERT INTO users (login, name, crypted_password, salt, active, external_identity, user_local, is_root, onboarded)
  VALUES ('${TEMPORARY_ADMIN_USER}', 'Temporary Administrator', '${HASHED_PW}', '${SALT}', true, '${TEMPORARY_ADMIN_USER}', true, true, true);"
  ADMIN_ID_PSQL_OUTPUT=$(PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "SELECT uuid FROM users WHERE login='${TEMPORARY_ADMIN_USER}';")
  ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | awk 'NR==3' | cut -d " " -f 2)
  if [[ -z ${ADMIN_ID} ]]; then
    # id has only one digit
    ADMIN_ID=$(echo "${ADMIN_ID_PSQL_OUTPUT}" | awk 'NR==3' | cut -d " " -f 3)
  fi
  sql "INSERT INTO groups_users (user_uuid, group_uuid) VALUES (${ADMIN_ID}, 1);"
  sql "INSERT INTO groups_users (user_uuid, group_uuid) VALUES (${ADMIN_ID}, 2);"
}

function getSHA1PW() {
    PW="${1}"
    SALT="${2}"
    echo -n "--${SALT}--${PW}--" | sha1sum | awk '{print $1}'
}

function remove_temporary_admin_user() {
  TEMPORARY_ADMIN_USER=${1}
  sql "DELETE FROM users WHERE login='${TEMPORARY_ADMIN_USER}';"
}

# make the script only run when executed, not when sourced from bats tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_pre_upgrade "$@"
fi