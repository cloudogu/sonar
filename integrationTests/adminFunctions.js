const config = require('./config');
const webdriver = require('selenium-webdriver');
const request = require('supertest');
const utils = require('./utils');
const By = webdriver.By;
const until = webdriver.until;
require('chromedriver');

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

module.exports = class AdminFunctions{
	
    constructor(testuserName, testUserFirstname, testuserSurname, testuserEmail, testuserPasswort) {
        this.testuserName=testuserName;
        this.testuserFirstname=testUserFirstname;
        this.testuserSurname=testuserSurname;
        this.testuserEmail=testuserEmail;
        this.testuserPasswort=testuserPasswort;
    };
	
    async createUser(){
		await request(config.baseUrl)
            .post('/usermgt/api/users/')
            .auth(config.username, config.password)
            .set('Content-Type', 'application/json;charset=UTF-8')
            .type('json')
            .send({
                'username': this.testuserName,
                'givenname': this.testuserFirstname,
                'surname': this.testuserSurname,
                'displayName': this.testuserName,
                'mail': this.testuserEmail,
                'password': this.testuserPasswort,
                'memberOf':[]
            });
    };

    async removeUser(driver){
        //remove in usermanagement
		await request(config.baseUrl)
            .del('/usermgt/api/users/' + this.testuserName)
            .auth(config.username, config.password);

        //remove in sonar (reason: a user that logged in sonar is still in sonar after removing it from usermanagement)
        await request(config.baseUrl)
            .post('/sonar/api/users/deactivate')
            .auth(config.username, config.password)
			.set('Content-Type', 'application/json;charset=UTF-8')
            .type('json')
            .send({
                'login': this.testuserName
            });
    };


    async testUserLogin(driver) {

        await driver.wait(until.elementLocated(By.id('password')), 5000);
        await driver.findElement(By.id('username')).sendKeys(this.testuserName);
        await driver.findElement(By.id('password')).sendKeys(this.testuserPasswort);
        await driver.findElement(By.css('input[name="submit"]')).click();
    };

    async testUserLogout(driver) {

		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1)")).click();
		await driver.wait(until.elementLocated(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(2) > a")),5000);
		await driver.findElement(By.css("#global-navigation > div > ul.nav.navbar-nav.navbar-right > li:nth-child(1) > ul > li:nth-child(2) > a")).click();
		await driver.wait(until.elementLocated(By.className('success')), 5000);
    };
	
	async giveAdminRights(driver){

        await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(2)")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(2) > a")).click(); //Click to edit user group
		await driver.wait(until.elementLocated(By.id('addGroup')), 5000);
		await driver.findElement(By.id('addGroup')).sendKeys(config.adminGroup);
		await driver.wait(until.elementLocated(By.id('addGroup')), 5000);
		await driver.findElement(By.id('addGroup')).sendKeys(webdriver.Key.ENTER);
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(1) > a")).click(); //Click to go back and save changes		
		await driver.findElement(By.className("btn btn-primary")).click(); // Saving changes
		await driver.findElement(By.linkText("Logout")).click();  //Logging out
		await driver.wait(until.elementLocated(By.className('success')), 5000);
    };	
	
	async takeAdminRights(driver){
		
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(2)")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(2) > a")).click();
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > table > tbody > tr > td.text-right > span")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > table > tbody > tr > td.text-right > span")).click(); // Deleting admin group
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(1) > a")).click(); //Click to go back and save changes
		await driver.findElement(By.className("btn btn-primary")).click(); // Saving changes
		await driver.findElement(By.linkText("Logout")).click();  //Logging out
		await driver.wait(until.elementLocated(By.className('success')), 5000);
    };
	
	async giveAdminRightsApi(){
		
		await request(config.baseUrl)
            .put('/usermgt/api/users/' + this.testuserName)
            .auth(config.username, config.password)
            .set('Content-Type', 'application/json;charset=UTF-8')
            .type('json')
            .send({'memberOf':[config.adminGroup],
                'username':this.testuserName,
                'givenname':this.testuserFirstname,
                'surname': this.testuserSurname,
                'displayName':this.testuserName,
                'mail':this.testuserEmail,
                'password':this.testuserPasswort})
            .expect(204);
    };	
	
	async takeAdminRightsApi(){
		
		await request(config.baseUrl)
            .put('/usermgt/api/users/' + this.testuserName)
            .auth(config.username, config.password)
            .set('Content-Type', 'application/json;charset=UTF-8')
            .type('json')
            .send({'memberOf':[],
                'username':this.testuserName,
                'givenname':this.testuserFirstname,
                'surname': this.testuserSurname,
                'displayName':this.testuserName,
                'mail':this.testuserEmail,
                'password':this.testuserPasswort})
            .expect(204);
    };
};