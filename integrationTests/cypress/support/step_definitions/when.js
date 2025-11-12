const {
    When
} = require("@badeball/cypress-cucumber-preprocessor");

const env = require('@cloudogu/dogu-integration-test-library/lib/environment_variables')

When(/^the user creates a User Token via the Web API$/, function () {
    cy.fixture("testuser_data").then(function (testuserdata) {
        cy.clearCookies()
        cy.wait(2000)
        cy.task("getAPIToken").then((token) => {
            cy.requestSonarAPI("/user_tokens/generate?name=" + Math.random().toString(), token, true, 200, "POST").then(function (response) {
                cy.task("setUserAPIToken", response.body["token"])
        })
        })
    })
});

When(/^wait for sonar load$/, function () {
    cy.get('#create-project', { timeout: 10000 }).should('be.visible');
    // even though sonar is fully loaded at this time, the test with multiple logins get flaky unless we wait a bit
    cy.wait(10000);
});

When(/^the user requests his\/her attributes via the \/users API endpoint$/, function () {
    cy.fixture("testuser_data").then(function (testuserdata) {
        cy.task("getAPIToken").then((token) => {
            cy.clearCookies()
            cy.wait(2000)
            cy.requestSonarAPI("/users/search?q=" + testuserdata.username, token).then(function (response) {
                cy.setCookie("userattributes", JSON.stringify(response.body))
            })
        })
    })
});

When("the user navigates to {string} page", function (name) {
    cy.visit("/" + env.GetDoguName() + name, {failOnStatusCode: false})
});