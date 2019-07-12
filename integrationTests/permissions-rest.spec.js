const AdminFunctions = require('./adminFunctions');
const expectations = require('./expectations');
const utils = require('./utils');
const webdriver = require('selenium-webdriver');
const userName = 'testUser';
const waitInterval = 1000;
require('chromedriver');

jest.setTimeout(60000);
let driver;
let adminFunctions;

// disable certificate validation
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

beforeEach(async() => {
    adminFunctions = await new AdminFunctions(userName, userName, userName, userName+'@test.de', 'testuserpassword');
	await adminFunctions.createTestUser();
});

afterEach(async() => {
    await adminFunctions.removeTestUser(driver);
});


describe('administration rest tests', () => {
	
	test('rest - user (testUser) has admin privileges', async() => {

        await adminFunctions.giveAdminRightsToTestUserViaUsermgt(driver);
        await sleep(waitInterval);
        await adminFunctions.accessUsersJson(200);

    });
	
	test('rest - user (testUser) has no admin privileges', async() => {
        await adminFunctions.accessUsersJson(403);

    });

	
	test('rest - user (testUser) remove admin privileges', async() => {
        driver = utils.createDriver(webdriver);
        await driver.manage().window().maximize();

        // give user admin permissions in usermgt
        await adminFunctions.giveAdminRightsToTestUserViaUsermgt(driver);
        await driver.sleep(waitInterval)
        // log user in and out
        await adminFunctions.testUserLogin(driver);
        await adminFunctions.logoutUserViaUI(driver);
        await driver.sleep(waitInterval)
        // make sure user is logged out (=> .../cas/logout is shown)
        let url = await driver.getCurrentUrl();
        expectations.expectCasLogout(url);
        // take admin permissions from user in usermgt
		await adminFunctions.takeAdminRightsUsermgt();
        await driver.sleep(waitInterval)
        // log user in and out
        await adminFunctions.testUserLogin(driver);
        await adminFunctions.logoutUserViaUI(driver);
        await driver.sleep(waitInterval)
        // make sure user is logged out (=> .../cas/logout is shown)
        url = await driver.getCurrentUrl();
        expectations.expectCasLogout(url);
        await driver.sleep(waitInterval)

        // check that user has no access to restricted api endpoints
        await adminFunctions.accessUsersJson(403);
        await driver.quit();
    });	
});