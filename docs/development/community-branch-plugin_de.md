# SonarQube Community Branch Plugin
Das [SonarQube Community Branch Plugin](https://github.com/mc1arke/sonarqube-community-branch-plugin) ist ein Plugin für SonarQube, um die Branch-Analyse in der SonarQube Community-Version zu ermöglichen.

Das Plugin muss immer in der passenden Version zur SonarQube-Version installiert sein. 
Siehe: [SonarQube version appropriate community plugin](https://github.com/mc1arke/sonarqube-community-branch-plugin?tab=readme-ov-file#compatibility)

Bei Start des Dogus, wird geprüft, ob die JAR-Datei des "Community Branch Plugin" in `/opt/sonar/extensions/downloads` oder `/opt/sonar/extensions/plugins` existiert und dann zusätzlich nach `/opt/sonar/lib/common` kopiert.
Dies ist nötig, damit das Plugin richtig ausgeführt werden kann und das Dogu startet.

## Installation

### Manuelle Installation über das Volume
1. Als CES-Shell-Administrator: das [SonarQube version appropriate community plugin](https://github.com/mc1arke/sonarqube-community-branch-plugin?tab=readme-ov-file#compatibility) als JAR herunterladen 
2. Die heruntergeladene JAR-Datei nach `/var/lib/ces/sonar/volumes/extensions/plugins/` verschieben
3. SonarQube neustarten

### Installation über das Updatecenter
Das "Community Branch Plugin" kann auch über das Updatecenter installiert werden.

1. Eine Update-Center `.properties`-Datei erstellen und dort die benötigte Version des "Community Branch Plugin" eintragen.
   Beispiel:
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
   > Es können mehrere Versionen des Plugins für die jeweilige SonarQube-Version hinterlegt werden. 
   > Für SonarQube <= 9.9 muss `*.sqVersions` mit `publicVersions` und der installierten SonarQube-Version übereinstimmen
   > Für SonarQube > 2025.1 muss `*.sqcb` mit `sqbc` und `*.sqs` mit `sqs` und der installierten SonarQube-Version übereinstimmen

2. Die Update-Center `.properties`-Datei auf einem ohne Authentifizierung verfügbaren Web-Server hosten
3. Die Dogu-Config für SonarQube anpassen:
    * Update-Center-URL: `etcdctl set /config/sonar/sonar.updatecenter.url https://domain.de/update-center.properties`
    * Default-Plugins, die beim Start installiert werden: `etcdctl set sonar.plugins.default communityBranchPlugin`
4. SonarQube neustarten

> Bei der ersten Installation des "Community Branch Plugin" über das UpdateCenter, muss Sonar nocheinmal neugestarte werden, damit das Plugin, wie oben beschrieben, an die richtige Stelle kopiert wird.

> Wenn der Web-Server nicht über ein gültiges HTTPS-Zertifikat verfügt, kann das Update-Center nicht verwendet werden.
> Damit dem Zertifikat verttraut werden kann, muss es im Dogu zu hinterlegt werden:
> 1. Die Zertifikate müssen im PEM-Format vorliegen.
> 2. Die Zertifikate müssen im `etcd` unterhalb von `/config/_global/certificate/additional/` vorliegen
>   - Der Schlüsselname (auch _Alias_ genannt) dient der Adressierung und dogu-internen Ablage und sollte keine Leerzeichen enthalten.
>   - Sinnvoll wäre hier die FQDN des Dienstes (etwa: `dienst.example.com`), damit später ein Zertifikat leichter wieder entfernt werden kann
>   - Ein Schlüssel kann mehr als ein Zertifikat zu einem Dienst besitzen. Zertifikate im PEM-Format haben textuelle Markierungen, anhand dessen die Zertifikate wieder auseinander getrennt werden können.
> 3. Der Schlüsselname, unter dem das Zertifikat abgelegt wurde, muss im `etcd` unter `/config/_global/certificate/additional/toc` abgelegt werden.
>   - Zertifikate unterschiedlicher Dienste müssen mit einem einzelnen Leerzeichen getrennt werden
> 4. Dogu neustarten
> 
> Beispiel
> ```shell
> # Schlüsselname anlegen
> etcdctl set /config/_global/certificate/additional/toc 35.198.174.144
> # Zertifikat aus Datei anlegen
> cat ./test.crt | etcdctl set /config/_global/certificate/additional/35.198.174.144
> ```

### Testen des SonarQube Community Plugin

Voraussetzung: SonarQube ist wie [hier](./developing_de.md/#sonarqube-dogu-testen) beschrieben eingerichtet <!-- markdown-link-check-disable-line -->

1. Das "Community Branch Plugin" wie oben beschrieben installieren
2. Im SCM-Manager: die Editor - und Review-Plugins installieren
    - damit ist die Bearbeitung von Quelldateien auch ohne `git clone ... ; git commit ...` möglich
3. spring-petclinic/ `master`-Branch bearbeiten
    - im SCM-Manager eine `sonar-project.properties` anlegen (sofern noch nicht vorhanden)
        - Beispiel siehe unten
        - dies sorgt dafür, dass SonarQube die gebauten `.class`-Files findet
    - im SCM-Manager das `Jenkinsfile` anreichern, dass `stage("build")` und `stage("integration test")` zusätzlich vorhanden sind
        - Beispiel siehe unten
        - dies sort dafür, dass SonarQube auch PR-Branches scannt und Jenkins über den Status informiert
4. In SonarQube den Main-Branch umdeklarieren (nur wenn nötig)
    1. zu [Projekte](https://192.168.56.2/sonar/admin/projects_management)  navigieren <!-- markdown-link-check-disable-line -->
    2. nur bei einem erfolgten Scan eines falschen Branches nötig
    3. Als `main` markiertes Projekt in den gewünschten Branch umbenennen, z. B. `master`
    4. die übrigen Projekte löschen
5. PR-Branch-Erkennung testen
    1. im SCM-Manager einen neuen Branch auf `master`-Basis anlegen
    2. eine beliebige Datei minimal ändern und commiten (um PR zu ermöglichen)
    3. PR von neuem Branch auf `master` anlegen
6. Nach PR-Anlage SonarQube und Jenkins-Job auf Scan-Ergebnis prüfen

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

> Dies ist nur eine Vorlage!
> Siehe Kommentare, um nötige Anpassungen vorzunehmen

```groovy
#!groovy
@Library('github.com/cloudogu/ces-build-lib@4.0.1')
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
        // usual stages go here: Checkout, Build, Test, Integration Test
        stage("...") {}
        
        stage('SonarQube') {
            def scannerHome = tool name: 'sonar-scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
            env.JAVA_HOME="${tool 'OpenJDK-17'}"
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