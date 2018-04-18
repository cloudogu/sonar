const config = require('./config');
const utils = require('./utils');
const AdminFunctions = require('./adminFunctions');

require('chromedriver');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;
const userName = 'testUser';

jest.setTimeout(60000);

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';


let driver;
let adminFunctions;

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


describe('user permissions', () => {
	
	test('user (testUser) has admin privileges', async() => {
		
		await driver.get(utils.gettestUserUrl(driver,userName));
		await utils.login(driver);
		await adminFunctions.giveAdminRights(driver);
		await driver.get(utils.getCasUrl(driver));
		await adminFunctions.testUserLogin(driver);
		const username = await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a"))).getText();
        expect(username).toContain(userName);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/");
        const isAdministrator = await utils.isAdministrator(driver);
        expect(isAdministrator).toBe(true);
    });
	
	test('user (testUser) has no admin privileges', async() => {
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.testUserLogin(driver);
		const username = await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a"))).getText();
        expect(username).toContain(userName);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/");
        adminPermissions = await utils.isAdministrator(driver);
		expect(adminPermissions).toBe(false);
    });
	
	test('user (testUser) remove admin privileges', async() => {
        await driver.get(utils.gettestUserUrl(driver,userName));
		await utils.login(driver);
		await adminFunctions.giveAdminRights(driver);
		await driver.get(utils.getCasUrl(driver));
		await adminFunctions.testUserLogin(driver);
		const username = await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a"))).getText();
        expect(username).toContain(userName);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/");
        expect(await utils.isAdministrator(driver)).toBe(true);
		await adminFunctions.testUserLogout(driver);
        await driver.wait(until.elementLocated(By.className('success')), 5000);
		await driver.get(utils.gettestUserUrl(driver,userName));
		await utils.login(driver);
		await adminFunctions.takeAdminRights(driver);
		await driver.get(utils.getCasUrl(driver));
		await adminFunctions.testUserLogin(driver);
		await driver.get(config.baseUrl + config.sonarContextPath + "/account/");
        const isAdministrator = await utils.isAdministrator(driver);
        expect(isAdministrator).toBe(false);
    });	
});