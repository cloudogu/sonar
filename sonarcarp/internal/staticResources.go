package internal

import (
	"fmt"
	"net/url"
	"regexp"
)

// staticResourceMatchers contains regexps that determine routes of unauthenticated web resources in sonarqube.
var staticResourceMatchers []*regexp.Regexp

// InitStaticResourceMatchers set up static resource matchers for IsInAlwaysAllowList.
//
// Usually, this initializer should be called once during the server start-up as there is no need for change
// accommodation which would happen during container restart.
func InitStaticResourceMatchers(paths []string) error {
	var result []*regexp.Regexp

	for _, path := range paths {
		regex, err := regexp.Compile(path)
		if err != nil {
			return fmt.Errorf("failed to create static resource matcher regex for static resource path '%s' (is it a compatible regex?): %w", path, err)
		}
		result = append(result, regex)
	}

	staticResourceMatchers = result

	return nil
}

func IsInAlwaysAllowList(path string) bool {
	for _, matcher := range staticResourceMatchers {

		cleanedPath, err := url.JoinPath(path, "")
		if err != nil {
			log.Errorf("Error cleaning path '%s' (will require authentication though): %s", path, err.Error())
		}
		if matcher.MatchString(cleanedPath) {
			return false
		}
	}

	return true
}
