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
