#!groovy
@Library([
        'pipe-build-lib',
        'ces-build-lib',
        'dogu-build-lib'
]) _

def goVersion = "1.24.5-bullseye"
def pipe = new com.cloudogu.sos.pipebuildlib.DoguPipe(this, [
        doguName           : 'sonar',
        shellScripts       : ['''
                            resources/post-upgrade.sh
                            resources/pre-upgrade.sh
                            resources/startup.sh
                            resources/upgrade-notification.sh
                            resources/util.sh
                          '''],
        dependedDogus       : ['cas', 'usermgt', 'postgresql'],
        doBatsTests         : true,
        checkMarkdown       : true,
        runIntegrationTests : true,
        cypressImage        : 'cypress/included:13.14.2'

])
com.cloudogu.ces.dogubuildlib.EcoSystem ecoSystem = pipe.ecoSystem

pipe.setBuildProperties()
pipe.addDefaultStages()
pipe.insertStageAfter("Checkout", "Build sonarcarp", {
    script.withGolangContainer("cp -r build Makefile sonarcarp/ && cd sonarcarp && make vendor compile")
})
pipe.insertStageAfter("Checkout", "Test sonarcarp", {
    script.withGolangContainer("cd sonarcarp && make unit-test")
})
pipe.insertStageAfter("Test sonarcarp", "Static analysis", {
    script.runSonarQube(script.sh)
})
pipe.overrideStage('Setup') {
    ecoSystem.loginBackend('cesmarvin-setup')
    ecoSystem.setup([ additionalDependencies: [ 'official/postgresql' ] ])
}
pipe.run()

void withGolangContainer(Closure closure) {
    new Docker(this)
            .image("golang:${goVersion}")
            .mountJenkinsUser()
            .inside("-e ENVIRONMENT=ci") { closure.call() }
}

void runSonarQube(def sh) {
    stage('SonarQube') {
        projectName = 'grafana-carp'
        def scannerHome = tool name: 'sonar-scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
        withSonarQubeEnv {
            sh "git config 'remote.origin.fetch' '+refs/heads/*:refs/remotes/origin/*'"
            branch = env.BRANCH_NAME
            gitWithCredentials("fetch --all")

            if (branch == "main") {
                echo "This branch has been detected as the main branch."
                sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName}"
            } else if (branch == "develop") {
                echo "This branch has been detected as the develop branch."
                sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${branch} -Dsonar.branch.target=main  "
            } else if (env.CHANGE_TARGET) {
                echo "This branch has been detected as a pull request."
                sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.pullrequest.key=${env.CHANGE_ID} -Dsonar.pullrequest.branch=${env.CHANGE_BRANCH} -Dsonar.pullrequest.base=develop    "
            } else if (branch.startsWith("feature/")) {
                echo "This branch has been detected as a feature branch."
                sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${branch} -Dsonar.branch.target=develop"
            } else if (branch.startsWith("bugfix/")) {
                echo "This branch has been detected as a bugfix branch."
                sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${branch} -Dsonar.branch.target=develop"
            } else {
                echo "This branch has been detected as a miscellaneous branch."
                sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${branch} -Dsonar.branch.target=develop"
            }
        }
        timeout(time: 2, unit: 'MINUTES') { // Needed when there is no webhook for example
            def qGate = waitForQualityGate()
            if (qGate.status != 'OK') {
                unstable("Pipeline unstable due to SonarQube quality gate failure")
            }
        }
    }
}
