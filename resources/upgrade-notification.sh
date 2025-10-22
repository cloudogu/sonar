#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

CURRENT_MAX_MAP_COUNT=$(cat /proc/sys/vm/max_map_count)


function run_upgrade_notification() {
  FROM_VERSION="${1}"
  TO_VERSION="${2}"
  FROM_MAJOR_VERSION=$(echo "${FROM_VERSION}" | cut -d '.' -f1)
  TO_MAJOR_VERSION=$(echo "${TO_VERSION}" | cut -d '.' -f1)

  if [[ ${CURRENT_MAX_MAP_COUNT} -lt 262144 ]]; then
    echo "Your max virtual memory areas vm.max_map_count is too low, increase to at least [262144]. You can do so by upgrading the ces-commons package to at least version 0.2.0."
    exit 1
  fi

  if [[ ${FROM_MAJOR_VERSION} == ${TO_MAJOR_VERSION} ]]; then
    exit 0
  fi

  if [[ ${FROM_MAJOR_VERSION} -lt 8 ]]; then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. It is not safe to migrate between"
    echo "several major versions in one step."
    echo "Please follow the upgrade path of one major version to the next one instead."
    exit 1
  fi

  # Allow ONLY: (<8 -> 9) OR (9 -> 25)
  if ! (( (FROM_MAJOR_VERSION == 8 && TO_MAJOR_VERSION == 9) \
       || (FROM_MAJOR_VERSION == 9 && TO_MAJOR_VERSION == 25) )); then
    echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported."
    echo "Allowed upgrade paths are strictly:"
    echo "  - <8.x  -> 9.x"
    echo "  - 9.x   -> 25.x"
    echo "No other major transitions (including downgrades or same-version) are allowed."
    exit 1
  fi

  return 0
}

# make the script only run when executed, not when sourced from bats tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_upgrade_notification "$@"
fi

# If you’re on a version older than 9.9, upgrade to SonarQube Server 9.9 LTA before upgrading to the latest 2025.1 LTA.
