const config = require('./config');

require('chromedriver');
const webdriver = require('selenium-webdriver');
var chromeCapabilities = webdriver.Capabilities.chrome();
//setting chrome options to start the browser fully maximized
var chromeOptions = {
    'args': ['--test-type', '--start-maximized']
};
chromeCapabilities.set('chromeOptions', chromeOptions);
const By = webdriver.By;
const until = webdriver.until;

exports.createDriver = function(){
    if (config.webdriverType === 'local') {
		var driver = new webdriver.Builder().forBrowser('chrome').withCapabilities(chromeCapabilities).build();
		return driver;
		//return createLocalDriver();
    }
    return createRemoteDriver();
};

function createRemoteDriver() {
    return new webdriver.Builder()
    .build();
}

function createLocalDriver() {
  return new webdriver.Builder()
    .withCapabilities(webdriver.Capabilities.chrome())
    .build();
}

exports.getCasUrl = async function getCasUrl(driver){
    await driver.get(config.baseUrl + config.jenkinsContextPath);
	return driver.getCurrentUrl()
};

exports.gettestUserUrl = async function gettestUserUrl(driver,userName){
	if (userName == 'testUser'){
		await driver.get(config.baseUrl + "/usermgt/#/user/"+userName);
		return driver.getCurrentUrl();
	}else if (userName == 'testUser1234'){
		await driver.get(config.baseUrl + "/usermgt/#/user/"+userName);
		return driver.getCurrentUrl();
	}
};

exports.gettestUsersUrl = async function gettestUsersUrl(driver){
    await driver.get(config.baseUrl + "/usermgt/#/users");
	return driver.getCurrentUrl()
};

exports.maketestUserUrl = async function maketestUserUrl(driver){
    await driver.get(config.baseUrl + "/usermgt/#/user/");
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
	await driver.wait(until.elementLocated(By.css("#content > div > div > div > div:nth-child(3) > section:nth-child(1) > h2")),5000);
	return await driver.findElement(By.css("#groups > li")).getText().then(function() {
		return true;//element was found
    }, function(err) {
        if (err instanceof webdriver.error.NoSuchElementError) {
            return false;//element did not exist
        } else {
            webdriver.promise.rejected(err);
        }
    });
};