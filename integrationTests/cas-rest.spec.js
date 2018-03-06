const config = require('./config');
const utils = require('./utils');
const request = require('supertest');

const webdriver = require('selenium-webdriver');
const By = webdriver.By;
const until = webdriver.until;
jest.setTimeout(30000);

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';


let driver;

beforeEach(() => {
    driver = utils.createDriver(webdriver);
});

afterEach(() => {
    driver.quit();
});


describe('cas rest basic authentication', () => {

    test('authentication with username password', async () => {
        await request(config.baseUrl)
            .get(config.jenkinsContextPath + "/api/json")
            .auth(config.username, config.password)
            .expect(200);
    });

    /*login -> click on username -> configure -> show api token*/
    test('authentication with API key', async () => {
        await driver.get(utils.getCasUrl(driver));
        await utils.login(driver);
        await driver.get(config.baseUrl + config.jenkinsContextPath + "/user/" + config.username + "/configure");
        await driver.wait(until.elementLocated(By.id('yui-gen1-button')), 5000);
        await driver.findElement(By.id("yui-gen1-button")).click();
        const input = await driver.findElement(By.id("apiToken"));
        const apikey = await input.getAttribute("value");
        await request(config.baseUrl)
            .get(config.jenkinsContextPath+"/api/json")
            .auth(config.username, apikey)
            .expect(200);
    });


});


describe('rest attributes', () => {

    test('rest - user attributes', async () => {
        const response = await request(config.baseUrl)
            .get(config.jenkinsContextPath + '/user/' + config.username + '/api/json')
            .auth(config.username, config.password)
            .expect('Content-Type', /json/)
            .expect(200);

        expect(response.body.fullName).toBe(config.displayName);
        expect(response.body.property[response.body.property.length-1].address).toBe(config.email);

    });

    test('rest - user is administrator', async () => {
        await request(config.baseUrl)
            .get(config.jenkinsContextPath+"/pluginManager/api/json")
            .auth(config.username, config.password)
            .expect(200);
    });



});