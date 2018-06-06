#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

SONAR_PROPERTIESFILE=/opt/sonar/conf/sonar.properties

# get variables for templates
QUALITYPROFILESADD_USER="qualityProfilesAdd"
ADMINGROUP=$(doguctl config --global admin_group)
FQDN=$(doguctl config --global fqdn)
DOMAIN=$(doguctl config --global domain)
MAIL_ADDRESS=$(doguctl config -d "sonar@${DOMAIN}" --global mail_address)
# shellcheck disable=SC2034
DATABASE_TYPE=postgresql
DATABASE_IP=postgresql
# shellcheck disable=SC2034
DATABASE_PORT=5432
DATABASE_USER=$(doguctl config -e sa-postgresql/username)
DATABASE_USER_PASSWORD=$(doguctl config -e sa-postgresql/password)
DATABASE_DB=$(doguctl config -e sa-postgresql/database)

# create extra user for importing quality profiles
function create_user_for_importing_profiles {

  # add random password for extra user
  if ! doguctl config -e "qualityProfileAdd_password" > /dev/null ; then
    QUALITYPROFILEADD_PW=$(doguctl random)
    doguctl config -e "qualityProfileAdd_password" "${QUALITYPROFILEADD_PW}"
  fi

  QUALITYPROFILEADD_PW=$(doguctl config -e "qualityProfileAdd_password")

  # create extra user and grant admin permissions so that updating quality profiles is possible
  echo "Add ${QUALITYPROFILESADD_USER} user and grant qualityprofile permissions"
  # ignore CasAuthenticationExceptions in log file, because the credentials below only work locally
  curl --silent -X POST -u admin:admin "localhost:9000/sonar/api/users/create?login=$QUALITYPROFILESADD_USER&password=$QUALITYPROFILEADD_PW&password_confirmation=$QUALITYPROFILEADD_PW&name=$QUALITYPROFILESADD_USER"
  curl --silent -X POST -u admin:admin "localhost:9000/sonar/api/permissions/add_user?permission=profileadmin&login=$QUALITYPROFILESADD_USER"

  echo "extra user for importing quality profiles is set"
}

function import_quality_profiles {

  RESPONSE_USER=$(curl --silent localhost:9000/sonar/api/users/search?q=$QUALITYPROFILESADD_USER);

  if [ $(echo ${RESPONSE_USER%%,*} | cut -d ':' -f2) -eq 0 ]; #check if extra user is still there
  then
    echo "ERROR - user for importing quality profiles ($QUALITYPROFILESADD_USER) is not present any more"
  else

    QUALITYPROFILEADD_PW=$(doguctl config -e "qualityProfileAdd_password") # get password

    echo "start importing quality profiles"
    if [ "$(ls -A /var/lib/qualityprofiles)" ]; # only try to import profiles if directory is not empty
    then
      for file in /var/lib/qualityprofiles/* # import all quality profiles that are in the suitable directory
      do
        # ignore CasAuthenticationExceptions in log file, because the credentials below only work locally
        RESPONSE_IMPORT=$(curl --silent -X POST -u $QUALITYPROFILESADD_USER:$QUALITYPROFILEADD_PW -F "backup=@$file" localhost:9000/sonar/api/qualityprofiles/restore)
        # check if import is successful
        if ! ( echo $RESPONSE_IMPORT | grep -o errors);
        then
          echo "import of quality profile $file was successful"
          # delete file if import was successful
          rm -f "$file"
          echo "removed $file file"
        else
          echo "import of quality profile $file has not been successful"
          echo $RESPONSE_IMPORT
        fi;
      done;
    else
      echo "no quality profiles to import"
    fi;
  fi;
}

function move_sonar_dir(){
  DIR="$1"
  if [ ! -d "/var/lib/sonar/$DIR" ]; then
    mv "/opt/sonar/$DIR" /var/lib/sonar
    ln -s "/var/lib/sonar/$DIR" "/opt/sonar/$DIR"
  elif [ ! -L "/opt/sonar/$DIR" ] && [ -d "/opt/sonar/$DIR" ]; then
    rm -rf "/opt/sonar/$DIR"
    ln -s "/var/lib/sonar/$DIR" "/opt/sonar/$DIR"
  fi
}

function render_template(){
  FILE="$1"
  if [ ! -f "$FILE.tpl" ]; then
    echo "could not find template $FILE.tpl"
    exit 1
  fi

  if [ -f "$FILE" ]; then
    rm -f "$FILE"
  fi
  echo "render template $FILE.tpl to $FILE"
  # render template
  eval "echo \"$(cat "$FILE.tpl")\"" | egrep -v '^#' | egrep -v '^\s*$' > "$FILE"
}

function setProxyConfiguration(){
  removeProxyRelatedEntriesFrom ${SONAR_PROPERTIESFILE}
  # Write proxy settings if enabled in etcd
  if [ "true" == "$(doguctl config --global proxy/enabled)" ]; then
    if PROXYSERVER=$(doguctl config --global proxy/server) && PROXYPORT=$(doguctl config --global proxy/port); then
      writeProxyCredentialsTo ${SONAR_PROPERTIESFILE}
      if PROXYUSER=$(doguctl config --global proxy/username) && PROXYPASSWORD=$(doguctl config --global proxy/password); then
        writeProxyAuthenticationCredentialsTo ${SONAR_PROPERTIESFILE}
      else
        echo "Proxy authentication credentials are incomplete or not existent."
      fi
    else
      echo "Proxy server or port configuration missing in etcd."
    fi
  fi
}

function removeProxyRelatedEntriesFrom() {
  sed -i '/http.proxyHost=.*/d' "$1"
  sed -i '/http.proxyPort=.*/d' "$1"
  sed -i '/http.proxyUser=.*/d' "$1"
  sed -i '/http.proxyPassword=.*/d' "$1"
}

function writeProxyCredentialsTo(){
  echo http.proxyHost="${PROXYSERVER}" >> "$1"
  echo http.proxyPort="${PROXYPORT}" >> "$1"
}

function writeProxyAuthenticationCredentialsTo(){
  # Check for java option and add it if not existent
  if [ -z "$(grep sonar.web.javaAdditionalOpts= "$1" | grep Djdk.http.auth.tunneling.disabledSchemes=)" ]; then
    sed -i '/^sonar.web.javaAdditionalOpts=/ s/$/ -Djdk.http.auth.tunneling.disabledSchemes=/' "$1"
  fi
  # Add proxy authentication credentials
  echo http.proxyUser="${PROXYUSER}" >> ${SONAR_PROPERTIESFILE}
  echo http.proxyPassword="${PROXYPASSWORD}" >> ${SONAR_PROPERTIESFILE}
}

function sql(){
  PGPASSWORD="${DATABASE_USER_PASSWORD}" psql --host "${DATABASE_IP}" --username "${DATABASE_USER}" --dbname "${DATABASE_DB}" -1 -c "${1}"
  return $?
}

function firstSonarStart() {
  echo "first start of SonarQube dogu"
	# prepare config
  # shellcheck disable=SC2034
	REALM="cas"
	render_template "${SONAR_PROPERTIESFILE}"
	# move cas plugin to right folder
	if [ -f "/opt/sonar/sonar-cas-plugin-0.3-TRIO-SNAPSHOT.jar" ]; then
		mv /opt/sonar/sonar-cas-plugin-0.3-TRIO-SNAPSHOT.jar /var/lib/sonar/extensions/plugins/
	fi
  # move german language pack to correct folder
  if [ -f "/opt/sonar/sonar-l10n-de-plugin-1.2.jar" ]; then
    mv /opt/sonar/sonar-l10n-de-plugin-1.2.jar /var/lib/sonar/extensions/plugins/
  fi

  setProxyConfiguration

  # start sonar in background
  su - sonar -c "java -jar /opt/sonar/lib/sonar-application-$SONAR_VERSION.jar" &
  SONAR_PROCESS_ID=$!

  echo "wait until sonarqube has finished database migration"
  N=0
  until [ $N -ge 24 ]; do
    # we are waiting for the last known migration version
    if sql "SELECT 1 FROM schema_migrations WHERE version='1153';" &> /dev/null; then
      break
    else
      N=$[$N+1]
      sleep 10
    fi
  done

  # waiting for sonar to get healthy
  if ! doguctl wait-for-http --timeout 120 --method GET http://localhost:9000/sonar/api/system/status; then
    echo "timeout reached while waiting for sonar to get healthy"
    exit 1
  fi

  # Waiting for SonarQube to be started based on the log file
  # Could not work if old log file is already present, e.g. after upgrade of dogu
  for i in $(seq 1 10);
  do
    # starting compute engine is the last thing sonar does on startup
    if grep -s "Compute Engine is up" /opt/sonar/logs/sonar.log > /dev/null; then
      break
    fi
    if [ "$i" -eq 10 ] ; then
      echo "compute engine did not start in the allowed time. Dogu exits now"
      exit 1
    fi
    echo "wait for compute engine to be up"
    sleep 5
  done

  # create extra user for importing quality profiles
  create_user_for_importing_profiles
  # import quality profiles
  import_quality_profiles

  echo "write ces configurations into database"
	# set base url
  sql "INSERT INTO properties (prop_key, text_value) VALUES ('sonar.core.serverBaseURL', 'https://${FQDN}/sonar');"
  # remove default admin
  sql "DELETE FROM users WHERE login='admin';"
  # add admin group
  sql "INSERT INTO groups (name, description, created_at) VALUES ('${ADMINGROUP}', 'CES Administrator Group', now());"
  # add admin privileges to admin group
  sql "INSERT INTO group_roles (group_id, role) VALUES((SELECT id FROM groups WHERE name='${ADMINGROUP}'), 'admin');"

  # set email settings
  sql "INSERT INTO properties (prop_key, text_value) VALUES ('email.smtp_host.secured', 'postfix');"
  sql "INSERT INTO properties (prop_key, text_value) VALUES ('email.smtp_port.secured', '25');"
  sql "INSERT INTO properties (prop_key, text_value) VALUES ('email.from', '${MAIL_ADDRESS}');"
  sql "INSERT INTO properties (prop_key, text_value) VALUES ('email.prefix', '[SONARQUBE]');"

  echo "restarting sonar to account for configuration changes"
  # kill process (sonar) in background
  kill ${SONAR_PROCESS_ID}
  # kill CeServer process which is started by sonar
  kill "$(ps -ax | grep CeServer | awk 'NR==1{print $1}')"

  # wait for killed processes to disappear
  for i in $(seq 1 10);
  do
    JAVA_PROCESSES=$(ps -ax | grep java | wc -l)
    # 1 instead of 0 because the 'grep java' command itself
    if [ "$JAVA_PROCESSES" -eq 1 ] ; then
      echo "all java processes ended. Starting sonar again"
      break
    fi
    if [ "$i" -eq 10 ] ; then
      echo "java processes did not end in the allowed time. Dogu exits now"
      exit 1
    fi
    echo "wait for all java processes to end"
    sleep 5
  done
}

function subsequentSonarStart() {
  echo "subsequent start of SonarQube dogu"
  # refresh base url
  sql "UPDATE properties SET text_value='https://${FQDN}/sonar' WHERE prop_key='sonar.core.serverBaseURL';"

  # refresh FQDN
  sed -i "/sonar.cas.casServerLoginUrl=.*/c\sonar.cas.casServerLoginUrl=https://${FQDN}/cas/login" ${SONAR_PROPERTIESFILE}
  sed -i "/sonar.cas.casServerUrlPrefix=.*/c\sonar.cas.casServerUrlPrefix=https://${FQDN}/cas" ${SONAR_PROPERTIESFILE}
  sed -i "/sonar.cas.sonarServerUrl=.*/c\sonar.cas.sonarServerUrl=https://${FQDN}/sonar" ${SONAR_PROPERTIESFILE}
  sed -i "/sonar.cas.casServerLogoutUrl=.*/c\sonar.cas.casServerLogoutUrl=https://${FQDN}/cas/logout" ${SONAR_PROPERTIESFILE}

  setProxyConfiguration


  # start sonar in background to have the possibility to import quality profiles
  su - sonar -c "java -jar /opt/sonar/lib/sonar-application-$SONAR_VERSION.jar" &
  SONAR_PROCESS_ID=$!

  # waiting for sonar to get healthy
  if ! doguctl wait-for-http --timeout 120 --method GET http://localhost:9000/sonar/api/system/status; then
    echo "timeout reached while waiting for sonar to get healthy"
    exit 1
  fi

  import_quality_profiles

  # stop/kill sonar after importing quality profiles
 echo "restarting sonar to account for configuration changes"
  # kill process (sonar) in background
  kill ${SONAR_PROCESS_ID}
  # kill CeServer process which is started by sonar
  kill "$(ps -ax | grep CeServer | awk 'NR==1{print $1}')"

  # wait for killed processes to disappear
  for i in $(seq 1 10);
  do
    JAVA_PROCESSES=$(ps -ax | grep java | wc -l)
    # 1 instead of 0 because the 'grep java' command itself
    if [ "$JAVA_PROCESSES" -eq 1 ] ; then
      echo "all java processes ended. Starting sonar again"
      break
    fi
    if [ "$i" -eq 10 ] ; then
      echo "java processes did not end in the allowed time. Dogu exits now"
      exit 1
    fi
    echo "wait for all java processes to end"
    sleep 5
  done
}

### End of declarations, work is done now

doguctl state "internalPreparations"

move_sonar_dir conf
move_sonar_dir extensions
move_sonar_dir data
move_sonar_dir logs
move_sonar_dir temp

doguctl state "waitingForPostgreSQL"

echo "wait until postgresql passes all health checks"
if ! doguctl healthy --wait --timeout 120 postgresql; then
  echo "timeout reached by waiting of postgresql to get healthy"
  exit 1
fi

# create truststore, which is used in the sonar.properties file
create_truststore.sh > /dev/null

doguctl state "installing..."

# check whether initialization has already been performed
if ! [ "$(cat ${SONAR_PROPERTIESFILE} | grep sonar.security.realm)" == "sonar.security.realm=cas" ]; then
  firstSonarStart
else
  subsequentSonarStart
fi


doguctl state "ready"
# fire it up
exec su - sonar -c "java -jar /opt/sonar/lib/sonar-application-$SONAR_VERSION.jar"
