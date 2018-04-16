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

    async createUser(driver){
		
		await driver.wait(until.elementLocated(By.id("username")),5000);
		await driver.findElement(By.id('username')).sendKeys(this.testuserName);
		await driver.findElement(By.id('givenname')).sendKeys(this.testuserFirstname);
		await driver.findElement(By.id('surname')).sendKeys(this.testuserSurname);
		await driver.findElement(By.id('displayName')).sendKeys(this.testuserName);
		await driver.findElement(By.id('email')).sendKeys(this.testuserEmail);
		await driver.findElement(By.id('password')).sendKeys(this.testuserPasswort);
		await driver.findElement(By.id('confirmPassword')).sendKeys(this.testuserPasswort);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button")).click();
    };

    async removeUser(driver){
		
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button.btn.btn-warning.ng-scope")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button.btn.btn-warning.ng-scope")).click(); // First click to remove
		await driver.wait(until.elementLocated(By.css("body > div.modal.fade.ng-isolate-scope.in > div > div > div.modal-footer.ng-scope")),5000);
		await driver.findElement(By.css("body > div.modal.fade.ng-isolate-scope.in > div > div > div.modal-footer.ng-scope > button.btn.btn-danger")).click(); // Confirmation
    };

    async giveAdminRights(driver){
		
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(2)")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(2) > a")).click(); //Click to edit user group
		await driver.wait(until.elementLocated(By.id('addGroup')), 5000);
		await driver.findElement(By.id('addGroup')).sendKeys(config.adminGroup);
		await driver.wait(until.elementLocated(By.id('addGroup')), 5000);
		await driver.findElement(By.id('addGroup')).sendKeys(webdriver.Key.ENTER);
		await driver.sleep(3000);
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(1) > a")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(1) > a")).click(); //Click to edit user options
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button")).click(); // Saving changes
		await driver.wait(until.elementLocated(By.css("body > div.navbar.navbar-default.navbar-fixed-top > div > div.collapse.navbar-collapse > ul > li:nth-child(4) > a")),5000);
		await driver.findElement(By.css("body > div.navbar.navbar-default.navbar-fixed-top > div > div.collapse.navbar-collapse > ul > li:nth-child(4) > a")).click();  //Logging out
		await driver.wait(until.elementLocated(By.className('success')), 5000);
    };


    async takeAdminRights(driver){
		
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(2)")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > ul > li:nth-child(2) > a")).click();
		await driver.sleep(3000);
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > table > tbody > tr > td.text-right > span")),5000);
		await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > table > tbody > tr > td.text-right > span")).click(); // Deleting admin group
		await driver.wait(until.elementLocated(By.css("body > div.navbar.navbar-default.navbar-fixed-top > div > div.collapse.navbar-collapse > ul > li:nth-child(4) > a")),5000);
		await driver.findElement(By.css("body > div.navbar.navbar-default.navbar-fixed-top > div > div.collapse.navbar-collapse > ul > li:nth-child(4) > a")).click();  //Logging out
		await driver.wait(until.elementLocated(By.className('success')), 5000);
    };
	
	async testUser(driver,userName){
		
		await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > table > tbody > tr:nth-child(2) > td.ng-binding")),5000)
		.then(async function(){
			if (await driver.findElement(By.css("body > div.container.ng-scope > table > tbody > tr:nth-child(2) > td.ng-binding")).getText() == userName){
				await driver.get(utils.gettestUserUrl(driver,userName));
				await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button.btn.btn-warning.ng-scope")),5000);
				await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button.btn.btn-warning.ng-scope")).click(); // First click to remove
				await driver.wait(until.elementLocated(By.css("body > div.modal.fade.ng-isolate-scope.in > div > div > div.modal-footer.ng-scope")),5000);
				await driver.findElement(By.css("body > div.modal.fade.ng-isolate-scope.in > div > div > div.modal-footer.ng-scope > button.btn.btn-danger")).click(); // Confirmation
				await driver.sleep(3000);
				await driver.get(utils.maketestUserUrl(driver));
				return;
			} else {
				await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > table > tbody > tr:nth-child(3) > td.ng-binding")),5000)
				.then(async function(){
					if (await driver.findElement(By.css("body > div.container.ng-scope > table > tbody > tr:nth-child(3) > td.ng-binding")).getText() == userName){
						await driver.get(utils.gettestUserUrl(driver,userName));
						await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button.btn.btn-warning.ng-scope")),5000);
						await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button.btn.btn-warning.ng-scope")).click(); // First click to remove
						await driver.wait(until.elementLocated(By.css("body > div.modal.fade.ng-isolate-scope.in > div > div > div.modal-footer.ng-scope")),5000);
						await driver.findElement(By.css("body > div.modal.fade.ng-isolate-scope.in > div > div > div.modal-footer.ng-scope > button.btn.btn-danger")).click(); // Confirmation
						await driver.sleep(3000);
						await driver.get(utils.maketestUserUrl(driver));
						return;
					}else {
						await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > table > tbody > tr:nth-child(4) > td.ng-binding")),5000)
						.then(async function(){
							if (await driver.findElement(By.css("body > div.container.ng-scope > table > tbody > tr:nth-child(4) > td.ng-binding")).getText() == userName){
								await driver.get(utils.gettestUserUrl(driver,userName));
								await driver.wait(until.elementLocated(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button.btn.btn-warning.ng-scope")),5000);
								await driver.findElement(By.css("body > div.container.ng-scope > div.ng-isolate-scope > div > div.tab-pane.ng-scope.active > form > button.btn.btn-warning.ng-scope")).click(); // First click to remove
								await driver.wait(until.elementLocated(By.css("body > div.modal.fade.ng-isolate-scope.in > div > div > div.modal-footer.ng-scope")),5000);
								await driver.findElement(By.css("body > div.modal.fade.ng-isolate-scope.in > div > div > div.modal-footer.ng-scope > button.btn.btn-danger")).click(); // Confirmation
								await driver.sleep(3000);
								await driver.get(utils.maketestUserUrl(driver));
								return;
							}
							else {
								console.log("DID NOT MATCH!!");
							}
						},function(err){
							driver.get(utils.maketestUserUrl(driver));
							return;
						});
					}
				},function(err){
						driver.get(utils.maketestUserUrl(driver));
						return;
				});
			}
		},function(err){
				driver.get(utils.maketestUserUrl(driver));
				return;
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
	
	async accessUserAPI(isAdmin){
        const response = await request(config.baseUrl)
			.get(config.jenkinsContextPath + "/account/api/json")
			.auth(this.testuserName, this.testuserPasswort)
			.expect('Content-Type', "text/html;charset=utf-8")
            .expect(200);
		
		var templateName = 'amukherjee';
		var templateEmail = 'ces-admin@cloudogu.com';
		var l1 = templateName.length;
		var l2 = this.testuserName.length;
		var l3 = templateEmail.length;
		var l4 = this.testuserEmail.length;
		var indexstart = 2430;
		var indexend = 2451;
		//Getting text embedded as HTML in webpage api
		var testObj = response["request"]["req"]["res"]["text"];
		testObj = testObj.replace(/\s/g,'');
		indexstart = (indexstart-((l1-l2)*2))-(l3-l4);
		indexend = (indexend-((l1-l2)*2))-(l3-l4);
		// Search for "is Administrator" true condition
		var adminField = testObj.substring(indexstart,indexend);
		var isTrue = testObj.substring(indexstart+22,indexend+5);
		expect(adminField).toBe('window.SS.isUserAdmin');
		if (isAdmin == 'true'){
			expect(isTrue).toBe('true');
		} else {
			expect(isTrue).toBe('fals');
		}		
    };
};