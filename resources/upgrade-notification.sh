#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

CURRENT_MAX_MAP_COUNT=$(cat /proc/sys/vm/max_map_count)

function run_upgrade_notification() {
  FROM_VERSION="${1}"
  TO_VERSION="${2}"
  FROM_MAJOR_VERSION=$(echo "${FROM_VERSION}" | cut -d '.' -f1)

  if [[ ${FROM_VERSION} == "5"* ]] || [[ ${FROM_VERSION} == "6.7.6-1" ]]; then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. Please upgrade to version 6.7.7-2 before."
    exit 1
  fi

  if [[ ${FROM_VERSION} == "6.7."* ]] && [[ ${TO_VERSION} == "7.9."* ]]; then
    echo "You are upgrading your SonarQube instance from 6.7.x LTS to 7.9.x LTS. Please consider backing up your SonarQube database. Upgrade problems are rare, but you'll want the backup if anything does happen."
    echo "The currently installed plugins will be re-installed in SonarQube 7.9, potentially in a newer version than they are installed now. As not all plugins which have been available in SonarQube 6.7 are also available in SonarQube 7.9, you should check the log output for plugins which could not be re-installed. The plugin binaries from your current 6.7.x SonarQube instance will not be removed, but be moved to their own folder in the extensions volume."
  fi

  if [[ ${CURRENT_MAX_MAP_COUNT} -lt 262144 ]]; then
    echo "Your max virtual memory areas vm.max_map_count is too low, increase to at least [262144]. You can do so by upgrading the ces-commons package to at least version 0.2.0."
    exit 1
  fi

  if [[ ${FROM_MAJOR_VERSION} -lt 7 ]] && [[ ${TO_VERSION} == "8.9."* ]]; then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. It is not safe to migrate between"
    echo "several major versions in one step."
    echo "Please follow the upgrade path of one major version to the next one instead."
    exit 1
  fi

  if [[ ${FROM_VERSION} == "7.9."* ]] && [[ ${TO_VERSION} == "8.9."* ]]; then
    echo "You are upgrading your SonarQube instance from 7.9.x LTS to 8.9.x LTS. Please consider backing up your SonarQube database."
    echo "Upgrade problems are rare, but you may want backup in case anything goes wrong."
    echo "Some plugins will be uninstalled because SonarQube 8.9 includes the plugin functionality into its core."
    echo "Please check the SonarQube plugin compatibility in the release notes. Concerned plugins will move to"
    echo "$(extensions/deprecated-plugins/) in case you need them."
    echo "Please check the log output for plugins which could not be installed."
  fi

  return 0
}

# make the script only run when executed, not when sourced from bats tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_upgrade_notification "$@"
fi
