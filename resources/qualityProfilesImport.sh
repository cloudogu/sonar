#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail


QUALITYPROFILESADD_USER="qualityProfilesAdd"

echo "wait until sonar passes all health checks"
if ! doguctl healthy --wait --timeout 120 sonar; then
  echo "timeout reached by waiting of sonar to get healthy"
  exit 1
fi

# create extra user for importing quality profiles
create_user_for_importing_profiles

QUALITYPROFILESADD_USER="qualityProfilesAdd"
QUALITYPROFILEADD_PW=$(doguctl config -e "qualityProfileAdd_password")

if find /opt/sonar/qualityprofiles -maxdepth 0 -type d -empty 2>/dev/null;
then
  for file in /opt/sonar/qualityprofiles/*
  do
    curl --insecure -X POST -u $QUALITYPROFILESADD_USER:$QUALITYPROFILEADD_PW -F "backup=@$file" -v localhost:9000/sonar/api/qualityprofiles/restore
    echo "import of quality profile $file successful"
  done;
fi;