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
            .get(config.sonarContextPath + "/api/users/search/json")
            .auth(config.username, config.password)
            .expect(200);
    });

    /*login -> click on username -> configure -> show api token*/
    test('authentication with API key', async () => {
		//Create user Token
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/security");
		await driver.sleep(250);
        await driver.wait(until.elementLocated(By.className("js-generate-token-form")), 5000);
		await driver.findElement(By.css("#content > div > div > div > div > div > form > input[type='text']")).sendKeys(config.sonarqubeToken);
		await driver.findElement(By.css("#content > div > div > div > div > div > form > button")).click(); //Click to create Token
		await driver.sleep(200);
		const apikey = await driver.findElement(By.className("monospaced text-success")).getText(); //Saving Token
		//Checking login with Token
        await request(config.baseUrl)
			.get(config.sonarContextPath + "/api/users/search/json")
            .auth(apikey)
            .expect(200);
		//Deleting user Token
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/security");
		await driver.sleep(200);
		await driver.findElement(By.className("js-revoke-token-form")).click(); // Click to delete
		await driver.findElement(By.className("js-revoke-token-form")).click(); // Click to confirm deletion
    });


});

describe('rest attributes', () => {

    test('rest - user attributes', async () => {
		
		const response = await request(config.baseUrl)
            .get(config.sonarContextPath + "/api/users/search/json")
            .auth(config.username, config.password)
            .expect('Content-Type', /json/)
            .expect(200);
		
		const result = await utils.isUser(response);
		expect(result).toBe(true);
        
    });

    test('rest - user is administrator', async () => {
			
		const response = await request(config.baseUrl)
            .get(config.sonarContextPath + "/api/users/search/json")
            .auth(config.username, config.password)
            .expect('Content-Type', /json/)
            .expect(200);
			
		const result = await utils.isUserAdmin(response);
		expect(result).toBe(true);
    });
});