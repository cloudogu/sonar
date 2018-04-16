#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

echo "wait until sonar passes all health checks"
if ! doguctl healthy --wait --timeout 120 sonar; then
  echo "timeout reached by waiting of sonar to get healthy"
  exit 1
fi

for file in /opt/sonar/qualityprofiles/*
do
  curl --insecure -X POST -u admin:adminpw -F "backup=@$file" -v https://$(doguctl config --global fqdn)/sonar/api/qualityprofiles/restore
  echo "import of quality profile $file successful"
done;