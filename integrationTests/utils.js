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
    await driver.get(config.baseUrl + config.sonarContextPath);
	return driver.getCurrentUrl()
};

exports.gettestUserUrl = async function gettestUserUrl(driver,testuserName){
	
	await driver.get(config.baseUrl + "/usermgt/#/user/"+testuserName);
	return driver.getCurrentUrl();
};

exports.login = async function login(driver) {
    await driver.wait(until.elementLocated(By.id('password')), 5000);
	await driver.wait(until.elementLocated(By.id('username')), 5000);

    await driver.findElement(By.id('username')).sendKeys(config.username);
    await driver.findElement(By.id('password')).sendKeys(config.password);
	return driver.findElement(By.css('input[name="submit"]')).click();
};

exports.isAdministrator = async function isAdministrator(driver){
	await driver.wait(until.elementLocated(By.className("column-third")),5000);
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

exports.isUser = async function isUser(response){
	const usersObject = JSON.parse(response["request"]["req"]["res"]["text"]);	// Parsing text field from "response" object to JS object
	const userObject = usersObject['users'];									// Getting object of all users
	const userObjectLength = Object.keys(userObject).length;					// Getting number of users object present
	for (var i=0; i<userObjectLength; i++){
		if (userObject[i].login == config.username && userObject[i].email == config.email && userObject[i].name == config.displayName && userObject[i].active == true 
		&& userObject[i].externalIdentity == config.username && userObject[i].externalProvider == 'sonarqube'){		// Looping through all users to get match with the login username
			return true;
		}
	}
	return false;
};

exports.isUserAdmin = async function isUserAdmin(response){
	const usersObject = JSON.parse(response["request"]["req"]["res"]["text"]);   // Parsing text field from "response" object to JS object
	const userObject = usersObject['users'];                     // Getting object of all users
	const userObjectLength = Object.keys(userObject).length;	// Getting number of users object present
	for (var i=0; i<userObjectLength; i++){                       // Looping through all users to get match with the login username.
		//if (userObject[i].login == config.displayName){
		if (userObject[i].login == config.username && userObject[i].email == config.email && userObject[i].name == config.displayName && userObject[i].active == true 
		&& userObject[i].externalIdentity == config.username && userObject[i].externalProvider == 'sonarqube'){
			const groupsLength = Object.keys(userObject[i].groups).length;    // Getting number of groups the matched user has
			if (groupsLength == 0){
				if (userObject[i].groups == config.adminGroup){			//If only one group, then check in one shot
					return true;
				} else{
					return false;
				}
			} else{
				const userGroups = userObject[i].groups;
				for (var j=0; j<groupsLength; j++){						// If more than one groups, then we need to loop through each group name to find match.
					if (userGroups[j] == config.adminGroup){
						return true;
					}
				}
				return false;
			}
		}
	}
	return false;
};