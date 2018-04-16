const config = require('./config');
const utils = require('./utils');


require('chromedriver');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;

const logoutUrl = '/cas/logout';
const loginUrl = '/cas/login';


jest.setTimeout(30000);

let driver;


beforeEach(() => {
    driver = utils.createDriver(webdriver);
});

afterEach(() => {
    driver.quit();
});

describe('cas browser login', () => {
	
    test('automatic redirect to cas login', async () => {
        await driver.get(config.baseUrl + config.jenkinsContextPath);
        const url = await driver.getCurrentUrl();
		await driver.sleep(500);
        expect(url).toMatch(loginUrl);
    });

    test('login', async() => {
        await driver.get(utils.getCasUrl(driver));
		await utils.login(driver);
		const username = await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a"))).getText();
		await driver.sleep(500);
        expect(username).toContain(config.displayName);
    });
	
	test('logout front channel', async() => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1)")).click();
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(2) > a")).click();
		const url = await driver.getCurrentUrl();
		await driver.sleep(500);
        expect(url).toMatch(logoutUrl);
    });
	
    test('logout back channel', async() => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        await driver.get(config.baseUrl + logoutUrl);
        await driver.get(config.baseUrl + config.jenkinsContextPath);
		await driver.sleep(3000);
		const url = await driver.getCurrentUrl();
		await driver.sleep(500);
        expect(url).toMatch(loginUrl);
    });

});

describe('browser attributes', () => {

    test('front channel user attributes', async () => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
		await driver.get(config.baseUrl + config.jenkinsContextPath + "/account/");
		await driver.wait(until.elementLocated(By.css("#content > div > header")),5000);
		const emailAddressInput = await driver.findElement(By.css("#email"));
		const emailAddress = await emailAddressInput.getText();
		const usernameInput= await driver.findElement(By.css('#login'));
		const username = await usernameInput.getText();
		await driver.sleep(500);
        expect(username).toBe(config.displayName);
        expect(emailAddress).toBe(config.email);
    });

    test('front channel user administrator', async () => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
		await driver.get(config.baseUrl + config.jenkinsContextPath + "/account/");
		await driver.wait(until.elementLocated(By.css("#content > div > div > div > div:nth-child(3)")),5000);
        const isAdministrator = await utils.isAdministrator(driver);
		await driver.sleep(500);
        expect(isAdministrator).toBe(true);
    });
});