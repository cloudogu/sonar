#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

FROM_VERSION="${1}"
TO_VERSION="${2}"

if [[ ${FROM_VERSION} == *"5"* ]]; then
  echo "Upgrade from version ${FROM_VERSION} to ${TO_VERSION} is not supported. Upgrade to version 6.7.7-2 before."
  exit 1
fi

echo "Before upgrading check if your installed plugins are compatible with the new SonarQube version."
echo "Otherwise starting errors could occur after the upgrade especially between two major versions."
echo "The compatiblity of many plugins can be checked here: https://docs.sonarqube.org/7.9/instance-administration/plugin-version-matrix/"