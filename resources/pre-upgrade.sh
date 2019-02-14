#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# import util functions:
# sql()
# add_temporary_admin_user()
# remove_temporary_admin_user functions()
source util.sh

FROM_VERSION="${1}"
TO_VERSION="${2}"
DATABASE_IP=postgresql
DATABASE_USER=$(doguctl config -e sa-postgresql/username)
DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
DATABASE_DB=$(doguctl config -e sa-postgresql/database)

if [[ ${FROM_VERSION} == *"5.6.7"* ]] && [[ ${TO_VERSION} == *"6.7."* ]]; then
  # temporarily create admin user
  TEMPORARY_ADMIN_USER=$(doguctl random)
  add_temporary_admin_user ${TEMPORARY_ADMIN_USER}

  # get plugins which are not up to date
  AVAILABLE_PLUGIN_UPDATES=$(curl --silent -u "${TEMPORARY_ADMIN_USER}":admin -X GET localhost:9000/sonar/api/plugins/updates | jq '.plugins' | jq '.[]' | jq -r '.key')
  # remove them
  while read -r PLUGIN; do
    echo "Removing plugin ${PLUGIN}..."
    curl --silent -u "${TEMPORARY_ADMIN_USER}":admin -X POST "localhost:9000/sonar/api/plugins/uninstall?key=${PLUGIN}"
  done <<< "${AVAILABLE_PLUGIN_UPDATES}"

  # remove temporary admin user
  remove_temporary_admin_user ${TEMPORARY_ADMIN_USER}
fi




