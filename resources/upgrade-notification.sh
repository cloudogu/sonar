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