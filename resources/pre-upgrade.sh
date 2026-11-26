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
  FROM_MINOR_VERSION=$(echo "${FROM_VERSION}" | cut -d '.' -f2)
  TO_MAJOR_VERSION=$(echo "${TO_VERSION}" | cut -d '.' -f1)

  echo "Running pre-upgrade script..."
  echo "  FROM_VERSION: ${FROM_VERSION}"
  echo "  TO_VERSION: ${TO_VERSION}"

  if [[ ${FROM_MAJOR_VERSION} -lt 8 ]]; then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. Upgrade to version 8.9.8-3 before."
    echo "It is not safe to migrate between several major versions in one step."
    exit 1
  fi

  # SonarQube 26.x refuses to migrate databases of versions older than 25.12
  if [[ ${TO_MAJOR_VERSION} -ge 26 ]] && { [[ ${FROM_MAJOR_VERSION} -lt 25 ]] || { [[ ${FROM_MAJOR_VERSION} -eq 25 ]] && [[ ${FROM_MINOR_VERSION} -lt 12 ]]; }; }; then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. Upgrade to version 25.12.0 before."
    echo "SonarQube 26.x only supports upgrades from SonarQube 25.12 or newer."
    exit 1
  fi

  if [[ ${FROM_VERSION} == "8"* ]] && [[ ${TO_VERSION} == "9.9"* ]]; then
    collectInstalledPlugins
  fi

  if [[ ${FROM_VERSION} == "9.9"* ]] && [[ ${TO_VERSION} == "25."* ]]; then
    collectInstalledPlugins
  fi

  if [[ ${FROM_MAJOR_VERSION} -eq 25 ]] && [[ ${TO_MAJOR_VERSION} -eq 26 ]]; then
    collectInstalledPlugins
  fi

  # set this so the startup.sh waits for the post_upgrade to finish
  doguctl config post_upgrade_running true
}

function collectInstalledPlugins() {
  # This script runs in the old container and sources its util.sh. Newer versions (e.g. 25.x) only initialize the
  # database variables via 'setDbVars', older versions (8.x, 9.9) do not provide this function.
  if declare -F setDbVars >/dev/null; then
    setDbVars
  fi

  if ! waitForSonarToBeReady "$(doguctl config --default "600" "health_timeout_seconds")"; then
    echo "Could not collect the installed plugins because SonarQube is not ready."
    exit 1
  fi

  TEMPORARY_ADMIN_GROUP=$(doguctl random)
  TEMPORARY_ADMIN_USER=$(doguctl random)
  TEMPORARY_ADMIN_PASSWORD=$(doguctl random)

  echo "Creating temporary user \"${TEMPORARY_ADMIN_USER}\"..."
  add_temporary_admin_group "${TEMPORARY_ADMIN_GROUP}"
  add_user "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_PASSWORD}"
  assign_group "${TEMPORARY_ADMIN_USER}" "${TEMPORARY_ADMIN_GROUP}"

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

  echo "Remove temporary admin user"
  remove_user "${TEMPORARY_ADMIN_USER}"
  remove_group "${TEMPORARY_ADMIN_GROUP}"

  mv /opt/sonar/extensions/plugins "/opt/sonar/extensions/plugins-${FROM_VERSION}"
}

# Waits until the dogu has finished its startup and SonarQube is up. The dogu reports itself as healthy while the
# startup script still restarts SonarQube, so the SonarQube status alone is not sufficient.
# This script runs in the old container, so only doguctl and curl are used and no functions from its util.sh.
function waitForSonarToBeReady() {
  local timeout="${1}" waited=0 state status
  echo "Waiting for SonarQube to be ready (max. ${timeout} seconds)..."
  while true; do
    state="$(doguctl state 2>/dev/null || true)"
    status="$(curl --silent --max-time 10 http://localhost:9000/sonar/api/system/status 2>/dev/null || true)"
    if [[ "${state}" == "ready" ]] && [[ "${status}" == *'"status":"UP"'* ]]; then
      echo "SonarQube is ready"
      return 0
    fi
    if [[ ${waited} -ge ${timeout} ]]; then
      echo "SonarQube did not get ready within ${timeout} seconds (dogu state: '${state}', SonarQube status: '${status}')."
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
}

# make the script only run when executed, not when sourced from bats tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_pre_upgrade "$@"
fi
