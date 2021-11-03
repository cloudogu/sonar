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