#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

FROM_VERSION="${1}"
TO_VERSION="${2}"

if [[ ${FROM_VERSION} == "5"* ]]; then
  echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. Please upgrade to version 6.7.7-2 before."
  exit 1
fi

if [[ ${FROM_VERSION} == "6.7."* ]] && [[ ${TO_VERSION} == "7.9."* ]]; then
  echo "You are upgrading your SonarQube instance from 6.7.x LTS to 7.9.x LTS. Please consider backing up your SonarQube database. Upgrade problems are rare, but you'll want the backup if anything does happen."
  echo "The currently installed plugins will be re-installed in SonarQube 7.9, potentially in a newer version than they are installed now. As not all plugins which have been available in SonarQube 6.7 are also available in SonarQube 7.9, you should check the log output for plugins which could not be re-installed. The plugin binaries from your current 6.7.x SonarQube instance will not be removed, but be moved to their own folder in the extensions volume."
fi

if [[ $(cat /proc/sys/vm/max_map_count) -lt 262144 ]]; then
  echo "Your max virtual memory areas vm.max_map_count is too low, increase to at least [262144]. You can do so by upgrading the ces-commons package to at least version 0.2.0."
  exit 1
fi
