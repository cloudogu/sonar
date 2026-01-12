#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

sourcingExitCode=0
# shellcheck disable=SC1090,SC1091
source "${STARTUP_DIR}"util.sh || sourcingExitCode=$?
if [[ ${sourcingExitCode} -ne 0 ]]; then
  echo "ERROR: An error occurred while sourcing ${STARTUP_DIR}util.sh."
fi

function run_pre_upgrade() {
  FROM_VERSION="${1}"
  TO_VERSION="${2}"
  FROM_MAJOR_VERSION=$(echo "${FROM_VERSION}" | cut -d '.' -f1)

  echo "Running pre-upgrade script..."
  echo "  FROM_VERSION: ${FROM_VERSION}"
  echo "  TO_VERSION: ${TO_VERSION}"

  if [[ ${FROM_MAJOR_VERSION} -lt 8 ]]; then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. Upgrade to version 8.9.8-3 before."
    echo "It is not safe to migrate between several major versions in one step."
    exit 1
  fi

  if [[ ${FROM_VERSION} == "8"* ]] && [[ ${TO_VERSION} == "9.9"* ]]; then
    collectInstalledPlugins
  fi

  if [[ ${FROM_VERSION} == "9.9"* ]] && [[ ${TO_VERSION} == "25."* ]]; then
    collectInstalledPlugins
  fi

  # set this so the startup.sh waits for the post_upgrade to finish
  doguctl config post_upgrade_running true
}

function collectInstalledPlugins() {
  create_temporary_admin

  echo "Getting all installed plugins..."
  INSTALLED_PLUGINS=$(curl --silent --fail -u "${TEMPORARY_ADMIN_USER}":"${TEMPORARY_ADMIN_PASSWORD}" -X GET localhost:9000/sonar/api/plugins/installed | jq '.plugins' | jq '.[]' | jq -r '.key')
  echo "The following plugins are installed. They will be re-installed after dogu upgrade:"
  echo "${INSTALLED_PLUGINS}"
  SAVED_PLUGIN_NAMES=""
  while read -r PLUGIN; do
    SAVED_PLUGIN_NAMES+=${PLUGIN},
  done <<<"${INSTALLED_PLUGINS}"


  if [[ -n "${SAVED_PLUGIN_NAMES:-}" ]]; then
    echo "Saving plugin names to registry..."
    doguctl config install_plugins "${SAVED_PLUGIN_NAMES}"
  fi

  mv /opt/sonar/extensions/plugins "/opt/sonar/extensions/plugins-${FROM_VERSION}"

  remove_all_temporary_admins_users_and_groups
}

# make the script only run when executed, not when sourced from bats tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_pre_upgrade "$@"
fi
