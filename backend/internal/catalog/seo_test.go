package catalog

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func get(mux *http.ServeMux, path string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", path, nil))
	return rec
}

func TestSitemapListsPublicPagesAndServices(t *testing.T) {
	mux := http.NewServeMux()
	SEORoutes(mux, "https://example.com/")
	rec := get(mux, "/sitemap.xml")
	body := rec.Body.String()
	for _, want := range []string{
		"<loc>https://example.com/</loc>",
		"<loc>https://example.com/services/plumbing</loc>",
		"<loc>https://example.com/service/tap-leak</loc>",
		"<loc>https://example.com/privacy</loc>",
	} {
		if !strings.Contains(body, want) {
			t.Errorf("sitemap lacks %s", want)
		}
	}
	if strings.Contains(body, "/admin") || strings.Contains(body, "/jobs") {
		t.Error("sitemap lists private pages")
	}
	robots := get(mux, "/robots.txt").Body.String()
	if !strings.Contains(robots, "Sitemap: https://example.com/sitemap.xml") || !strings.Contains(robots, "Disallow: /admin") {
		t.Fatalf("robots = %s", robots)
	}
}

func TestNoSitemapWithoutAnAddress(t *testing.T) {
	mux := http.NewServeMux()
	SEORoutes(mux, "")
	if rec := get(mux, "/sitemap.xml"); rec.Code != http.StatusNotFound {
		t.Fatalf("sitemap = %d", rec.Code)
	}
	if strings.Contains(get(mux, "/robots.txt").Body.String(), "Sitemap:") {
		t.Fatal("robots points to a sitemap that does not exist")
	}
}
