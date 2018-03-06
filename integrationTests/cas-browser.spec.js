const config = require('./config');
const utils = require('./utils');
const webdriver = require('selenium-webdriver');
const By = webdriver.By;

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
        expect(url).toMatch(loginUrl);
    });

    test('login', async() => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        const username = await driver.findElement(By.className('login')).getText();
        expect(username).toContain(config.displayName);
    });

    test('logout front channel', async() => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        await driver.findElement(By.xpath("//div[@id='header']/div[2]/span/a[2]/b")).click();
        const url = await driver.getCurrentUrl();
        expect(url).toMatch(logoutUrl);
    });

    test('logout back channel', async() => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        await driver.get(config.baseUrl + logoutUrl);
        await driver.get(config.baseUrl + config.jenkinsContextPath);
        const url = await driver.getCurrentUrl();
        expect(url).toMatch(loginUrl);
    });

});


describe('browser attributes', () => {

    test('front channel user attributes', async () => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        await driver.get(config.baseUrl + config.jenkinsContextPath + "/user/" + config.username + "/configure");
        const emailAddressInput = await driver.findElement(By.name("email.address"));
        const emailAddress = await emailAddressInput.getAttribute("value");
        const usernameInput= await driver.findElement(By.name('_.fullName'));
        const username = await usernameInput.getAttribute("value");
        expect(username).toBe(config.displayName);
        expect(emailAddress).toBe(config.email);
    });

    test('front channel user administrator', async () => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        const isAdministrator = await utils.isAdministrator(driver);
        expect(isAdministrator).toBe(true);
    });



});



