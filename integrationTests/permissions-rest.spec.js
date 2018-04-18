const config = require('./config');
const AdminFunctions = require('./adminFunctions');
const utils = require('./utils');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;
const userName = 'testUser';
require('chromedriver');

jest.setTimeout(30000);
let driver;
let adminFunctions;

// disable certificate validation
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

beforeEach(async() => {
    driver = await utils.createDriver(webdriver);
    adminFunctions = new AdminFunctions(userName, userName, userName, userName+'@test.de', 'testuserpassword');
	await adminFunctions.createUser();
});

afterEach(async() => {
    await adminFunctions.testUserLogout(driver);
	await adminFunctions.removeUser(driver);
	await driver.quit();
});


describe('administration rest tests', () => {
	
	test('rest - user (testUser) has admin privileges', async() => {
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.giveAdminRightsApi();
		await adminFunctions.testUserLogin(driver);
		const username = await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a"))).getText();
        expect(username).toContain(userName);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/");
        const isAdministrator = await utils.isAdministrator(driver);
        expect(isAdministrator).toBe(true);
        
    });
	
	test('rest - user (testUser) has no admin privileges', async() => {
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.testUserLogin(driver);
		const username = await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a"))).getText();
        expect(username).toContain(userName);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/");
        adminPermissions = await utils.isAdministrator(driver);
		expect(adminPermissions).toBe(false);
    });

	
	test('rest - user (testUser) remove admin privileges', async() => {
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.giveAdminRightsApi();
        await adminFunctions.testUserLogin(driver);
		const username = await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a"))).getText();
        expect(username).toContain(userName);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/");
        expect(await utils.isAdministrator(driver)).toBe(true);
        await adminFunctions.testUserLogout(driver);
        await driver.wait(until.elementLocated(By.className('success')), 5000);
		await adminFunctions.takeAdminRightsApi();
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.testUserLogin(driver);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/");
        const adminPermissions = await utils.isAdministrator(driver);
        expect(adminPermissions).toBe(false);
    });	
});