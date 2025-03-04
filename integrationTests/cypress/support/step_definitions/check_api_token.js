const {
    Given
} = require("@badeball/cypress-cucumber-preprocessor");
const env = require("@cloudogu/dogu-integration-test-library/lib/environment_variables");

/**
 * Make sure that the API Token is set
 */
Given(/^check if API token is set$/, function () {
    cy.task("getAPIToken").then((token) => {
        if (token === null) {
            cy.visit("/" + env.GetDoguName() + "/account/security")
            cy.get('#token-name').type(Math.random().toString())
            cy.get("div").contains("Select Token Type").click({force: true}) //select("User Token")
            cy.get("#react-select-2-listbox").contains("User Token").click({force: true})
            cy.get("button").contains("Generate").click()
            cy.get("code").then((val) => {
                cy.task("setAPIToken", val.text())
            })
        }
    })
});
