#!groovy
@Library([
        'pipe-build-lib',
        'ces-build-lib',
        'dogu-build-lib'
]) _

def goVersion = "1.26.0-bookworm"
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
        additionalDogus    : ['official/postgresql'],
        doBatsTests        : true,
        doSonarTests       : true,
        checkMarkdown      : true,
        runIntegrationTests: true,
        cypressImage       : 'cypress/included:13.14.2',
        defaultBranch      : "master"
])
com.cloudogu.ces.dogubuildlib.EcoSystem ecoSystem = pipe.ecoSystem

pipe.setBuildProperties()
pipe.addDefaultStages()

pipe.overrideStage('Setup') {
    ecoSystem.loginBackend('cesmarvin-setup')
    // set refreshIntervalInMinutes to 0 to have integration tests running properly, esp. privilege modification tests.
    ecoSystem.setup([registryConfig:"""
    	"sonar": {
        	"sonar.web.sso.refreshIntervalInMinutes": "0",
        	"remove_product_news": "true"
        }
    """, additionalDependencies: ['official/postgresql']])
}


String sonarConfigOverride = """
{
  "sonar.web.sso.refreshIntervalInMinutes": "0",
  "remove_product_news": "true",
}
"""
}

def mergeConfigMapYaml = { String configMapName, String overrideConfig ->
    sh """
       kubectl get configmap ${configMapName} -n ecosystem -o yaml | .bin/yq '
         .data."config.yaml" |= (
           (from_yaml) * ${overrideConfig}
           | to_yaml
         )
       ' | tee ${configMapName}-output.yml | kubectl apply -f -
       """
}

com.cloudogu.ces.dogubuildlib.MultiNodeEcoSystem multiNodeEcoSystem = pipe.multiNodeEcoSystem

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

pipe.insertStageBefore("MN-Run Integration Tests", "Setup Configs") {
   pipe.multiNodeEcoSystem.waitForDogu("sonar")
   mergeConfigMapYaml('sonar-config', sonarConfigOverride)
   pipe.multiNodeEcoSystem.waitForDogu("sonar")
}

pipe.run()