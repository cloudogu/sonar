const config = require('./config');
const AdminFunctions = require('./adminFunctions');
const utils = require('./utils');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;
const userName = 'testUser';
const waitInterval = 3000;
require('chromedriver');
const request = require('supertest');

jest.setTimeout(60000);
let driver;
let adminFunctions;

// disable certificate validation
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

beforeEach(async() => {
    driver = await utils.createDriver(webdriver);
    adminFunctions = await new AdminFunctions(userName, userName, userName, userName+'@test.de', 'testuserpassword');
	await adminFunctions.createUser();
});

afterEach(async() => {
	await adminFunctions.removeUser(driver);
	await driver.quit();
});


describe('administration rest tests', () => {
	
	test('rest - user (testUser) has admin privileges', async() => {

        await adminFunctions.giveAdminRightsUsermgt(driver);
        await driver.sleep(waitInterval);
        await adminFunctions.accessUsersJson(200);

    });
	
	test('rest - user (testUser) has no admin privileges', async() => {
        await adminFunctions.accessUsersJson(403);

    });

	
	test('rest - user (testUser) remove admin privileges', async() => {

        await adminFunctions.giveAdminRightsUsermgt(driver);

        await adminFunctions.testUserLogin(driver);
        await adminFunctions.testUserLogout(driver);

		await adminFunctions.takeAdminRightsUsermgt();

        await adminFunctions.testUserLogin(driver);
        await adminFunctions.testUserLogout(driver);

        await adminFunctions.accessUsersJson(403);

    });	
});