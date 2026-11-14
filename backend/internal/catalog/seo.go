package catalog

import (
	"encoding/xml"
	"fmt"
	"net/http"
	"strings"
)

// publicPages are the pages anyone can visit, for search engines.
var publicPages = []string{"/", "/services", "/guarantee", "/become-provider", "/terms", "/privacy", "/refunds"}

type urlEntry struct {
	Loc string `xml:"loc"`
}

type urlSet struct {
	XMLName xml.Name   `xml:"urlset"`
	Xmlns   string     `xml:"xmlns,attr"`
	URLs    []urlEntry `xml:"url"`
}

// SEORoutes serves robots.txt and a sitemap built from the live catalogue,
// so new services reach search engines without a release. siteURL is the
// public address, such as https://subidha360.com; without it the sitemap is
// off, because a sitemap must use full addresses.
func SEORoutes(mux *http.ServeMux, siteURL string) {
	siteURL = strings.TrimRight(siteURL, "/")
	mux.HandleFunc("GET /robots.txt", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		// Signed-in pages and the API have nothing for search engines.
		body := "User-agent: *\nDisallow: /home\nDisallow: /jobs\nDisallow: /admin\nDisallow: /provider/\nDisallow: /help\nDisallow: /v1/\n"
		if siteURL != "" {
			body += "\nSitemap: " + siteURL + "/sitemap.xml\n"
		}
		fmt.Fprint(w, body)
	})
	mux.HandleFunc("GET /sitemap.xml", func(w http.ResponseWriter, _ *http.Request) {
		if siteURL == "" {
			http.NotFound(w, nil)
			return
		}
		set := urlSet{Xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9"}
		for _, p := range publicPages {
			set.URLs = append(set.URLs, urlEntry{Loc: siteURL + p})
		}
		for _, c := range Public() {
			set.URLs = append(set.URLs, urlEntry{Loc: siteURL + "/services/" + c.Slug})
			for _, s := range c.Services {
				set.URLs = append(set.URLs, urlEntry{Loc: siteURL + "/service/" + s.ID})
			}
		}
		w.Header().Set("Content-Type", "application/xml; charset=utf-8")
		fmt.Fprint(w, xml.Header)
		xml.NewEncoder(w).Encode(set)
	})
}
