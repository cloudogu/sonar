#!groovy
@Library(['github.com/cloudogu/ces-build-lib@1.65.0', 'github.com/cloudogu/dogu-build-lib@v2.1.0'])
import com.cloudogu.ces.cesbuildlib.*
import com.cloudogu.ces.dogubuildlib.*

node('vagrant') {

    String doguName = "sonar"
    Git git = new Git(this, "cesmarvin")
    git.committerName = 'cesmarvin'
    git.committerEmail = 'cesmarvin@cloudogu.com'
    GitFlow gitflow = new GitFlow(this, git)
    GitHub github = new GitHub(this, git)
    Changelog changelog = new Changelog(this)
    Markdown markdown = new Markdown(this, "3.11.0")

    timestamps{
        properties([
                // Keep only the last x builds to preserve space
                buildDiscarder(logRotator(numToKeepStr: '10')),
                // Don't run concurrent builds for a branch, because they use the same workspace directory
                disableConcurrentBuilds(),
                // Parameter to activate dogu upgrade test on demand
                parameters([
                        booleanParam(defaultValue: false, description: 'Test dogu upgrade from latest release or optionally from defined version below', name: 'TestDoguUpgrade'),
                        string(defaultValue: '', description: 'Old Dogu version for the upgrade test (optional; e.g. 2.222.1-1)', name: 'OldDoguVersionForUpgradeTest'),
                        booleanParam(defaultValue: false, description: 'Enables the video recording during the test execution', name: 'EnableVideoRecording'),
                        choice(name: 'TrivyScanLevels', choices: [TrivyScanLevel.CRITICAL, TrivyScanLevel.HIGH, TrivyScanLevel.MEDIUM, TrivyScanLevel.ALL], description: 'The levels to scan with trivy'),
                        choice(name: 'TrivyStrategy', choices: [TrivyScanStrategy.UNSTABLE, TrivyScanStrategy.FAIL, TrivyScanStrategy.IGNORE], description: 'Define whether the build should be unstable, fail or whether the error should be ignored if any vulnerability was found.'),
                ])
        ])

        EcoSystem ecoSystem = new EcoSystem(this, "gcloud-ces-operations-internal-packer", "jenkins-gcloud-ces-operations-internal")
        Trivy trivy = new Trivy(this, ecoSystem)

        stage('Checkout') {
            checkout scm
        }

        stage('Lint') {
            lintDockerfile()
            // TODO: Change this to shellCheck("./resources") as soon as https://github.com/cloudogu/dogu-build-lib/issues/8 is solved
            shellCheck("./resources/post-upgrade.sh ./resources/pre-upgrade.sh ./resources/startup.sh ./resources/upgrade-notification.sh ./resources/util.sh")
        }

        stage('Check Markdown Links') {
            markdown.check()
        }

        try {

            stage('Provision') {
                ecoSystem.provision("/dogu")
            }

            stage('Setup') {
                ecoSystem.loginBackend('cesmarvin-setup')
                ecoSystem.setup([ additionalDependencies: [ 'official/postgresql' ] ])

            }

            stage('Wait for dependencies') {
                timeout(15) {
                    ecoSystem.waitForDogu("cas")
                    ecoSystem.waitForDogu("usermgt")
                    ecoSystem.waitForDogu("postgresql")
                }
            }

            stage('Build') {
                ecoSystem.build("/dogu")
            }

            stage('Trivy scan') {
                trivy.scanDogu("/dogu", TrivyScanFormat.HTML, params.TrivyScanLevels, params.TrivyStrategy)
                trivy.scanDogu("/dogu", TrivyScanFormat.JSON,  params.TrivyScanLevels, params.TrivyStrategy)
                trivy.scanDogu("/dogu", TrivyScanFormat.PLAIN, params.TrivyScanLevels, params.TrivyStrategy)
            }

            stage('Verify') {
                ecoSystem.verify("/dogu")
            }

            stage('Integration Tests') {
                ecoSystem.runCypressIntegrationTests([
                    cypressImage:"cypress/included:12.17.0",
                    enableVideo: params.EnableVideoRecording,
                    enableScreenshots: params.EnableScreenshotRecording
                ])
            }

            if (params.TestDoguUpgrade != null && params.TestDoguUpgrade){
                stage('Upgrade dogu') {
                    // Remove new dogu that has been built and tested above
                    ecoSystem.purgeDogu(doguName)

                    if (params.OldDoguVersionForUpgradeTest != '' && !params.OldDoguVersionForUpgradeTest.contains('v')){
                        println "Installing user defined version of dogu: " + params.OldDoguVersionForUpgradeTest
                        ecoSystem.installDogu("official/" + doguName + " " + params.OldDoguVersionForUpgradeTest)
                    } else {
                        println "Installing latest released version of dogu..."
                        ecoSystem.installDogu("official/" + doguName)
                    }
                    ecoSystem.startDogu(doguName)
                    ecoSystem.waitForDogu(doguName)
                    ecoSystem.upgradeDogu(ecoSystem)

                    // Wait for upgraded dogu to get healthy
                    ecoSystem.waitForDogu(doguName)
                    ecoSystem.waitUntilAvailable(doguName)
                }

                stage('Integration Tests - After Upgrade') {
                    // Run integration tests again to verify that the upgrade was successful
                    ecoSystem.runCypressIntegrationTests([
                        cypressImage:"cypress/included:12.17.0",
                        enableVideo: params.EnableVideoRecording,
                        enableScreenshots: params.EnableScreenshotRecording
                ])
                }
            }


            if (gitflow.isReleaseBranch()) {
                String releaseVersion = git.getSimpleBranchName()

                stage('Finish Release') {
                    gitflow.finishRelease(releaseVersion)
                }

                stage('Push Dogu to registry') {
                    ecoSystem.push("/dogu")
                }

                stage ('Add Github-Release'){
                    github.createReleaseWithChangelog(releaseVersion, changelog)
                }
            }
        } finally {
            stage('Clean') {
                ecoSystem.destroy()
            }
        }
    }
}
