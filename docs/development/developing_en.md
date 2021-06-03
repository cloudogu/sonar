# Developing the SonarQube dogu

Build SonarQube inside a running CES instance by changing into this repository. Call then `cesapp` to install/upgrade and start the dogu:

```bash
cd /your/workspace/sonar
cesapp build .
cesapp start sonar
```

## Integrating and Test the Sonar CAS Plugin within the Dogu

There are two alternatives for testing development versions of the [Sonar CAS Plugin](https://github.com/cloudogu/sonar-cas-plugin/) (you can find the compiling instructions there):

1. Replace the plugin version in an already running SonarQube
    - `rm /var/lib/ces/sonar/volumes/extensions/plugins/sonar-cas-plugin-2.0.1.jar`
    - `cp your-sonar-cas-plugin.jar /var/lib/ces/sonar/volumes/extensions/plugins/`
    - `sudo docker restart sonar`
1. Modify the Dockerfile and build another image with your local plugin version
    - comment-out lines that focus on sonar-cas-plugin
    - add a new line for `COPY`ing your plugin, like so:
        - `COPY --chown=1000:1000 sonar-cas-plugin-3.0.0-SNAPSHOT.jar ${SONARQUBE_HOME}/sonar-cas-plugin-3.0.0-SNAPSHOT.jar`

## Shell testing

You can create and amend bash tests in the `unitTests` directory. The make target `unit-test-shell` will support you with a generalized bash test environment.

```bash
make unit-test-shell
```

In order to write testable shell scripts these aspects should be respected:

### Global environment variable `STARTUP_DIR`

The global environment variable `STARTUP_DIR` will point to the directory where the production scripts (aka: scripts-under-test) reside. Inside the dogu container this is usually `/`. But during testing it is easier to put it somewhere else for permission reasons.

A second reason is that the scripts-under-test source other scripts. Absolute paths will make testing quite hard. Source new scripts like so, in order that the tests will run smoothly:

```bash
source "${STARTUP_DIR}"/util.sh
```

Please note in the above example the shellcheck disablement comment. Because `STARTUP_DIR` is wired into the `Dockerfile` it is considered as global environment variable that will never be found unset (which would soon be followed by errors).

Currently sourcing scripts in a static manner (that is: without dynamic variable in the path) makes shell testing impossible (unless you find a better way to construct the test container)

### General structure of scripts-under-test

It is rather uncommon to run a _scripts-under-test_ like `startup.sh` all on its own. Effective unit testing will most probably turn into a nightmare if no proper script structure is put in place. Because these scripts source each other _AND_ execute code **everything** must be set-up beforehand: global variables, mocks of every single binary being called... and so on. In the end the tests would reside on an end-to-end test level rather than unit test level.

The good news is that testing single functions is possible with these little parts:

1. Use sourcing execution guards
1. Run binaries and logic code only inside functions
1. Source with (dynamic yet fixed-up) environment variables

#### Use sourcing execution guards

Make sourcing possible with _sourcing execution guards._ like this:

```bash
# yourscript.sh
function runTheThing() {
    echo "hello world"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  runTheThing
fi
```

The `if`-condition below will be executed if the script is executed by calling via the shell but not when sourced:

```bash
$ ./yourscript.sh
hello world
$ source yourscript.sh
$ runTheThing
hello world
$
```

Execution guards work also with parameters:

```bash
# yourscript.sh
function runTheThing() {
    echo "${1} ${2}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  runTheThingWithParameters "$@"
fi
```

Note the proper argument passing with `"$@"` which allows for arguments that contain whitespace and such.

```bash
$ ./yourscript.sh hello world
hello world
$ source yourscript.sh
$ runTheThing hello bash
hello bash
$
```

#### Run binaries and logic code only inside functions

Environment variables and constants are okay, but once logic runs outside a function it will be executed during script sourcing.

#### Source with (dynamic yet fixed-up) environment variables

Shellcheck basically says this is a no-no. Anyhow unless the test container allows for  appropriate script paths there is hardly a way around it:

```bash
sourcingExitCode=0
# shellcheck disable=SC1090
source "${STARTUP_DIR}"/util.sh || sourcingExitCode=$?
if [[ ${sourcingExitCode} -ne 0 ]]; then
  echo "ERROR: An error occurred while sourcing /util.sh."
fi
```

At least make sure that the variables are properly set into the production (f. i. `Dockerfile`)and test environment (set-up an env var in your test).

## Test SonarQube Dogu

Due to communication problems caused by self-signed SSL certificates in a development CES instance, it is a good idea to run SonarScanner via Jenkins in the same instance. The following procedure has proven successful:

1. install SCM Manager and Jenkins.
   - `cesapp install official/scm; cesapp install official/scm; cesapp start scm; cesapp start jenkins`
1. SCMM: install Spring Petclinic in SCM manager by SCMM repo import into a new repository
1. sonarQube: create local user or API token if necessary
1. jenkins
   1. add credentials for SCMM and SonarQube in Jenkins Credential Manager
      - for SCMM e.g. under the ID `scmCredentials
      - for SonarQube pay attention to credential type!
         - username/password for Basic Authentication
         - `Secret text` for SQ API token
   1. create build job
      1. create element -> select `SCM-Manager Namespace` -> configure job
         - Server URL: https://192.198.56.2/scm
         - Credentials: as configured above
      1. save job
      1. cancel surplus/non-functioning jobs if necessary
      1. adjust and build master/main branch
