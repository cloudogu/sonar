#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

FROM_VERSION="${1}"
TO_VERSION="${2}"

if [[ ${FROM_VERSION} == *"5.6.6"* ]] && [[ ${TO_VERSION} == *"6.7."* ]]; then
  echo "You are upgrading from SonarQube 5.6.6 to a 6.7 LTS version. This may lead to unexpected behavior!"
  echo "Please upgrade to 5.6.7 LTS before upgrading to 6.7 LTS!"
  echo "See https://docs.sonarqube.org/latest/setup/upgrading/"
  exit 1
elif [[ ${FROM_VERSION} == *"5.6.7"* ]] && [[ ${TO_VERSION} == *"6.7."* ]]; then
  echo "You are upgrading your SonarQube instance from 5.6.7 to 6.7.x LTS. Please consider backing up your SonarQube database. Upgrade problems are rare, but you'll want the backup if anything does happen."
  echo "The currently installed plugins will be re-installed in SonarQube 6.7, potentially in a newer version than they are installed now. As not all plugins which have been available in SonarQube 5.6 are also available in SonarQube 6.7, you should check the log output for plugins which could not be re-installed."
fi