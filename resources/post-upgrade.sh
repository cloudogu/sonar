#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

echo "wait until sonar passes all health checks"
if ! doguctl healthy --wait --timeout 120 sonar; then
  echo "timeout reached by waiting of sonar to get healthy"
  exit 1
fi
curl --insecure -X POST https://$(doguctl config --global fqdn)/sonar/api/system/migrate_db
echo "db migration successful"
