const config = require('./config');
const utils = require('./utils');
const request = require('supertest');
const expectations = require('./expectations');

require('chromedriver');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;
jest.setTimeout(60000);

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

let driver;

describe('cas rest basic authentication', () => {

    test('authentication with username password', async () => {
        await request(config.baseUrl)
            .get(config.sonarContextPath + "/api/users/search")
            .auth(config.username, config.password)
            .expect(200);
    });

    let test1 = test('authentication with API key', async () => {
        driver = utils.createDriver(webdriver);
		// Login and go to user tokens page
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/security");
        await driver.wait(until.elementLocated(By.className("display-flex-center")), 5000);
        // Create user Token
        await driver.findElement(By.css("input[type='text']")).sendKeys(config.sonarqubeToken);
        await driver.findElement(By.xpath("//button[contains(text(),'Generate')]")).click(); //Click to create Token
        // Get token id
        await driver.wait(until.elementLocated(By.className("big-spacer-left text-success")), 5000);
        const apikey = await driver.findElement(By.className("big-spacer-left text-success")).getText(); //Saving Token
		//Checking login with Token
        await request(config.baseUrl)
			.get(config.sonarContextPath + "/api/system/health")
            .auth(apikey)
            .expect(200);
		//Deleting user Token
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/security");
        await driver.wait(until.elementLocated(By.className("display-flex-center")), 5000);
        await driver.findElement(By.className("button spacer-left button-red input-small")).click(); // Click to delete
        // Wait until modal is open
        await driver.sleep(500);
        await driver.findElement(By.xpath("/html/body/div[4]/div/div/form/footer/button[1]")).click(); // Click to confirm deletion

        await driver.quit();
    });

    test('rest - check user attributes', async () => {
        const response = await request(config.baseUrl)
            .get(config.sonarContextPath + "/api/users/search")
            .auth(config.username, config.password)
            .expect('Content-Type', 'application/json')
            .type('json')
            .send({'q': config.username})
            .expect(200);

        const userObject = JSON.parse(response["request"]["req"]["res"]["text"]).users[1];
        expectations.expectStateUser(userObject);
    });

    test('rest - user is administrator', async () => {
        const response = await request(config.baseUrl)
            .get(config.sonarContextPath + "/api/users/search")
            .auth(config.username, config.password)
            .expect('Content-Type', 'application/json')
            .type('json')
            .send({'q': config.username})
            .expect(200);
        const userObject = JSON.parse(response["request"]["req"]["res"]["text"]).users[1];
        expectations.expectStateAdmin(userObject);
    });

});
