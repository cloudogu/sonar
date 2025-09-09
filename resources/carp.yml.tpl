# Change the port of this url if you run the carp locally under another port
base-url: http://localhost:8080/sonar/
cas-url: https://{{.GlobalConfig.Get "fqdn"}}/cas

# Change the port of this url if you run your local sonarqube under another port
service-url: http://localhost:9000/
logout-path: /sonar/sessions/logout
logout-redirect-path: /sonar/

skip-ssl-verification: true
# Change this port if you run the carp locally under another port
port: 8080
# The *-header values must match SonarQubes authentication headers. Please see the SQ docs for more infos
# the principal-header value must correspond with sonar.web.sso.loginHeader in sonar.properties
principal-header: X-Forwarded-Login
# the principal-header value must correspond with sonar.web.sso.groupsHeader in sonar.properties
role-header: X-Forwarded-Groups
# the principal-header value must correspond with sonar.web.sso.emailHeader in sonar.properties
mail-header: X-Forwarded-Email
# the principal-header value must correspond with sonar.web.sso.nameHeader in sonar.properties
name-header: X-Forwarded-Name
log-format: "%{level:.4s} [%{module}:%{shortfile}] %{message}"
log-level: "{{ .Config.GetOrDefault "logging/root" "WARN" }}"
# the value will be used to check if a user belongs to the CES administrator group.
ces-admin-group: "{{ .Env.Get "CES_ADMIN_GROUP" }}"
# the value will be added to a CES administrators's group list during the CAS authentication
sonar-admin-group: sonar-administrators
# This command will starts SonarQube to avoid multiple concurrent processes in a container.
application-exec-command: "{{ .Env.Get "carpExecCommand" }}"
# The following list of regular expressions of SonarQube routes mark routes that do not need authorization.
# For security reasons, here usually appear static resources like CSS files etc.
# example: /sonar/css/ matches all requests that start with this path
carp-resource-paths:
  - /sonar/css/
  - /sonar/favicon.ico
  - /sonar/fonts/
  - /sonar/images/
  - /sonar/js/



