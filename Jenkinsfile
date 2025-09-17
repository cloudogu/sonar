#!groovy
<<<<<<< HEAD
@Library(['github.com/cloudogu/ces-build-lib@4.2.0', 'github.com/cloudogu/dogu-build-lib@v3.2.0'])
import com.cloudogu.ces.cesbuildlib.*
import com.cloudogu.ces.dogubuildlib.*
=======
@Library([
  'pipe-build-lib',
  'ces-build-lib',
  'dogu-build-lib'
]) _
>>>>>>> 17a09ceaa6d9df499441188fe8591eac2ca8be8a

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
pipe.overrideStage('Setup') {
    ecoSystem.loginBackend('cesmarvin-setup')
    ecoSystem.setup([ additionalDependencies: [ 'official/postgresql' ] ])
}
pipe.run()

