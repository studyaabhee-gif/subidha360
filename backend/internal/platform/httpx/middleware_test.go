package httpx

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestObserveRecoversFromPanics(t *testing.T) {
	h := Observe(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("boom")
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/v1/anything", nil))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "internal_error") || strings.Contains(rec.Body.String(), "boom") {
		t.Fatalf("body leaks or lacks the error: %s", rec.Body)
	}
	if len(rec.Header().Get("X-Request-ID")) != 16 {
		t.Fatalf("request id = %q", rec.Header().Get("X-Request-ID"))
	}
}

func TestObserveGivesEachRequestItsOwnID(t *testing.T) {
	h := Observe(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	ids := map[string]bool{}
	for range 20 {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
		ids[rec.Header().Get("X-Request-ID")] = true
	}
	if len(ids) != 20 {
		t.Fatalf("got %d distinct ids from 20 requests", len(ids))
	}
}
