const {
    Then
} = require("@badeball/cypress-cucumber-preprocessor");

const env = require('@cloudogu/dogu-integration-test-library/lib/environment_variables')

Then(/^the page shows the replicated data of the user in tabular form$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.get("#login").contains(testuserdata.username)
        cy.get("#email").contains(testuserdata.mail)
        cy.get("#component-nav-portal").contains(testuserdata.displayName)
    })
});

Then(/^the user can access the SonarQube API with API token$/, function () {
        cy.task("getAPIToken").then((token) => {
            cy.requestSonarAPI("/users/search", token)
        })
});

Then(/^the user can not access the SonarQube API with wrong api token$/, function () {
    cy.requestSonarAPI("/users/search", "incorrect_token", false, 401)
});

Then(/^the user can access the Web API with the User Token$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.task("getUserAPIToken").then((token) => {
            cy.requestSonarAPI("/system/ping", token)
        })
    })
});

Then(/^the user's login attribute matches the username attribute in the user backend$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.getCookie("userattributes").should('exist').then((cookie) => {
            const responseBody = JSON.parse(cookie.value)
            expect(responseBody["users"][0]["login"]).to.equal(testuserdata.username)
        })
    })
});

Then(/^the user's name attribute matches the displayName attribute in the user backend$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.getCookie("userattributes").should('exist').then((cookie) => {
            const responseBody = JSON.parse(cookie.value)
            expect(responseBody["users"][0]["name"]).to.equal(testuserdata.displayName)
        })
    })
});

Then(/^the user's email attribute matches the mail attribute in the user backend$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.getCookie("userattributes").should('exist').then((cookie) => {
            const responseBody = JSON.parse(cookie.value)
            expect(responseBody["users"][0]["email"]).to.equal(testuserdata.mail)
        })
    })
});

Then(/^the user's externalIdentity attribute matches the username attribute in the user backend$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.getCookie("userattributes").should('exist').then((cookie) => {
            const responseBody = JSON.parse(cookie.value)
            expect(responseBody["users"][0]["externalIdentity"]).to.equal(testuserdata.username)
        })
    })
});

Then(/^the user can access the \/users\/groups Web API endpoint$/, function () {
    cy.wait(30000)
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.task("getAPIToken").then((token) => {
            cy.requestSonarAPI("/system/health", token)
        })
    })
});

Then(/^the user can not access the \/users\/groups Web API endpoint$/, function () {
    cy.wait(30000)
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.task("getAPIToken").then((token) => {
            cy.requestSonarAPI("/users/groups?login=" + testuserdata.username, token, false, 403)
        })
    })
});