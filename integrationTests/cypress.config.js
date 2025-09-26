const doguTestLibrary = require('@cloudogu/dogu-integration-test-library');
const { defineConfig } = require('cypress');
const createBundler = require("@bahmutov/cypress-esbuild-preprocessor");
const preprocessor = require("@badeball/cypress-cucumber-preprocessor");
const createEsbuildPlugin = require("@badeball/cypress-cucumber-preprocessor/esbuild");

async function setupNodeEvents(on, config) {
    // This is required for the preprocessor to be able to generate JSON reports after each run, and more,
    await preprocessor.addCucumberPreprocessorPlugin(on, config);
    
    on(
        "file:preprocessor",
        createBundler({
            plugins: [createEsbuildPlugin.default(config)],
        }),
    );

    on("task", {
        setAPIToken(token) {
            global.token = token;
            return null;
        },
        getAPIToken() {
            return global.token ? global.token : null;
        },
        log(message) { console.log('\t[cy.log]', message); return null; },
        setUserAPIToken(token) {
            global.usertoken = token;
            return null;
        },
        getUserAPIToken() {
            return global.usertoken ? global.usertoken : null;
        },
    });

    config = doguTestLibrary.configure(config);

    return config;
}

module.exports = defineConfig({
    e2e: {
        baseUrl: 'https://192.168.56.2',
        env: {
            "DoguName": "sonar",
            "MaxLoginRetries": 3,
            "AdminUsername": "ces-admin",
            "AdminPassword": "Ecosystem2016!",
            "AdminGroup": "CesAdministrators"
        },
        videoCompression: false,
        specPattern: ["cypress/e2e/**/*.feature"],
        viewportWidth: 1920,
        viewportHeight: 1080,
        setupNodeEvents
    },
});