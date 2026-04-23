Feature: Dismiss Notifications

  @requires_testuser
  Scenario: test user opens sonar first time
    Given the user is logged into the CES
    When the user navigates to "/projects/create" page
    Then the headline "Welcome to SonarQube Community Build" should not exist
