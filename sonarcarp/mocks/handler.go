package mocks

import (
	"github.com/stretchr/testify/mock"
	"net/http"
)

type Handler struct {
	mock.Mock
	MserveHTTP func(w http.ResponseWriter, r *http.Request)
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Called()
	if h.MserveHTTP != nil {
		h.MserveHTTP(w, r)
	}
}
