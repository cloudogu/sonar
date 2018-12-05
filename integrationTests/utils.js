const config = require('./config');

require('chromedriver');
const webdriver = require('selenium-webdriver');
const chromeCapabilities = webdriver.Capabilities.chrome();
//setting chrome options to start the browser fully maximized
const chromeOptions = {
    'args': ['--test-type', '--start-maximized']
};
chromeCapabilities.set('chromeOptions', chromeOptions);
chromeCapabilities.set('name', "Sonar ITs");
// set filename pattern for zalenium videos
chromeCapabilities.set("testFileNameTemplate", "{testName}_{testStatus}");

const By = webdriver.By;
const until = webdriver.until;

let driver = null;
const zaleniumReporter = {
    specStarted: function(test) {
        // set testname for zalenium
        chromeCapabilities.set("name", test.fullName);
    },
    // does not work on jasmine 2, we have to wait until jest updates jasmine to v3
    // set status to success or failed, currently all tests have status completed
    xspecDone: function(result, done) {
        driver.manage().addCookie({
            name: "zaleniumTestPassed", 
            value: result.status === "passed"
        });
        driver.quit().then(done);
    }
};
jasmine.getEnv().addReporter(zaleniumReporter);

exports.createDriver = function(){
    if (config.webdriverType === 'local') {
        driver = createLocalDriver();
    } else {
        driver = createRemoteDriver();
    }
    
    return driver;
};

function createLocalDriver() {
    return new webdriver.Builder().forBrowser('chrome').withCapabilities(chromeCapabilities)
        .usingServer('http://localhost:4444/wd/hub')
        .build();
}

function createRemoteDriver() {
    return new webdriver.Builder().forBrowser('chrome').withCapabilities(chromeCapabilities)
    .build();
}

exports.getCasUrl = async function getCasUrl(driver){
    await driver.get(config.baseUrl + config.sonarContextPath);
	return driver.getCurrentUrl()
};

exports.login = async function login(driver) {
    await driver.wait(until.elementLocated(By.id('password')), 5000);
	await driver.wait(until.elementLocated(By.id('username')), 5000);

    await driver.findElement(By.id('username')).sendKeys(config.username);
    await driver.findElement(By.id('password')).sendKeys(config.password);
	return driver.findElement(By.css('input[name="submit"]')).click();
};

exports.isAdministrator = async function isAdministrator(driver){
    await driver.wait(until.elementLocated(By.className('dropdown')), 5000);
    await driver.sleep(200);

	return await driver.findElement(By.className('navbar-admin-link')).then(function() {
		return true;//element was found
    }, function(err) {
        if (err instanceof webdriver.error.NoSuchElementError) {
            return false;//element did not exist
        } else {
            webdriver.promise.rejected(err);
        }
    });
};