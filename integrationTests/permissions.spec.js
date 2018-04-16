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
	await driver.get(utils.gettestUsersUrl(driver));
	//await driver.get(utils.maketestUserUrl(driver));
	await utils.login(driver);
	await driver.sleep(3000);
	await adminFunctions.testUser(driver,userName);
	await driver.sleep(3000);
	await adminFunctions.createUser(driver);
	await driver.sleep(5000);
	await driver.wait(until.elementLocated(By.css("body > div.navbar.navbar-default.navbar-fixed-top > div > div.collapse.navbar-collapse > ul > li:nth-child(4) > a")),5000);
	await driver.findElement(By.css("body > div.navbar.navbar-default.navbar-fixed-top > div > div.collapse.navbar-collapse > ul > li:nth-child(4) > a")).click(); //Logout
});

afterEach(async() => {
	await driver.get(utils.gettestUserUrl(driver,userName));
	await utils.login(driver);
	await adminFunctions.removeUser(driver);
    await driver.quit();
});

describe('user permissions', () => {
	
	test('user (testUser) remove admin privileges', async() => {
		
        // Remove Admin Rights
		await driver.get(utils.gettestUserUrl(driver,userName));
		await utils.login(driver);
		await driver.sleep(3000);
        await adminFunctions.giveAdminRights(driver);
		await driver.sleep(3000);
		await driver.get(utils.gettestUserUrl(driver,userName));
		await utils.login(driver);
		await driver.sleep(3000);
		await adminFunctions.takeAdminRights(driver);
		await driver.sleep(3000);
        await driver.get(utils.getCasUrl(driver));
        await adminFunctions.testUserLogin(driver);
		//test Admin Rights removal
		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1)")).click();
		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(1) > a")).click();
		await driver.wait(until.elementLocated(By.xpath("//*[@id='content']/div/div/div/div[3]")),5000);
        adminPermissions = await utils.isAdministrator(driver);
        expect(adminPermissions).toBe(false);
		await adminFunctions.testUserLogout(driver);
    });
	
	test('user (testUser) has no admin privileges', async() => {
		
		// Test no Admin Rights
        await driver.get(utils.getCasUrl(driver));
		await adminFunctions.testUserLogin(driver);
			// Test testUser creation
		const username = await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a"))).getText();
        expect(username).toContain(userName);
		// Contd...
		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1)")).click();
		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(1) > a")).click();
		await driver.wait(until.elementLocated(By.xpath("//*[@id='content']/div/div/div/div[3]")),5000);
        adminPermissions = await utils.isAdministrator(driver);
		expect(adminPermissions).toBe(false);
		await adminFunctions.testUserLogout(driver);
    });
	
	test('user (testUser) has admin privileges', async() => {
		
		// Giving Admin Rights
		await driver.get(utils.gettestUserUrl(driver,userName));
		await utils.login(driver);
        await adminFunctions.giveAdminRights(driver);
		await driver.get(utils.getCasUrl(driver));
        await adminFunctions.testUserLogin(driver);
		// test Admin rights addition
		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1)")).click();
		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(1) > a")).click();
		await driver.wait(until.elementLocated(By.xpath("//*[@id='content']/div/div/div/div[3]")),5000);
        adminPermissions = await utils.isAdministrator(driver);
        expect(adminPermissions).toBe(true);
        await adminFunctions.testUserLogout(driver);		
	});
});