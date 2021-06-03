const utils = require('./utils');
const AdminFunctions = require('./adminFunctions');

require('chromedriver');
const webdriver = require('selenium-webdriver');
const userName = 'testUser';

jest.setTimeout(60000);

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

let driver;
let adminFunctions;

beforeEach(async () => {
  driver = utils.createDriver(webdriver);
  await driver.manage().window().maximize();
  let user = userName + getRandomInt(1, 9999999)
  adminFunctions = await new AdminFunctions(user, user, user, user + '@test.de', 'testuserpassword');
  await adminFunctions.createTestUser();
});

afterEach(async () => {
  await adminFunctions.logoutUserViaUI(driver);
  await adminFunctions.removeTestUser();
  await driver.quit();
});


describe('user permissions', () => {

  test('user (testUser) has admin privileges', async () => {

    await adminFunctions.giveAdminRightsToTestUserViaUsermgt(driver);
    await driver.get(utils.getCasUrl(driver));
    await adminFunctions.testUserLogin(driver);

    const isAdministrator = await utils.isAdministrator(driver);
    expect(isAdministrator).toBe(true);
  });

  test('user (testUser) has no admin privileges', async () => {
    await driver.get(utils.getCasUrl(driver));
    await adminFunctions.testUserLogin(driver);

    const adminPermissions = await utils.isAdministrator(driver);
    expect(adminPermissions).toBe(false);
  });

  test('user (testUser) remove admin privileges', async () => {

    await adminFunctions.giveAdminRightsToTestUserViaUsermgt(driver);
    await driver.get(utils.getCasUrl(driver));

    await adminFunctions.testUserLogin(driver);
    await adminFunctions.logoutUserViaUI(driver);

    await adminFunctions.takeAdminRightsUsermgt(driver);

    await driver.get(utils.getCasUrl(driver));
    await adminFunctions.testUserLogin(driver);
    const isAdministrator = await utils.isAdministrator(driver);
    expect(isAdministrator).toBe(false);
  });
});

function getRandomInt(min, max) {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min)) + min;
}