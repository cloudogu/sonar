# SonarQube Community Branch Plugin
The [SonarQube Community Branch Plugin](https://github.com/mc1arke/sonarqube-community-branch-plugin) is a plugin for SonarQube to enable branch analysis in the SonarQube Community version.

The plugin must always be installed in the appropriate version for the SonarQube version.
See: [SonarQube version appropriate community plugin](https://github.com/mc1arke/sonarqube-community-branch-plugin?tab=readme-ov-file#compatibility)

When the Dogus is started, it is checked whether the JAR file of the “Community Branch Plugin” exists in `/opt/sonar/extensions/downloads` or `/opt/sonar/extensions/plugins` and then also copied to `/opt/sonar/lib/common`.
This is necessary so that the plugin can be executed correctly and the dogu starts.

## Installation

### Manual installation via the volume
1. as CES shell administrator: download the [SonarQube version appropriate community plugin](https://github.com/mc1arke/sonarqube-community-branch-plugin?tab=readme-ov-file#compatibility) as JAR
2. move the downloaded JAR file to `/var/lib/ces/sonar/volumes/extensions/plugins/`
3. restart SonarQube

### Installation via the update center
The “Community Branch Plugin” can also be installed via the Update Center.

1. create an update center `.properties` file and enter the required version of the “Community Branch Plugin” there.
   Example:
    ```properties
    plugins=communityBranchPlugin
    publicVersions=9.8,9.9,9.9.1,9.9.2,9.9.3,9.9.4,9.9.5,9.9.6,9.9.7,9.9.8,10.0,10.1,10.2,10.2.1,10.3,10.4,10.4.1,10.5,10.5.1,10.6,10.7,10.8,2025.1
    ltaVersion=2025.1
    ltsVersion=2025.1
    sqcb=24.12,25.1,25.2
    sqs=10.8,10.8.1,2025.1
    date=2025-02-27T12\:54\:36+0000
    
    communityBranchPlugin.publicVersions = 1.14.0,1.23.0
    communityBranchPlugin.versions = 1.14.0,1.23.0
    communityBranchPlugin.archivedVersions =
    communityBranchPlugin.category = External Analyzers
    communityBranchPlugin.description = Enables branch and pull request analysis in SonarQube Community Edition, without having to upgrade to Developer Edition
    communityBranchPlugin.developers = Michael Clarke
    communityBranchPlugin.homepageUrl = https://github.com/mc1arke/sonarqube-community-branch-plugin
    communityBranchPlugin.issueTrackerUrl = https://github.com/mc1arke/sonarqube-community-branch-plugin/issues
    communityBranchPlugin.license = GNU LGPL 3 LICENSE
    communityBranchPlugin.name = Community Branch Plugin
    communityBranchPlugin.scm = https://github.com/mc1arke/sonarqube-community-branch-plugin
    communityBranchPlugin.1.14.0.changelogUrl = https://github.com/mc1arke/sonarqube-community-branch-plugin/releases
    communityBranchPlugin.1.14.0.date = 2022-12-31
    communityBranchPlugin.1.14.0.downloadUrl = https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/1.14.0/sonarqube-community-branch-plugin-1.14.0.jar
    communityBranchPlugin.1.14.0.requiredSonarVersions = 9.8,9.9,9.9.1,9.9.4,9.9.5,9.9.6,9.9.7,9.9.8
    communityBranchPlugin.1.14.0.sqVersions = 9.8,9.9,9.9.1,9.9.4,9.9.5,9.9.6,9.9.7,9.9.8
    communityBranchPlugin.1.14.0.description = This version supports Sonarqube 9.8 and above. Sonarqube 9.7 and below are not supported in this release.
    communityBranchPlugin.1.14.0.mavenGroupId = com.github.mc1arke.sonarqube.plugin
    communityBranchPlugin.1.14.0.mavenArtifactId = sonar-community-branch-plugin
    communityBranchPlugin.1.23.0.changelogUrl = https://github.com/mc1arke/sonarqube-community-branch-plugin/releases
    communityBranchPlugin.1.23.0.date = 2024-12-31
    communityBranchPlugin.1.23.0.downloadUrl = https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/1.23.0/sonarqube-community-branch-plugin-1.23.0.jar
    communityBranchPlugin.1.23.0.requiredSonarVersions = 10.8,2025.1
    communityBranchPlugin.1.23.0.sqVersions = 10.8,2025.1
    communityBranchPlugin.1.23.0.sqcb=24.12,25.1,25.2
    communityBranchPlugin.1.23.0.sqs=10.8,10.8.1,2025.1
    communityBranchPlugin.1.23.0.description = This version supports Sonarqube 2025.1 and above. Sonarqube 9.9 and below are not supported in this release.
    communityBranchPlugin.1.23.0.mavenGroupId = com.github.mc1arke.sonarqube.plugin
    communityBranchPlugin.1.23.0.mavenArtifactId = sonar-community-branch-plugin
    ```
   > Several versions of the plugin can be stored for the respective SonarQube version.
   > For SonarQube <= 9.9, `*.sqVersions` must match `publicVersions` and the installed SonarQube version
   > For SonarQube > 2025.1, `*.sqcb` must match `sqbc` and `*.sqs` must match `sqs` and the installed SonarQube version

2. host the update center `.properties` file on a web server available without authentication
3. customize the Dogu-Config for SonarQube:
    * Update-Center-URL: `etcdctl set /config/sonar/sonar.updatecenter.url https://domain.de/update-center.properties`
    * Default plugins that are installed at startup: `etcdctl set sonar.plugins.default communityBranchPlugin`.
4. restart SonarQube


> When installing the “Community Branch Plugin” via the UpdateCenter for the first time, Sonar must be restarted so that the plugin is copied to the correct location as described above.

> If the web server does not have a valid HTTPS certificate, the Update Center cannot be used.
> In order for the certificate to be trusted, it must be stored in the Dogu:
> 1. the certificates must be in PEM format.
> 2. the certificates must be available in `etcd` below `/config/_global/certificate/additional/`
     > The key name (also called _Alias_) is used for addressing and internal dogu storage and should not contain any spaces.
> - The FQDN of the service would be useful here (e.g. `service.example.com`) so that a certificate can be removed more easily at a later date
> - A key can have more than one certificate for a service. Certificates in PEM format have textual markers that can be used to separate the certificates again.
> 3. the key name under which the certificate was stored must be stored in `etcd` under `/config/_global/certificate/additional/toc`.
     > Certificates of different services must be separated by a single space
> 4. restart Dogu
>
> Example:
> ```shell
> #  Create key name
> etcdctl set /config/_global/certificate/additional/toc 35.198.174.144
> # Create certificate from file
> cat ./test.crt | etcdctl set /config/_global/certificate/additional/35.198.174.144
> ```

### Testing the SonarQube Community Plugin

Prerequisite: SonarQube is set up as described [here](./developing_en.md/#test-sonarqube-dogu) <!-- markdown-link-check-disable-line -->

1. install the “Community Branch Plugin” as described above
2. in the SCM Manager: install the editor and review plugins
    - This makes it possible to edit source files without `git clone ... ; git commit ...`
3. edit spring-petclinic/ `master` branch
    - create a `sonar-project.properties` in the SCM Manager (if not already available)
        - see below for an example file
        - this ensures that SonarQube finds the built `.class` files
    - enrich the `Jenkinsfile` in the SCM Manager so that `stage("build")` and `stage("integration test")` are also available
        - see below for an example file
        - This ensures that SonarQube also scans PR branches and informs Jenkins about the status
4. in SonarQube: redeclare the main branch (only if necessary)
    1. navigate to [Projects](https://192.168.56.2/sonar/admin/projects_management) <!-- markdown-link-check-disable-line -->
    2. only necessary if a wrong branch has been scanned
    3. rename the project marked as `main` to the desired branch, e.g. `master`
    4. delete the remaining projects
5. test PR branch recognition
    1. create a new branch in the SCM Manager on a `master` basis
    2. minimally modify and commit any file (so a PR can be created)
    3. create PR from new branch on `master`
6. after PR creation, check SonarQube and Jenkins job for the scan result

**sonar-project.properties**

```properties
sonar.projectKey=spring-petclinic

sonar.sources=./src/main/java
sonar.tests=./src/test/java
sonar.java.binaries=./target/classes

sonar.junit.reportPaths=./target/surefire-reports
sonar.coverage.jacoco.xmlReportPaths=./target/site/jacoco/jacoco.xml
```

**Jenkinsfile**

> This is just a template!
> Please see the comments to make necessary changes

```groovy
#!groovy
@Library('github.com/cloudogu/ces-build-lib@2.2.1')
import com.cloudogu.ces.cesbuildlib.*

node {

    Git git = new Git(this, "admin")
    git.committerName = 'admin'
    git.committerEmail = 'admin@admin.de'
    projectName="spring-petclinic"
    branch = "${env.BRANCH_NAME}"
    Maven mvn = new MavenWrapper(this)

    String credentialsId = 'scmCredentials'

    catchError {
        // Add the usual Checkout, Build, Test, Integration Test stages here
        stage("...") {}
        
        stage('SonarQube') {
            def scannerHome = tool name: 'sonar-scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
            env.JAVA_HOME="${tool 'OpenJDK-11'}"
            withSonarQubeEnv {
                gitWithCredentials("fetch --all", credentialsId)

                if (branch == "master") {
                    echo "This branch has been detected as the master branch."
                    sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName}"
                } else if (branch == "develop") {
                    echo "This branch has been detected as the develop branch."
                    sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${env.BRANCH_NAME} -Dsonar.branch.target=master  "
                } else if (env.CHANGE_TARGET) {
                    echo "This branch has been detected as a pull request."
                    sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.pullrequest.key=${env.CHANGE_ID} -Dsonar.pullrequest.branch=${env.CHANGE_BRANCH} -Dsonar.pullrequest.base=develop    "
                } else {
                    echo "This branch has been detected as a feature branch."
                    sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${env.BRANCH_NAME} -Dsonar.branch.target=develop"
                } // add more to your liking
            }

            timeout(time: 60, unit: 'SECONDS') { // Works best with Webhooks, otherwise it needs a sleep which may not work for the async SQ scan
                def qGate = waitForQualityGate()
                if (qGate.status != 'OK') {
                    unstable("Pipeline unstable due to SonarQube quality gate failure")
                }
            }
        }
    }

    junit allowEmptyResults: true, testResults: '**/target/failsafe-reports/TEST-*.xml,**/target/surefire-reports/TEST-*.xml'
}

void gitWithCredentials(String command, String credentialsId) {
    withCredentials([usernamePassword(credentialsId: credentialsId, usernameVariable: 'GIT_AUTH_USR', passwordVariable: 'GIT_AUTH_PSW')]) {
        sh(
                script: "git -c credential.helper=\"!f() { echo username='\$GIT_AUTH_USR'; echo password='\$GIT_AUTH_PSW'; }; f\" " + command,
                returnStdout: true
        )
    }
}
```