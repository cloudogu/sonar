const config = require('./config');
const utils = require('./utils');
const request = require('supertest');

require('chromedriver');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;
jest.setTimeout(30000);

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';


let driver;

beforeEach(() => {
    driver = utils.createDriver(webdriver);
});

afterEach(() => {
    driver.quit();
});


describe('cas rest basic authentication', () => {

    test('authentication with username password', async () => {
        await request(config.baseUrl)
            //.get(config.jenkinsContextPath + "/api/webservices/list")
			//.get(config.jenkinsContextPath + "/account/api/json")
			.get(config.jenkinsContextPath + "/api/user_tokens/search")
            .auth(config.username, config.password)
            .expect(200);
    });

    /*login -> click on username -> configure -> show api token*/
    test('authentication with API key', async () => {
		//Create user Token
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
		await driver.sleep(2000);
        await driver.get(config.baseUrl + config.jenkinsContextPath + "/account/security");
		await driver.sleep(3000);
        await driver.wait(until.elementLocated(By.className("js-generate-token-form")), 5000);
		await driver.findElement(By.css("#content > div > div > div > div > div > form > input[type='text']")).sendKeys(config.testToken);
		await driver.sleep(2000);
		await driver.findElement(By.css("#content > div > div > div > div > div > form > button")).click(); //Click to create Token
		await driver.sleep(2000);
		const apikey = await driver.findElement(By.css("#content > div > div > div > div > div > div.panel.panel-white.big-spacer-top > table > tbody > tr > td.nowrap > div")).getText(); //Saving Token
		//Checking login with Token
        await request(config.baseUrl)
            //.get(config.jenkinsContextPath+"/api/webservices/list")
			//.get(config.jenkinsContextPath + "/account/api/json")
			.get(config.jenkinsContextPath + "/api/user_tokens/search")
            .auth(apikey)
            .expect(200);
		//Deleting user Token
		await driver.get(config.baseUrl + config.jenkinsContextPath + "/account/security");
		await driver.sleep(3000);
		await driver.findElement(By.css("#content > div > div > div > div > div > table > tbody > tr > td:nth-child(3) > div > form > button")).click(); // Click to delete
		await driver.sleep(1000);
		await driver.findElement(By.css("#content > div > div > div > div > div > table > tbody > tr > td:nth-child(3) > div > form > button")).click(); // Click to confirm deletion
    });


});


describe('rest attributes', () => {

    test('rest - user attributes', async () => {
        const response = await request(config.baseUrl)
            //.get(config.jenkinsContextPath + "/api/webservices/list")
			//.get(config.jenkinsContextPath + "/api/user_tokens/search")
			.get(config.jenkinsContextPath + "/account/api/json")
			.auth(config.username, config.password)
			.expect('Content-Type', "text/html;charset=utf-8")
            .expect(200);
		
		var templateName = 'amukherjee';
		var l1 = templateName.length;
		var l2 = config.username.length;
		var indexstart = 470;
		var indexend = 478;
		//Getting text embedded as HTML in webpage api
		var testObj = response["request"]["req"]["res"]["text"];
		testObj = testObj.replace(/\s/g,'');
		indexstart = indexstart-(l1-l2);
		indexend = indexend-(l1-l2);
		var userName = testObj.substring(indexstart,indexend);
		var extractName = testObj.substring(indexstart+10,indexend+2+l2);
		expect(userName).toBe('userName');
		expect(extractName).toBe(config.username);
    });

    test('rest - user is administrator', async () => {
			
		const response = await request(config.baseUrl)
            //.get(config.jenkinsContextPath + "/api/webservices/list")
			//.get(config.jenkinsContextPath + "/api/user_tokens/search")
			.get(config.jenkinsContextPath + "/account/api/json")
			.auth(config.username, config.password)
			
			.expect('Content-Type', "text/html;charset=utf-8")
            .expect(200);
		
		var templateName = 'amukherjee';
		var templateEmail = 'ces-admin@cloudogu.com';
		var l1 = templateName.length;
		var l2 = config.username.length;
		var l3 = templateEmail.length;
		var l4 = config.email.length;
		var indexstart = 2430;
		var indexend = 2451;
		//Getting text embedded as HTML in webpage api
		var testObj = response["request"]["req"]["res"]["text"];
		testObj = testObj.replace(/\s/g,'');
		indexstart = (indexstart-((l1-l2)*2))-(l3-l4);
		indexend = (indexend-((l1-l2)*2))-(l3-l4);
		// Search for "is Administrator" true condition
		var adminField = testObj.substring(indexstart,indexend);
		var isTrue = testObj.substring(indexstart+22,indexend+5);
		expect(adminField).toBe('window.SS.isUserAdmin');
		expect(isTrue).toBe('true');
    });
});