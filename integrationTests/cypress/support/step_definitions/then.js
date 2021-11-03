const {
    Then
} = require("cypress-cucumber-preprocessor/steps");

const env = require('@cloudogu/dogu-integration-test-library/lib/environment_variables')


Then(/^the test user's replicated user data is visible$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.get("[id=login]").then(loginFromSite => {
            expect(loginFromSite.text()).to.eq(testuserdata.username)
        })
        cy.get("[id=email]").then(loginFromSite => {
            expect(loginFromSite.text()).to.eq(testuserdata.mail)
        })
        cy.get("[id=name]").then(loginFromSite => {
            expect(loginFromSite.text()).to.eq(testuserdata.displayName)
        })
    })
});