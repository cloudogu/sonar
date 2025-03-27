#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# import util functions:
# functions()
# wait_for_sonar_status_endpoint()
# wait_for_sonar_to_get_up()
# wait_for_sonar_to_get_healthy()
# remove_user()
# remove_group()
# add_temporary_admin_group()
# shellcheck disable=SC1091
source "${STARTUP_DIR}/util.sh"

function reinstall_plugins() {
  if doguctl config install_plugins >/dev/null; then
        TEMPORARY_ADMIN_GROUP=$(doguctl random)
        TEMPORARY_ADMIN_USER=$(doguctl random)
        TEMPORARY_ADMIN_PASSWORD=$(doguctl random)

        # remove user in case it already exists
        remove_user "${TEMPORARY_ADMIN_USER}"
        remove_group "${TEMPORARY_ADMIN_GROUP}"

        echo "Waiting for SonarQube to get up (max ${WAIT_TIMEOUT} seconds)..."
        wait_for_sonar_to_get_up ${WAIT_TIMEOUT}

        echo "Creating temporary user \"${TEMPORARY_ADMIN_USER}\"..."
        add_temporary_admin_group "${TEMPORARY_ADMIN_GROUP}"
        add_user "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
        assign_group "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_GROUP}"

        echo "Waiting for SonarQube to get healthy (max. ${WAIT_TIMEOUT} seconds)..."
        # default admin credentials (admin, admin) are used
        wait_for_sonar_to_get_healthy ${WAIT_TIMEOUT} "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}" ${CURL_LOG_LEVEL}

        while IFS=',' read -ra ADDR; do
            for PLUGIN in "${ADDR[@]}"; do
              echo "Checking if plugin ${PLUGIN} is installed already..."
              INSTALLED_PLUGINS=$(curl "${CURL_LOG_LEVEL}" --fail -u "${TEMPORARY_ADMIN_USER}":"${TEMPORARY_ADMIN_PASSWORD}" -X GET localhost:9000/sonar/api/plugins/installed | jq '.plugins' | jq '.[]' | jq -r '.key')
              if [[ ${INSTALLED_PLUGINS} == *"${PLUGIN}"* ]]; then
                echo "Plugin ${PLUGIN} is installed already"
              else
                echo "Plugin ${PLUGIN} is not installed, installing it..."
                install_plugin_via_api "${PLUGIN}" "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
              fi
            done
          done <<< "$(doguctl config install_plugins)"

          if [[ -n ${FAILED_PLUGIN_NAMES} ]]; then
            echo "### SUMMARY ###"
            echo "The following plugins could not be re-installed: ${FAILED_PLUGIN_NAMES}"
            echo ""
          fi

        echo "Remove temporary admin user"
        remove_user "${TEMPORARY_ADMIN_USER}"
        remove_group "${TEMPORARY_ADMIN_GROUP}"

        doguctl config --remove install_plugins
      fi
}

function run_post_upgrade() {
  # init variables from util.sh
  setDbVars

  FROM_VERSION="${1}"
  TO_VERSION="${2}"
  WAIT_TIMEOUT=600
  CURL_LOG_LEVEL="--silent"
  FAILED_PLUGIN_NAMES=""

  echo "Running post-upgrade script..."

  echo "Waiting for SonarQube status endpoint to be available (max. ${WAIT_TIMEOUT} seconds)..."
  wait_for_sonar_status_endpoint ${WAIT_TIMEOUT}

  echo "Checking if db migration is needed..."
  DB_MIGRATION_STATUS=$(curl "${CURL_LOG_LEVEL}" --fail -X GET http://localhost:9000/sonar/api/system/db_migration_status | jq -r '.state')
  if [[ "${DB_MIGRATION_STATUS}" == "MIGRATION_REQUIRED" ]]; then
    echo "Database migration is required. Migrating database now..."
    curl "${CURL_LOG_LEVEL}" --fail -X POST http://localhost:9000/sonar/api/system/migrate_db
    printf "\\nWaiting for db migration to succeed (max. %s seconds)...\\n" ${WAIT_TIMEOUT}
    for i in $(seq 1 "${WAIT_TIMEOUT}"); do
      DB_MIGRATION_STATE=$(curl "${CURL_LOG_LEVEL}" --fail -X GET http://localhost:9000/sonar/api/system/db_migration_status | jq -r '.state')
      if [[ "${DB_MIGRATION_STATE}" == "MIGRATION_SUCCEEDED" ]]; then
        echo "Database migration has been successful: ${DB_MIGRATION_STATE}"
        break
      fi
      if [[ "$i" -eq ${WAIT_TIMEOUT} ]]; then
        echo "Database migration did not succeed within ${WAIT_TIMEOUT} seconds; status is ${DB_MIGRATION_STATE}."
        exit 1
      fi
      # waiting for db migration
      sleep 1
    done
  else
    echo "No db migration is needed"
  fi

  if [[ ${FROM_VERSION} == "8"* ]] && [[ ${TO_VERSION} == "9.9"* ]]; then
    # reinstall missing plugins if there are any
    reinstall_plugins
  fi

  if [[ ${FROM_VERSION} == "9.9"* ]] && [[ ${TO_VERSION} == "25."* ]]; then
    # reinstall missing plugins if there are any
    reinstall_plugins
  fi

  doguctl config post_upgrade_running false
}

# make the script only run when executed, not when sourced from bats tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_post_upgrade "$@"
fi
