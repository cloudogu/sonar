package internal

import (
	"net/http"
	"path"
)

func WithBackChannelLogoutRequestCheck(appContextPath string) func(r *http.Request) bool {
	sanitizedAppContextPath := path.Join(appContextPath)

	return func(r *http.Request) bool {
		if r.Method != http.MethodPost {
			return false
		}

		contentType := r.Header.Get("Content-Type")
		if contentType != "application/x-www-form-urlencoded" {
			return false
		}

		urlPath := r.URL.Path

		if !(urlPath == sanitizedAppContextPath || urlPath == sanitizedAppContextPath+"/") {
			return false
		}

		return true
	}
}
