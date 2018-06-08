const config = require('./config');
const utils = require('./utils');
const expectations = require('./expectations');


require('chromedriver');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;

jest.setTimeout(30000);

let driver;


beforeEach(async () => {
    driver = utils.createDriver(webdriver);
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
		const username = await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a"))).getText();
        expect(username).toContain(config.displayName);
    });
	
	test('logout front channel', async() => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1)")).click();
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(2) > a")).click();
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
		expect(username).toBe(config.displayName);
    });

    test('front channel user administrator', async () => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        const isAdministrator = await utils.isAdministrator(driver);
        expect(isAdministrator).toBe(true);
    });
});