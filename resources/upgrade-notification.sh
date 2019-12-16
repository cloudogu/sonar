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

if [[ $(cat /proc/sys/vm/max_map_count) -lt 262144 ]]; then
  echo "Your max virtual memory areas vm.max_map_count is too low, increase to at least [262144]. You can do so by upgrading the ces-commons package to at least version 0.2.0."
  exit 1
fi
