# This file must contain only ISO 8859-1 characters.
# See http://docs.oracle.com/javase/1.5.0/docs/api/java/util/Properties.html#load(java.io.InputStream)
#
# Property values can:
# - reference an environment variable
# - be encrypted. See http://redirect.sonarsource.com/doc/settings-encryption.html


#--------------------------------------------------------------------------------------------------
# DATABASE
#
# IMPORTANT: the embedded H2 database is used by default. It is recommended for tests but not for
# production use. Supported databases are MySQL, Oracle, PostgreSQL and Microsoft SQLServer.

# User credentials.
# Permissions to create tables, indices and triggers must be granted to JDBC user.
# The schema must be created first.
#sonar.jdbc.username=sonar
#sonar.jdbc.password=sonar

#----- Embedded Database (default)
# It does not accept connections from remote hosts, so the
# server and the analyzers must be executed on the same host.
#sonar.jdbc.url=jdbc:h2:tcp://localhost:9092/sonar

# H2 embedded database server listening port, defaults to 9092
#sonar.embeddedDatabase.port=9092


#----- MySQL 5.x
# Only InnoDB storage engine is supported (not myISAM).
# Only the bundled driver is supported.
#sonar.jdbc.url=jdbc:mysql://localhost:3306/sonar?useUnicode=true&characterEncoding=utf8&rewriteBatchedStatements=true&useConfigs=maxPerformance


#----- Oracle 10g/11g
# - Only thin client is supported
# - Only versions 11.2.* of Oracle JDBC driver are supported, even if connecting to lower Oracle versions.
# - The JDBC driver must be copied into the directory extensions/jdbc-driver/oracle/
# - If you need to set the schema, please refer to http://jira.codehaus.org/browse/SONAR-5000
#sonar.jdbc.url=jdbc:oracle:thin:@localhost/XE


#----- PostgreSQL 8.x/9.x
# If you don't use the schema named "public", please refer to http://jira.codehaus.org/browse/SONAR-5000
#sonar.jdbc.url=jdbc:postgresql://localhost/sonar


#----- Microsoft SQLServer 2008/2012
# Only the bundled jTDS driver is supported.
# Collation must be case-sensitive (CS) and accent-sensitive (AS).
#sonar.jdbc.url=jdbc:jtds:sqlserver://localhost/sonar;SelectMethod=Cursor


#----- Connection pool settings
# The maximum number of active connections that can be allocated
# at the same time, or negative for no limit.
#sonar.jdbc.maxActive=50

# The maximum number of connections that can remain idle in the
# pool, without extra ones being released, or negative for no limit.
#sonar.jdbc.maxIdle=5

# The minimum number of connections that can remain idle in the pool,
# without extra ones being created, or zero to create none.
#sonar.jdbc.minIdle=2

# The maximum number of milliseconds that the pool will wait (when there
# are no available connections) for a connection to be returned before
# throwing an exception, or <= 0 to wait indefinitely.
#sonar.jdbc.maxWait=5000

#sonar.jdbc.minEvictableIdleTimeMillis=600000
#sonar.jdbc.timeBetweenEvictionRunsMillis=30000



#--------------------------------------------------------------------------------------------------
# WEB SERVER

# Web server is executed in a dedicated Java process. By default heap size is 768Mb.
# Use the following property to customize JVM options.
#    Recommendations:
#
#    The HotSpot Server VM is recommended. The property -server should be added if server mode
#    is not enabled by default on your environment: http://docs.oracle.com/javase/7/docs/technotes/guides/vm/server-class.html
#
#    Set min and max memory (respectively -Xms and -Xmx) to the same value to prevent heap
#    from resizing at runtime.
#
#sonar.web.javaOpts=-Xmx768m -XX:MaxPermSize=160m -XX:+HeapDumpOnOutOfMemoryError

# Same as previous property, but allows to not repeat all other settings like -Xmx
#sonar.web.javaAdditionalOpts=

# Binding IP address. For servers with more than one IP address, this property specifies which
# address will be used for listening on the specified ports.
# By default, ports will be used on all IP addresses associated with the server.
#sonar.web.host=0.0.0.0

# Web context. When set, it must start with forward slash (for example /sonarqube).
# The default value is root context (empty value).
sonar.web.context=/sonar

# TCP port for incoming HTTP connections. Disabled when value is -1.
#sonar.web.port=9000


# Recommendation for HTTPS
#    SonarQube natively supports HTTPS. However using a reverse proxy
#    infrastructure is the recommended way to set up your SonarQube installation
#    on production environments which need to be highly secured.
#    This allows to fully master all the security parameters that you want.

# TCP port for incoming HTTPS connections. Disabled when value is -1 (default).
#sonar.web.https.port=-1

# HTTPS - the alias used to for the server certificate in the keystore.
# If not specified the first key read in the keystore is used.
#sonar.web.https.keyAlias=

# HTTPS - the password used to access the server certificate from the
# specified keystore file. The default value is "changeit".
#sonar.web.https.keyPass=changeit

# HTTPS - the pathname of the keystore file where is stored the server certificate.
# By default, the pathname is the file ".keystore" in the user home.
# If keystoreType doesn't need a file use empty value.
#sonar.web.https.keystoreFile=

# HTTPS - the password used to access the specified keystore file. The default
# value is the value of sonar.web.https.keyPass.
#sonar.web.https.keystorePass=

# HTTPS - the type of keystore file to be used for the server certificate.
# The default value is JKS (Java KeyStore).
#sonar.web.https.keystoreType=JKS

# HTTPS - the name of the keystore provider to be used for the server certificate.
# If not specified, the list of registered providers is traversed in preference order
# and the first provider that supports the keystore type is used (see sonar.web.https.keystoreType).
#sonar.web.https.keystoreProvider=

# HTTPS - the pathname of the truststore file which contains trusted certificate authorities.
# By default, this would be the cacerts file in your JRE.
# If truststoreFile doesn't need a file use empty value.
#sonar.web.https.truststoreFile=

# HTTPS - the password used to access the specified truststore file.
#sonar.web.https.truststorePass=

# HTTPS - the type of truststore file to be used.
# The default value is JKS (Java KeyStore).
#sonar.web.https.truststoreType=JKS

# HTTPS - the name of the truststore provider to be used for the server certificate.
# If not specified, the list of registered providers is traversed in preference order
# and the first provider that supports the truststore type is used (see sonar.web.https.truststoreType).
#sonar.web.https.truststoreProvider=

# HTTPS - whether to enable client certificate authentication.
# The default is false (client certificates disabled).
# Other possible values are 'want' (certificates will be requested, but not required),
# and 'true' (certificates are required).
#sonar.web.https.clientAuth=false

# HTTPS - comma separated list of encryption ciphers to support for HTTPS connections.
# If specified, only the ciphers that are listed and supported by the SSL implementation will be used.
# By default, the default ciphers for the JVM will be used. Note that this usually means that the weak
# export grade ciphers, for instance RC4, will be included in the list of available ciphers.
# The ciphers are specified using the JSSE cipher naming convention (see
# https://www.openssl.org/docs/apps/ciphers.html)
# Example: sonar.web.https.ciphers=TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384
#sonar.web.https.ciphers=

# The maximum number of connections that the server will accept and process at any given time.
# When this number has been reached, the server will not accept any more connections until
# the number of connections falls below this value. The operating system may still accept connections
# based on the sonar.web.connections.acceptCount property. The default value is 50 for each
# enabled connector.
#sonar.web.http.maxThreads=50
#sonar.web.https.maxThreads=50

# The minimum number of threads always kept running. The default value is 5 for each
# enabled connector.
#sonar.web.http.minThreads=5
#sonar.web.https.minThreads=5

# The maximum queue length for incoming connection requests when all possible request processing
# threads are in use. Any requests received when the queue is full will be refused.
# The default value is 25 for each enabled connector.
#sonar.web.http.acceptCount=25
#sonar.web.https.acceptCount=25

# TCP port for incoming AJP connections. Disabled if value is -1. Disabled by default.
#sonar.ajp.port=-1


#--------------------------------------------------------------------------------------------------
# ELASTICSEARCH
# Elasticsearch is used to facilitate fast and accurate information retrieval.
# It is executed in a dedicated Java process.

# JVM options of Elasticsearch process
#    Recommendations:
#
#    Use HotSpot Server VM. The property -server should be added if server mode
#    is not enabled by default on your environment: http://docs.oracle.com/javase/7/docs/technotes/guides/vm/server-class.html
#
#    Set min and max memory (respectively -Xms and -Xmx) to the same value to prevent heap
#    from resizing at runtime.
#
#sonar.search.javaOpts=-Xmx1G -Xms256m -Xss256k -Djava.net.preferIPv4Stack=true \
#  -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=75 \
#  -XX:+UseCMSInitiatingOccupancyOnly -XX:+HeapDumpOnOutOfMemoryError

# Same as previous property, but allows to not repeat all other settings like -Xmx
#sonar.search.javaAdditionalOpts=

# Elasticsearch port. Default is 9001. Use 0 to get a free port.
# This port must be private and must not be exposed to the Internet.
#sonar.search.port=9001


#--------------------------------------------------------------------------------------------------
# UPDATE CENTER

# Update Center requires an internet connection to request http://update.sonarsource.org
# It is enabled by default.
#sonar.updatecenter.activate=true

# HTTP proxy (default none)
#http.proxyHost=
#http.proxyPort=

# NT domain name if NTLM proxy is used
#http.auth.ntlm.domain=

# SOCKS proxy (default none)
#socksProxyHost=
#socksProxyPort=

# proxy authentication. The 2 following properties are used for HTTP and SOCKS proxies.
#http.proxyUser=
#http.proxyPassword=


#--------------------------------------------------------------------------------------------------
# LOGGING

# Level of logs. Supported values are INFO, DEBUG and TRACE
#sonar.log.level=INFO

# Path to log files. Can be absolute or relative to installation directory.
# Default is <installation home>/logs
#sonar.path.logs=logs

# Rolling policy of log files
#    - based on time if value starts with "time:", for example by day ("time:yyyy-MM-dd")
#      or by month ("time:yyyy-MM")
#    - based on size if value starts with "size:", for example "size:10MB"
#    - disabled if value is "none".  That needs logs to be managed by an external system like logrotate.
#sonar.log.rollingPolicy=time:yyyy-MM-dd

# Maximum number of files to keep if a rolling policy is enabled.
#    - maximum value is 20 on size rolling policy
#    - unlimited on time rolling policy. Set to zero to disable old file purging.
#sonar.log.maxFiles=7

# Access log is the list of all the HTTP requests received by server. If enabled, it is stored
# in the file {sonar.path.logs}/access.log. This file follows the same rolling policy as for
# sonar.log (see sonar.log.rollingPolicy and sonar.log.maxFiles).
#sonar.web.accessLogs.enable=true

# Format of access log. It is ignored if sonar.web.accessLogs.enable=false. Value is:
#    - "common" is the Common Log Format (shortcut for: %h %l %u %user %date "%r" %s %b)
#    - "combined" is another format widely recognized (shortcut for: %h %l %u [%t] "%r" %s %b "%i{Referer}" "%i{User-Agent}")
#    - else a custom pattern. See http://logback.qos.ch/manual/layouts.html#AccessPatternLayout
#sonar.web.accessLogs.pattern=combined


#--------------------------------------------------------------------------------------------------
# OTHERS

# Delay in seconds between processing of notification queue. Default is 60 seconds.
#sonar.notifications.delay=60

# Paths to persistent data files (embedded database and search index) and temporary files.
# Can be absolute or relative to installation directory.
# Defaults are respectively <installation home>/data and <installation home>/temp
#sonar.path.data=data
#sonar.path.temp=temp


#--------------------------------------------------------------------------------------------------
# DEVELOPMENT - only for developers
# The following properties MUST NOT be used in production environments.

# Dev mode allows to reload web sources on changes and to restart server when new versions
# of plugins are deployed.
#sonar.web.dev=false

# Path to webapp sources for hot-reloading of Ruby on Rails, JS and CSS (only core,
# plugins not supported).
#sonar.web.dev.sources=/path/to/server/sonar-web/src/main/webapp

# Uncomment to enable the Elasticsearch HTTP connector, so that ES can be directly requested through
# http://lmenezes.com/elasticsearch-kopf/?location=http://localhost:9010
#sonar.search.httpPort=9010

# ces properties
sonar.jdbc.username=${DATABASE_USER}
sonar.jdbc.password=${DATABASE_USER_PASSWORD}
sonar.jdbc.url=jdbc:${DATABASE_TYPE}://${DATABASE_IP}:${DATABASE_PORT}/${DATABASE_DB}
sonar.jdbc.maxActive=20
sonar.jdbc.maxIdle=5
sonar.jdbc.minIdle=2
sonar.jdbc.maxWait=5000
sonar.jdbc.minEvictableIdleTimeMillis=600000
sonar.jdbc.timeBetweenEvictionRunsMillis=30000
sonar.notifications.delay=60
sonar.security.realm=${REALM}
sonar.authenticator.createUsers=true
sonar.cas.forceCasLogin=true
sonar.cas.protocol=saml11
sonar.cas.casServerLoginUrl=https://${FQDN}/cas/login
sonar.cas.casServerUrlPrefix=https://${FQDN}/cas
sonar.cas.sonarServerUrl=https://${FQDN}/sonar
sonar.cas.casServerLogoutUrl=https://${FQDN}/cas/logout
sonar.cas.rolesAttributes=groups,roles
sonar.cas.eMailAttribute=mail
sonar.cas.disableCertValidation=false
sonar.cas.fullNameAttribute=displayName

# log to console
sonar.log.console=true

# java opts
sonar.web.javaAdditionalOpts=-Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true -Djava.net.preferIPv4Stack=true -Djavax.net.ssl.trustStore=/etc/ssl/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit -Djdk.http.auth.tunneling.disabledSchemes=""
