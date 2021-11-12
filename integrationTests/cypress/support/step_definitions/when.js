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

When(/^the user is redirected to the account site$/, function () {
    cy.url().then(currentURL => {
        expect(currentURL).to.eq(Cypress.config().baseUrl + "/" + env.GetDoguName() + "/account")
    })
});

When(/^the user opens the SonarQube issue page$/, function () {
    cy.visit("/" + env.GetDoguName() + "/issues?resolved=false", {failOnStatusCode: false})
});

When(/^the user can create a User Token via the Web API$/, function () {
    cy.fixture("testuser_data").then(function (testuserdata) {
        cy.clearCookies()
        cy.request({
            method: "POST",
            url: Cypress.config().baseUrl + "/" + env.GetDoguName() + "/api/user_tokens/generate?name=" + testuserdata.sonarqubeToken,
            auth: {
                'user': testuserdata.username,
                'pass': testuserdata.password
            }
        }).then((response) => {
            expect(response.status).to.eq(200)
            // save token inside a cookie for the following (Then) steps
            cy.setCookie(testuserdata.sonarqubeToken, response.body["token"])
        })
    })
});

When(/^the user's attributes are requested via Web API$/, function () {
    cy.fixture("testuser_data").then(function (testuserdata) {
        cy.clearCookies()
        cy.request({
            method: "GET",
            url: Cypress.config().baseUrl + "/" + env.GetDoguName() + "/api/users/search?q=" + testuserdata.username,
            auth: {
                'user': testuserdata.username,
                'pass': testuserdata.password
            }
        }).then((response) => {
            expect(response.status).to.eq(200)
            // save data inside a cookie for the following (Then) steps
            cy.setCookie("userattributes", JSON.stringify(response.body))
        })
    })
});