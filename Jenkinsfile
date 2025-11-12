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
        doSonarTests       : true,
        checkMarkdown      : true,
        runIntegrationTests: true,
        cypressImage       : 'cypress/included:13.14.2'

])
com.cloudogu.ces.dogubuildlib.EcoSystem ecoSystem = pipe.ecoSystem

pipe.setBuildProperties()
pipe.addDefaultStages()

pipe.overrideStage('Setup') {
    ecoSystem.loginBackend('cesmarvin-setup')
    // set refreshIntervalInMinutes to 0 to have integration tests running properly, esp. privilege modification tests.
    ecoSystem.setup([registryConfig:"""
    	"sonar": {
        	"sonar.web.sso.refreshIntervalInMinutes": "0"
        }
    """, additionalDependencies: ['official/postgresql']])
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

pipe.run()