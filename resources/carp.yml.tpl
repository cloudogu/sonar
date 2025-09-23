# skip-ssl-verification can be used to allow certificates from TLS requests that would fail otherwise.
# DO NOT ENABLE WHEN RUNNING IN PRODUCTION MODE
skip-ssl-verification: true
# port contains the TCP port under which the CARP can be reached.
# Change this port if you run the carp locally under another port.
port: 8080
# cas-url contains the URL to the CAS to which requests are redirected if unauthenticated.
cas-url: https://{{.GlobalConfig.Get "fqdn"}}/cas
# service-url contains the URL to the actual application WITHOUT context path.
# Change the port of this URL if you run your local SonarQube under another port
# Typically, this URL is hidden from the user for security reasons to avoid bypassing
service-url: http://localhost:9000/
# app-context-path contains the payload application's context path.
# This URL path also is used to detect backchannel logout requests as CAS default behaviour is to POST SAML parameters
# against the main application path.
# This value must correspond with sonar.web.context in the sonar.properties configuration file.
logout-redirect-path: /sonar/
# logout-path-frontchannel-endpoint contains a URL endpoint (without context path) to detect SonarQube frontchannel logout
logout-path: /sonar/sessions/logout
# logout-path-backchannel-endpoint contains a URL endpoint (without context path) which will be called during channel logout to
# terminate existing SonarQube sessions for the user provided by the CAS logout information.
logout-path-backchannel-endpoint: /api/authentication/logout

# The *-header values must match SonarQubes authentication headers. Please see the SQ docs for more infos
# the principal-header value must correspond with sonar.web.sso.loginHeader in sonar.properties
principal-header: X-Forwarded-Login
# the principal-header value must correspond with sonar.web.sso.groupsHeader in sonar.properties
role-header: X-Forwarded-Groups
# the principal-header value must correspond with sonar.web.sso.emailHeader in sonar.properties
mail-header: X-Forwarded-Email
# the principal-header value must correspond with sonar.web.sso.nameHeader in sonar.properties
name-header: X-Forwarded-Name
# sonar-admin-group cotnains the name of the injected group information if a CES account was detected that belongs to
# CES admin group and further administration permissions should be granted to the user.
sonar-admin-group: sonar-administrators
# ces-admin-group contains the name of the current Cloudogu EcoSystem admin group. If the request's user is a CES admin
# this will lead to an additional HTTP proxy request headers.
ces-admin-group: "{{ .Env.Get "CES_ADMIN_GROUP" }}"

# log-format influences the log message's layout.
log-format: "%{level:.4s} [%{module}:%{shortfile}] %{message}"
# log-level influences the CARP's log verbosity. Supported values are ERROR, WARN, INFO, DEBUG
log-level: "{{ .Config.GetOrDefault "logging/root" "WARN" }}"
# application-exec-command contains the command which will start SonarQube. Chaining CARP and application in this way avoids
# multiple concurrent processes inside a container. During development this could be set to "sleep infinity".
application-exec-command: "{{ .Env.Get "carpExecCommand" }}"
# carp-resource-paths accepts a list of regular expressions of SonarQube routes that do not need authorization.
# For security reasons, here usually appear static resources like CSS files etc.
# example: /sonar/css/ matches all requests that start with this path
# Note: A misconfiguration could lead to undesirable exposing of authenticated
# information.
carp-resource-paths:
  - /sonar/css/
  - /sonar/favicon.ico
  - /sonar/fonts/
  - /sonar/images/
  - /sonar/js/



