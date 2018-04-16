const config = require('./config');
const AdminFunctions = require('./adminFunctions');
const utils = require('./utils');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;
const userName = 'testUser1234';
require('chromedriver');

jest.setTimeout(30000);
let driver;
let adminFunctions;

// disable certificate validation
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

beforeEach(async() => {
    driver = await utils.createDriver(webdriver);
    adminFunctions = new AdminFunctions(userName, userName, userName, userName+'@test.de', 'testuserpassword');
	await driver.get(utils.gettestUsersUrl(driver));
	//await driver.get(utils.maketestUserUrl(driver));
	await utils.login(driver);
	await driver.sleep(3000);
	await adminFunctions.testUser(driver,userName);
	await driver.sleep(3000);
	await adminFunctions.createUser(driver);
	await driver.sleep(3000);
	await driver.wait(until.elementLocated(By.css("body > div.navbar.navbar-default.navbar-fixed-top > div > div.collapse.navbar-collapse > ul > li:nth-child(4) > a")),5000);
	await driver.findElement(By.css("body > div.navbar.navbar-default.navbar-fixed-top > div > div.collapse.navbar-collapse > ul > li:nth-child(4) > a")).click(); //Logout
});

afterEach(async() => {
    await driver.get(utils.gettestUserUrl(driver,userName));
	await utils.login(driver);
	await adminFunctions.removeUser(driver);
    await driver.quit();
});


describe('administration rest tests', () => {

    test('rest - user (testUser1234) has admin privileges', async() => {
		
		await driver.get(utils.gettestUserUrl(driver,userName));
		await utils.login(driver);
        await adminFunctions.giveAdminRights(driver);
		const isAdmin = 'true';
		await driver.get(utils.getCasUrl(driver));
        await adminFunctions.testUserLogin(driver);
		await adminFunctions.testUserLogout(driver);
		await adminFunctions.accessUserAPI(isAdmin);
    });
	
	test('rest - user (testUser1234) has no admin privileges', async() => {
        const isAdmin = 'fals';
		await driver.get(utils.getCasUrl(driver));
		await adminFunctions.testUserLogin(driver);
		await adminFunctions.testUserLogout(driver);
        await adminFunctions.accessUserAPI(isAdmin);
    });
	
	test('rest - user (testUser1234) remove admin privileges', async() => {
        await driver.get(utils.gettestUserUrl(driver,userName));
		await utils.login(driver);
        await adminFunctions.giveAdminRights(driver);
		await driver.get(utils.gettestUserUrl(driver,userName));
		await utils.login(driver);
		await adminFunctions.takeAdminRights(driver);
		await driver.get(utils.getCasUrl(driver));
        await adminFunctions.testUserLogin(driver);
		await adminFunctions.testUserLogout(driver);
		const isAdmin = 'fals';
		await adminFunctions.accessUserAPI(isAdmin);
    });
});