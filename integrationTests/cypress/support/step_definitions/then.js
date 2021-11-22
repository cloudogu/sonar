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

Then(/^the user can access the SonarQube API with username and password$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.requestSonarAPI("/users/search", testuserdata.username, testuserdata.password)
    })
});

Then(/^the user can not access the SonarQube API with wrong username and password$/, function () {
    cy.requestSonarAPI("/users/search", "NoVaLiDUSRnam33", "ThIsIsNoTaP4$$worD", false, 401)
});

Then(/^the user is redirected to the SonarQube issue page$/, function () {
    cy.url().should('contain', Cypress.config().baseUrl + "/" + env.GetDoguName() + "/issues?resolved=false")
});

Then(/^the user can access the Web API with the User Token$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.getCookie(testuserdata.sonarqubeToken).should('exist').then((cookie) => {
            cy.requestSonarAPI("/system/health", cookie.value)
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

Then(/^the user's attributes should include the admin group$/, function () {
    cy.getCookie("adminuserattributes").should('exist').then((cookie) => {
        //check if response body (from cookie) holds admin group
        const responseBody = JSON.parse(cookie.value)
        cy.log("DEBUG: " + cookie.value)
        expect(responseBody["users"][0]["groups"]).to.contain(env.GetAdminGroup())
    })
});

Then(/^the user can access the \/users\/groups Web API endpoint$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.requestSonarAPI("/users/groups?login=" + testuserdata.username, testuserdata.username, testuserdata.password)
    })
});

Then(/^the user is redirected to the account site$/, function () {
    cy.url().then(currentURL => {
        expect(currentURL).to.eq(Cypress.config().baseUrl + "/" + env.GetDoguName() + "/account")
    })
});

Then(/^the user can not access the \/users\/groups Web API endpoint$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.requestSonarAPI("/users/groups?login=" + testuserdata.username, testuserdata.username, testuserdata.password, false, 403)
    })
});