#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

echo "wait until sonar passes all health checks"
if ! doguctl healthy --wait --timeout 120 sonar; then
  echo "timeout reached by waiting of sonar to get healthy"
  exit 1
fi
curl --insecure -X POST -u admin:adminpw -F 'backup=@opt/sonar/qualityprofiles/java-sonar-way-92069.xml' -v https://$(doguctl config --global fqdn)/sonar/api/qualityprofiles/restore 
echo "import of quality profiles successful"
