// Loads all steps from the dogu integration library into this project
const doguTestLibrary = require('@cloudogu/dogu-integration-test-library')
const env = require('@cloudogu/dogu-integration-test-library/lib/environment_variables')
doguTestLibrary.registerSteps()

When(/^the user clicks the dogu logout button$/, function () {
    cy.loginSecondTimeIfNecessary()
    cy.visit("/" + env.GetDoguName(), { failOnStatusCode: false })
    // Click user menu button
    cy.get('html.kkhevqlt.idc0_332.sidebar-page body.sidebar-page div#content div.global-container div#container.page-wrapper div.page-container nav#global-navigation.navbar.navbar-global div.navbar-inner div.clearfix.navbar-limited ul.global-navbar-menu.global-navbar-menu-right li.dropdown.js-user-authenticated a.dropdown-toggle.navbar-avatar div.rounded').click();
    cy.get('#Log out').click();
});

Then(/^the user has administrator privileges in the dogu$/, function () {
    // TODO: Bestimme, dass der derzeitige User Adminrechte im Dogu besitzt
});

Then(/^the user has no administrator privileges in the dogu$/, function () {
    // TODO: Bestimme, dass der derzeitige User keine Adminrechte im Dogu besitzt
});
