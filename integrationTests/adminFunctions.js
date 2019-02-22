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

        await driver.get(config.baseUrl + config.sonarContextPath);
        await driver.wait(until.elementLocated(By.id('password')), 5000);
        await driver.findElement(By.id('username')).sendKeys(this.testuserName);
        await driver.findElement(By.id('password')).sendKeys(this.testuserPasswort);
        await driver.findElement(By.css('input[name="submit"]')).click();
    };

    async testUserLogout(driver) {
        await this.showUserMenu(driver);
        // wait for dropdown menu
        await driver.wait(until.elementLocated(By.className("dropdown-menu dropdown-menu-right")),5000);
        // click logout link
		await driver.findElement(By.xpath("//a[@href='#']")).click();
    };

    async showUserMenu(driver) {
        // wait for user button
        await driver.wait(until.elementLocated(By.className("dropdown-toggle navbar-avatar")),5000);
        // click user button
        await driver.findElement(By.className("dropdown-toggle navbar-avatar")).click();
    };

	async giveAdminRightsUsermgt(){
		
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
	
	async takeAdminRightsUsermgt(){
		
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

    async accessUsersJson(expectStatus){

        await request(config.baseUrl)
            .get(config.sonarContextPath + "/api/users/groups?login="+this.testuserName)
            .auth(this.testuserName, this.testuserPasswort)
            .expect('Content-Type', 'application/json')
            .type('json')
            .expect(expectStatus);//403 = "Forbidden", 200 = "OK"
    };
};