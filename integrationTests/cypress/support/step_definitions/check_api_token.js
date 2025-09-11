const {
    Given
} = require("@badeball/cypress-cucumber-preprocessor");
const env = require("@cloudogu/dogu-integration-test-library/lib/environment_variables");

/**
 * Make sure that the API Token is set
 */
Given(/^check if API token is set$/, function () {
    cy.task("getAPIToken").then((token) => {
        if (token === "") {
            generateToken()
        }
    })
});

/**
 * always set new API-Token
 */
Given(/^reset API token$/, function () {
    generateToken()
});

function generateToken() {
    cy.visit("/" + env.GetDoguName() + "/account/security")
    cy.get("button").contains("Dismiss").click({force: true})
    cy.get('#token-name').type(Math.random().toString(),{force: true})
    cy.get("div").contains("Select Token Type").click({force: true}) //select("User Token")
    cy.get("#react-select-2-listbox").contains("User Token").click({force: true})
    cy.get("button").contains("Generate").click({force: true})
    cy.get("code").then((val) => {
        cy.task("setAPIToken", val.text())
    })
}
