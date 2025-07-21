// ***********************************************************
// This example support/e2e.js is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

const commands_sonarqube_api = require('./commands/sonarqube_api')
// Loads all commands from the dogu integration library into this project
const doguTestLibrary = require('@cloudogu/dogu-integration-test-library')
doguTestLibrary.registerCommands()


doguTestLibrary.logout = () =>{
    cy.visit("/cas/logout")
    cy.wait(30000) // 30 seconds instead of 1 second
}


commands_sonarqube_api.register()

Cypress.on('uncaught:exception', (err, runnable) => {
    // returning false here prevents Cypress from
    // failing the test
    return false
})

// local commands
import './commands/required_commands_for_dogu_lib'
import './commands/sonarqube_api'