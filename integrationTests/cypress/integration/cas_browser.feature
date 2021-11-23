Feature: SonarQube-specific browser-based CAS login and logout functionality

  @requires_testuser
  Scenario: CAS redirects user to subpage of SonarQube after login if this page was requested
  Given the user is logged out of the CES
    And the warp menu hint is turned off
    When the user opens the SonarQube issue page
    Then the user is redirected to the CAS login page
    When the user types in correct login credentials
    And the user clicks the login button
    Then the user is redirected to the SonarQube issue page