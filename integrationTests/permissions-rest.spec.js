const config = require('./config');
const AdminFunctions = require('./adminFunctions');
const utils = require('./utils');
const webdriver = require('selenium-webdriver');

jest.setTimeout(30000);
let driver;
let adminFunctions;

// disable certificate validation
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

beforeEach(async() => {
    driver = utils.createDriver(webdriver);
    adminFunctions = new AdminFunctions('testUserR', 'testUserR', 'testUserR', 'testUserR@test.de', 'testuserrpasswort');
    await adminFunctions.createUser();
});

afterEach(async() => {
    await adminFunctions.removeUser(driver);
    await driver.quit();
});


describe('administration rest tests', () => {

    test('rest - user (testUser) has admin privileges', async() => {
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.giveAdminRights();
        await adminFunctions.testUserLogin(driver);
        await adminFunctions.testUserLogout(driver);
        await adminFunctions.accessUsersJson(200);
    });

    test('rest - user (testUser) has no admin privileges', async() => {
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.accessUsersJson(403);
    });


    test('rest - user (testUser) remove admin privileges', async() => {
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.testUserLogin(driver);
        await adminFunctions.testUserLogout(driver);
        await adminFunctions.takeAdminRights();
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.accessUsersJson(403);
    });

});