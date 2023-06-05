#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

CURRENT_MAX_MAP_COUNT=$(cat /proc/sys/vm/max_map_count)

function run_upgrade_notification() {
  FROM_VERSION="${1}"
  TO_VERSION="${2}"
  FROM_MAJOR_VERSION=$(echo "${FROM_VERSION}" | cut -d '.' -f1)

  if [[ ${CURRENT_MAX_MAP_COUNT} -lt 262144 ]]; then
    echo "Your max virtual memory areas vm.max_map_count is too low, increase to at least [262144]. You can do so by upgrading the ces-commons package to at least version 0.2.0."
    exit 1
  fi

  if [[ ${FROM_MAJOR_VERSION} -lt 8 ]]; then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. It is not safe to migrate between"
    echo "several major versions in one step."
    echo "Please follow the upgrade path of one major version to the next one instead."
    exit 1
  fi

  return 0
}

# make the script only run when executed, not when sourced from bats tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_upgrade_notification "$@"
fi
