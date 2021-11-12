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
        cy.request({
            method: "GET",
            url: Cypress.config().baseUrl + "/" + env.GetDoguName() + "/api/users/search",
            auth: {
                'user': testuserdata.username,
                'pass': testuserdata.password
            }
        }).then((response) => {
            expect(response.status).to.eq(200)
        })
    })
});

Then(/^the user can not access the SonarQube API with wrong username and password$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.request({
            method: "GET",
            url: Cypress.config().baseUrl + "/" + env.GetDoguName() + "/api/users/search",
            auth: {
                'user': "NoVaLiDUSRnam33",
                'pass': "ThIsIsNoTaP4$$worD"
            },
            failOnStatusCode: false
        }).then((response) => {
            expect(response.status).to.eq(401)
        })
    })
});
Then(/^the user is redirected to the SonarQube issue page$/, function () {
    cy.url().should('contain', Cypress.config().baseUrl + "/" + env.GetDoguName() + "/issues?resolved=false")
});

Then(/^the user can access the Web API with the User Token$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.getCookie(testuserdata.sonarqubeToken).should('exist').then((cookie) => {
            cy.request({
                method: "GET",
                url: Cypress.config().baseUrl + "/" + env.GetDoguName() + "/api/system/health",
                auth: {
                    'user': cookie.value,
                    'pass': ""
                }
            }).then((response) => {
                expect(response.status).to.eq(200)
            })
        })
    })
});
Then(/^the user's attributes are matching those in the user backend$/, function () {
    cy.fixture("testuser_data").then((testuserdata) => {
        cy.getCookie("userattributes").should('exist').then((cookie) => {
            //check if response body (from cookie) holds correct user data
            const responseBody = JSON.parse(cookie.value)
            expect(responseBody["users"][0]["login"]).to.equal(testuserdata.username)
            expect(responseBody["users"][0]["name"]).to.equal(testuserdata.displayName)
            expect(responseBody["users"][0]["email"]).to.equal(testuserdata.mail)
            expect(responseBody["users"][0]["externalIdentity"]).to.equal(testuserdata.username)
        })
    })
});

Then(/^the user's attributes should include the admin group$/, function () {
    cy.getCookie("adminuserattributes").should('exist').then((cookie) => {
        //check if response body (from cookie) holds admin group
        const responseBody = JSON.parse(cookie.value)
        expect(responseBody["users"][0]["groups"]).to.contain(env.GetAdminGroup())
        expect(responseBody["users"][0]["name"]).to.equal(env.GetAdminUsername())
    })
});