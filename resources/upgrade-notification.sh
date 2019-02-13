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
fi