const {
    When
} = require("cypress-cucumber-preprocessor/steps");

const env = require('@cloudogu/dogu-integration-test-library/lib/environment_variables')

When(/^the user clicks the user menu button$/, function () {
    cy.get('*[class^="dropdown-toggle navbar-avatar"]').scrollIntoView().click();
});

When(/^the user clicks the My Account button$/, function () {
    cy.get('*[class^="popup is-bottom"]').contains("My Account").click();
});

When(/^the user opens the SonarQube issue page$/, function () {
    cy.visit("/" + env.GetDoguName() + "/issues?resolved=false", {failOnStatusCode: false})
});

When(/^the user creates a User Token via the Web API$/, function () {
    cy.fixture("testuser_data").then(function (testuserdata) {
        cy.clearCookies()
        cy.requestSonarAPI("/user_tokens/generate?name=" + testuserdata.sonarqubeToken, testuserdata.username, testuserdata.password, true, 200, "POST").then(function (response) {
            cy.setCookie(testuserdata.sonarqubeToken, response.body["token"])
        })
    })
});

When(/^the user requests his\/her attributes via the \/users API endpoint$/, function () {
    cy.fixture("testuser_data").then(function (testuserdata) {
        cy.clearCookies()
        cy.requestSonarAPI("/users/search?q=" + testuserdata.username, testuserdata.username, testuserdata.password).then(function (response) {
            cy.setCookie("userattributes", JSON.stringify(response.body))
        })
    })
});

When(/^the admin user requests his\/her attributes via the \/users API endpoint$/, function () {
    cy.clearCookies()
    cy.requestSonarAPI("/users/search?q=" + env.GetAdminUsername(), env.GetAdminUsername(), env.GetAdminPassword()).then(function (response) {
        cy.setCookie("adminuserattributes", JSON.stringify(response.body))
    })
});