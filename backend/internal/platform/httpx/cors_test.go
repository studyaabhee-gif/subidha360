package httpx

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDevCORSAnswersPreflightWithoutCallingTheHandler(t *testing.T) {
	called := false
	h := DevCORS(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { called = true }))

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodOptions, "/v1/me", nil))

	if rec.Code != http.StatusNoContent || called {
		t.Fatalf("status = %d, called = %v", rec.Code, called)
	}
	if rec.Header().Get("Access-Control-Allow-Headers") == "" {
		t.Fatal("missing allow headers")
	}
}

func TestDevCORSPassesOtherRequestsThrough(t *testing.T) {
	h := DevCORS(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusTeapot) }))

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/v1/me", nil))

	if rec.Code != http.StatusTeapot || rec.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Fatalf("status = %d", rec.Code)
	}
}
