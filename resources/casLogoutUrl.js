/**
 * Adds an event listener to the sonar logout button that navigates to the cas logout page
 * This script is called from the sonar cas plugin
 */
function logoutMenuHandler() {
    var menuHandlerTimer = setInterval(function () {
        var elem1 = document.querySelectorAll("a[href*='sessions/logout']")[0];
        if (elem1) {
            elem1.addEventListener('click', function (event) {
                window.location.href = '/cas/logout';
                event.stopImmediatePropagation();
                return false;
            });
            clearInterval(menuHandlerTimer)
        }
    }, 250);
}

window.onload = logoutMenuHandler