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

		await adminFunctions.giveAdminRightsUsermgt(driver);
		await driver.get(utils.getCasUrl(driver));
		await adminFunctions.testUserLogin(driver);

        const isAdministrator = await utils.isAdministrator(driver);
        expect(isAdministrator).toBe(true);
    });
	
	test('user (testUser) has no admin privileges', async() => {
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.testUserLogin(driver);

        var adminPermissions = await utils.isAdministrator(driver);
		expect(adminPermissions).toBe(false);
    });
	
	test('user (testUser) remove admin privileges', async() => {

        await adminFunctions.giveAdminRightsUsermgt(driver);
        await driver.get(utils.getCasUrl(driver));

		await adminFunctions.testUserLogin(driver);
		await adminFunctions.testUserLogout(driver);

		await adminFunctions.takeAdminRightsUsermgt(driver);

		await driver.get(utils.getCasUrl(driver));
		await adminFunctions.testUserLogin(driver);
        const isAdministrator = await utils.isAdministrator(driver);
        expect(isAdministrator).toBe(false);
    });	
});