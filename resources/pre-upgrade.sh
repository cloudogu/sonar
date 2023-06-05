#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# import util functions:
# remove_temporary_admin_user()
# remove_temporary_admin_group()
# add_temporary_admin_group()
# create_temporary_admin_user_with_temporary_admin_group()
# shellcheck disable=SC1091
source "${STARTUP_DIR}/util.sh"

function run_pre_upgrade() {
  FROM_VERSION="${1}"
  TO_VERSION="${2}"
  FROM_MAJOR_VERSION=$(echo "${FROM_VERSION}" | cut -d '.' -f1)

  DATABASE_IP=postgresql
  DATABASE_USER=$(doguctl config -e sa-postgresql/username)
  DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
  DATABASE_DB=$(doguctl config -e sa-postgresql/database)

  echo "Running pre-upgrade script..."
  echo "  FROM_VERSION: ${FROM_VERSION}"
  echo "  TO_VERSION: ${TO_VERSION}"

  if [[ ${FROM_MAJOR_VERSION} -lt 8 ]]; then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. Upgrade to version 8.9.8-3 before."
    echo "It is not safe to migrate between several major versions in one step."
    exit 1
  fi

  if [[ ${FROM_VERSION} == "8"* ]] && [[ ${TO_VERSION} == "9.9"* ]]; then
      TEMPORARY_ADMIN_GROUP=$(doguctl random)
      TEMPORARY_ADMIN_USER=$(doguctl random)
      TEMPORARY_ADMIN_PASSWORD=$(doguctl random)

      # remove user in case it already exists
      remove_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
      remove_temporary_admin_group "${TEMPORARY_ADMIN_GROUP}"

      echo "Creating temporary user \"${TEMPORARY_ADMIN_USER}\"..."
      add_temporary_admin_group "${TEMPORARY_ADMIN_GROUP}"
      create_temporary_admin_user_with_temporary_admin_group "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}" "${TEMPORARY_ADMIN_GROUP}" "--silent"

      collectInstalledPlugins "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"

      echo "Remove temporary admin user"
      remove_temporary_admin_user "${TEMPORARY_ADMIN_USER}"
      remove_temporary_admin_group "${TEMPORARY_ADMIN_GROUP}"

      mv /opt/sonar/extensions/plugins "/opt/sonar/extensions/plugins-${FROM_VERSION}"
    fi

  # set this so the startup.sh waits for the post_upgrade to finish
  doguctl config post_upgrade_running true
}

function sql() {
  PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "${1}"
  return $?
}

function collectInstalledPlugins() {
  TEMPORARY_ADMIN_USER=${1}
  PW=${2}
  echo "Getting all installed plugins..."
  INSTALLED_PLUGINS=$(curl --silent --fail -u "${TEMPORARY_ADMIN_USER}":"${PW}" -X GET localhost:9000/sonar/api/plugins/installed | jq '.plugins' | jq '.[]' | jq -r '.key')
  echo "The following plugins are installed. They will be re-installed after dogu upgrade:"
  echo "${INSTALLED_PLUGINS}"
  SAVED_PLUGIN_NAMES=""
  while read -r PLUGIN; do
    SAVED_PLUGIN_NAMES+=${PLUGIN},
  done <<<"${INSTALLED_PLUGINS}"

  echo "Saving plugin names to registry..."
  doguctl config install_plugins "${SAVED_PLUGIN_NAMES}"
}

# make the script only run when executed, not when sourced from bats tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_pre_upgrade "$@"
fi
