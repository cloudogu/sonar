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

## Shell testing with BATS

You can create and amend bash tests in the `unitTests` directory. The make target `unit-test-shell` will support you with a generalized bash test environment.

```bash
make unit-test-shell
```

BATS is configured to leave JUnit compatible reports in `target/shell_test_reports/`.

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

1. Install SCM Manager and Jenkins in CES
   - `cesapp install official/jenkins; cesapp install official/scm; cesapp start scm; cesapp start jenkins`
2. SCMM:
   - Import Spring Petclinic into a new repository in the SCM Manager via SCMM repo import
   - Import: https://github.com/cloudogu/spring-petclinic/
   - Admin credentials are sufficient for this test
3. SonarQube
   1. Create a SonarQube token
      1. Navigate as admin to the [Security page](https://192.168.56.2/sonar/account/security) <!-- markdown-link-check-disable-line -->
      2. Generate token
         - Name: `admin_token`
         - Type: `Global Analysis Token`
         - Expires in: `30 Days`
      3. Copy generated token
   2. Create a webhook
      1. navigate as admin to the [global Webhooks page](https://192.168.56.2/sonar/admin/webhooks) <!-- markdown-link-check-disable-line -->
      2. Create a new webhook with the `[ Create ]` button
         - Name: `ces`
         - URL: `https://192.168.56.2/jenkins/sonarqube-webhook` <!-- markdown-link-check-disable-line -->
         - Secret: leave empty
4. Jenkins
   1. Create sonar scanner if necessary
      - Navigate to [Dashboard/Manage Jenkins/Tools](https://192.168.56.2/jenkins/manage/configureTools/) <!-- markdown-link-check-disable-line -->
      - In the "SonarQube Scanner Installations" section, create an entry via Maven Central
      - name: `sonar-scanner`
      - Version: `4.8.1` (maximum [Java 11](https://docs.sonarsource.com/sonarqube/9.9/analyzing-source-code/scanners/sonarscanner/))
   2. Configure SonarServer if necessary
      - navigate to [Manage Dashboard/Jenkins/System](https://192.168.56.2/jenkins/manage/configure) <!-- markdown-link-check-disable-line -->
      - Configure the following in the "SonarQube servers" section
         - Environment variables: yes/check
         - Name: `sonar`
         - Server URL: `http://sonar:9000/sonar`
      - Server authentication token: Press `add`
         - Create credential of type "Secret Text" with the token generated in SonarQube
         - **do not** configure a **Secret for the webhook**
   3. insert credentials for SCMM and SonarQube in the [Jenkins Credential Manager](https://192.168.56.2/jenkins/manage/credentials/store/system/domain/_/newCredentials) <!-- markdown-link-check-disable-line -->
      - Store admin credentials under the ID `scmCredentials`
         - SCMM and SonarQube share admin credentials (SCMM in the build configuration, SonarQube in the Jenkinsfile)
      - Pay attention to the credential type for SonarQube!
         - `Username/Password` for Basic Authentication
   4. create build job
      1. Create 1st element -> Select `Multibranch Pipeline` -> Configure job
         - Select Branch Sources/Add source: "SCM-Manager (git, hg)"
         - Server URL: https://192.168.56.2/scm/ <!-- markdown-link-check-disable-line -->
         - Credentials for SCM Manager: select the credential `scmCredentials` configured above
      2. save job
         - the Jenkinsfile will be found automatically
      3. if necessary, cancel surplus/non-functioning jobs
      4. adapt and build the master branch with regard to changed credentials or unwanted job days
         - An old version (ces-build-lib@1.35.1) of the `ces-build-lib` is important, newer versions lead to authentication errors
         - an exchange for a newer build-lib is not relevant in the context of smoke tests of SonarQube