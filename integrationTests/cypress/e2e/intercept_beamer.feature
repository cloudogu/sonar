Feature: Beamer-calls are intercepted

  @requires_testuser
  Scenario: No Beamer calls on Start-Page
    Given the user is logged into the CES
    When the "GET" call to "**getbeamer.com**" is intercepted as "beamerCalls"
    When the user navigates to "/projects/create" page
    Then the interception count for "beamerCalls" should be 0 after 10 seconds
    Then the data-component "beamer-widget-custom" should not be visible

