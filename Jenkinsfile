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
        dependedDogus      : ['cas', 'usermgt', 'postgresql'],
        doBatsTests        : true,
        checkMarkdown      : true,
        runIntegrationTests: true,
        cypressImage       : 'cypress/included:13.14.2'

])
com.cloudogu.ces.dogubuildlib.EcoSystem ecoSystem = pipe.ecoSystem

pipe.setBuildProperties()
pipe.addDefaultStages()

pipe.overrideStage('Setup') {
    ecoSystem.loginBackend('cesmarvin-setup')
    ecoSystem.setup([])
    ecoSystem.setup([registryConfig:"""
            "sonar": {
                "sonar.web.sso.refreshIntervalInMinutes": "0"
            },
        """, additionalDependencies: ['official/postgresql']])
}

pipe.overrideStage("Integration tests") {
    com.cloudogu.ces.dogubuildlib.EcoSystem eco = pipe.ecoSystem
    eco.runCypressIntegrationTests([enableVideo      : params.EnableVideoRecording,
                                    enableScreenshots: params.EnableScreenshotRecording,
                                    cypressImage     : pipe.cypressImage])
}

pipe.insertStageAfter("Bats Tests", "Build sonarcarp") {
    def ctx = pipe.script
    new com.cloudogu.ces.cesbuildlib.Docker(ctx)
            .image("golang:${goVersion}")
            .mountJenkinsUser()
            .inside('-e ENVIRONMENT=ci') {
                ctx.sh 'cp -r build sonarcarp/ && cd sonarcarp && make vendor compile'
            }
}
pipe.insertStageAfter("Build sonarcarp", "Test sonarcarp") {
    def ctx = pipe.script
    new com.cloudogu.ces.cesbuildlib.Docker(ctx)
            .image("golang:${goVersion}")
            .mountJenkinsUser()
            .inside('-e ENVIRONMENT=ci') {
                ctx.sh 'cd sonarcarp && make unit-test'
            }
    ctx.junit allowEmptyResults: true, testResults: 'sonarcarp/target/unit-tests/*-tests.xml'
    ctx.archiveArtifacts "sonarcarp/target/unit-tests/*-tests.xml"
}

pipe.insertStageAfter("Test sonarcarp", "Static analysis", {
    def ctx = pipe.script
    ctx.runSonarQube(ctx)
})

pipe.run()


void runSonarQube(def script) {
    projectName = 'sonar'
    def scannerHome = script.tool name: 'sonar-scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
    script.withSonarQubeEnv {
        script.sh "git config 'remote.origin.fetch' '+refs/heads/*:refs/remotes/origin/*'"
        def branch = script.env.BRANCH_NAME
        script.withCredentials([usernamePassword(credentialsId: 'cesmarvin', usernameVariable: 'GIT_AUTH_USR', passwordVariable: 'GIT_AUTH_PSW')]) {
            script.sh (
                    script: "git -c credential.helper=\"!f() { echo username='\$GIT_AUTH_USR'; echo password='\$GIT_AUTH_PSW'; }; f\" fetch --all",
                    returnStdout: true
            )
        }

        if (branch == "master") {
            script.echo "This branch has been detected as the main branch."
            script.sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName}"
        } else if (branch == "develop") {
            script.echo "This branch has been detected as the develop branch."
            script.sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${branch} -Dsonar.branch.target=master  "
        } else if (env.CHANGE_TARGET) {
            script.echo "This branch has been detected as a pull request."
            script.sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.pullrequest.key=${env.CHANGE_ID} -Dsonar.pullrequest.branch=${env.CHANGE_BRANCH} -Dsonar.pullrequest.base=develop    "
        } else if (branch.startsWith("feature/")) {
            script.echo "This branch has been detected as a feature branch."
            script.sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${branch} -Dsonar.branch.target=develop"
        } else if (branch.startsWith("bugfix/")) {
            script.echo "This branch has been detected as a bugfix branch."
            script.sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${branch} -Dsonar.branch.target=develop"
        } else {
            script.echo "This branch has been detected as a miscellaneous branch."
            script.sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${branch} -Dsonar.branch.target=develop"
        }
    }
    timeout(time: 2, unit: 'MINUTES') { // Needed when there is no webhook for example
        def qGate = script.waitForQualityGate()
        if (qGate.status != 'OK') {
            script.unstable("Pipeline unstable due to SonarQube quality gate failure")
        }
    }
}
