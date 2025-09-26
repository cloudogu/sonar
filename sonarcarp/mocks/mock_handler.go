package mocks

import (
	"net/http"

	"github.com/stretchr/testify/mock"
)

type Handler struct {
	mock.Mock
	MserveHTTP func(w http.ResponseWriter, r *http.Request)
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Called(w, r)
	if h.MserveHTTP != nil {
		h.MserveHTTP(w, r)
	}
}
