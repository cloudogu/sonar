const config = require('./config');
const utils = require('./utils');
const expectations = require('./expectations');
const AdminFunctions = require('./adminFunctions');
const userName = 'testUser';

require('chromedriver');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;

jest.setTimeout(30000);

let driver;
let adminFunctions;

beforeEach(async () => {
    driver = utils.createDriver(webdriver);
    adminFunctions = await new AdminFunctions(userName, userName, userName, userName+'@test.de', 'testuserpassword');
    await driver.manage().window().maximize();
});

afterEach(async () => {
    await driver.quit();
});


describe('cas browser login', () => {
	
    test('automatic redirect to cas login', async () => {
        await driver.get(config.baseUrl + config.sonarContextPath);
        const url = await driver.getCurrentUrl();
        expectations.expectCasLogin(url);
    });

    test('cas authentication', async() => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        await adminFunctions.showUserMenu(driver)
        const username = await driver.findElement(By.className("text-ellipsis text-muted")).getText();
        expect(username).toContain(config.displayName);
    });
	
	test('logout front channel', async() => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        await adminFunctions.testUserLogout(driver)
        await driver.sleep(1000)
		const url = await driver.getCurrentUrl();
        expectations.expectCasLogout(url);
    });
	
    test('logout back channel', async() => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        await driver.get(config.baseUrl + '/cas/logout');
        await driver.get(config.baseUrl + config.sonarContextPath);
		const url = await driver.getCurrentUrl();
        expectations.expectCasLogin(url);
    });

});

describe('browser attributes', () => {

    test('front channel user attributes', async () => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/");
		await driver.wait(until.elementLocated(By.id("email")),5000);
		const emailAddress = await driver.findElement(By.id("email")).getText();
		const username = await driver.findElement(By.id("login")).getText();
        expect(emailAddress).toBe(config.email);
		expect(username).toBe(config.username);
    });

    test('front channel user administrator', async () => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        const isAdministrator = await utils.isAdministrator(driver);
        expect(isAdministrator).toBe(true);
    });
});