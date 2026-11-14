// Package analytics counts page views without tracking anyone. The app sends
// the route a page belongs to, such as /service/:id, and the server adds one
// to that day's total. No cookies, user IDs or IP addresses are stored, so
// there is nothing personal to protect or delete, and no consent banner is
// needed.
package analytics

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net"
	"net/http"
	"slices"
	"sort"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
)

// Routes are the pages that are counted. Anything else is ignored, so
// nobody can fill the database with made-up paths.
var Routes = []string{
	"/", "/services", "/services/:slug", "/service/:id", "/guarantee", "/become-provider",
	"/login", "/otp", "/home", "/jobs/new", "/jobs/:id", "/help", "/terms", "/privacy", "/refunds",
}

// Funnel is the path from first visit to posting a job.
var Funnel = []string{"/", "/service/:id", "/login", "/jobs/new"}

const (
	// perMinute caps how fast one address can add views.
	perMinute = 60
	topPages  = 15
)

var nepal = time.FixedZone("NPT", 5*3600+45*60)

type Service struct {
	days *mongo.Collection
	rdb  *redis.Client
	// trustProxy reads the address from X-Forwarded-For, for a server behind
	// a proxy such as Caddy that sets it. Without a proxy it must stay off,
	// or visitors could claim any address.
	trustProxy bool
	now        func() time.Time
}

func NewService(db *mongo.Database, rdb *redis.Client, trustProxy bool) *Service {
	return &Service{days: db.Collection(mongodb.DailyViews), rdb: rdb, trustProxy: trustProxy, now: func() time.Time { return time.Now().UTC() }}
}

// allowed reports whether one more view from this address is fine. The
// address is hashed and forgotten within two minutes.
func (s *Service) allowed(ctx context.Context, r *http.Request) bool {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	if fwd := r.Header.Get("X-Forwarded-For"); s.trustProxy && fwd != "" {
		// The last entry is the one our own proxy added.
		parts := strings.Split(fwd, ",")
		host = strings.TrimSpace(parts[len(parts)-1])
	}
	sum := sha256.Sum256([]byte(host))
	key := fmt.Sprintf("views:%s:%d", hex.EncodeToString(sum[:8]), s.now().Unix()/60)
	n, err := s.rdb.Incr(ctx, key).Result()
	if err != nil {
		// Counting is not worth failing over.
		return false
	}
	if n == 1 {
		s.rdb.Expire(ctx, key, 2*time.Minute)
	}
	return n <= perMinute
}

// Record adds one view of a route to today's total.
func (s *Service) Record(ctx context.Context, route string) error {
	if !slices.Contains(Routes, route) {
		return apperr.BadRequest("unknown_page", "unknown page")
	}
	day := s.now().In(nepal).Format("2006-01-02")
	_, err := s.days.UpdateOne(ctx,
		bson.M{"_id": day + "|" + route},
		bson.M{"$inc": bson.M{"views": 1}, "$setOnInsert": bson.M{"day": day, "route": route}},
		options.UpdateOne().SetUpsert(true))
	if err != nil {
		return fmt.Errorf("record view: %w", err)
	}
	return nil
}

// DayViews is one day's total.
type DayViews struct {
	Date  string `json:"date"`
	Views int64  `json:"views"`
}

// PageViews is one route's total over a period.
type PageViews struct {
	Route string `json:"route"`
	Views int64  `json:"views"`
}

// Traffic is page views over an inclusive range of Nepal days.
type Traffic struct {
	Total  int64       `json:"total_views"`
	Days   []DayViews  `json:"days"`
	Pages  []PageViews `json:"top_pages"`
	Funnel []PageViews `json:"funnel"`
}

// Report sums views between two dates, given as YYYY-MM-DD.
func (s *Service) Report(ctx context.Context, from, to string) (*Traffic, error) {
	cur, err := s.days.Find(ctx, bson.M{"day": bson.M{"$gte": from, "$lte": to}})
	if err != nil {
		return nil, fmt.Errorf("find views: %w", err)
	}
	var rows []struct {
		Day   string `bson:"day"`
		Route string `bson:"route"`
		Views int64  `bson:"views"`
	}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read views: %w", err)
	}
	byDay, byRoute := map[string]int64{}, map[string]int64{}
	t := &Traffic{Days: []DayViews{}, Pages: []PageViews{}, Funnel: []PageViews{}}
	for _, r := range rows {
		byDay[r.Day] += r.Views
		byRoute[r.Route] += r.Views
		t.Total += r.Views
	}
	start, err := time.Parse("2006-01-02", from)
	if err != nil {
		return nil, apperr.BadRequest("invalid_date", "dates must look like 2026-11-13")
	}
	for d := start; d.Format("2006-01-02") <= to; d = d.AddDate(0, 0, 1) {
		key := d.Format("2006-01-02")
		t.Days = append(t.Days, DayViews{Date: key, Views: byDay[key]})
	}
	for route, n := range byRoute {
		t.Pages = append(t.Pages, PageViews{Route: route, Views: n})
	}
	sort.Slice(t.Pages, func(i, j int) bool {
		if t.Pages[i].Views != t.Pages[j].Views {
			return t.Pages[i].Views > t.Pages[j].Views
		}
		return t.Pages[i].Route < t.Pages[j].Route
	})
	if len(t.Pages) > topPages {
		t.Pages = t.Pages[:topPages]
	}
	for _, route := range Funnel {
		t.Funnel = append(t.Funnel, PageViews{Route: route, Views: byRoute[route]})
	}
	return t, nil
}

// Routes registers the public counter. It needs no login, because most
// visitors have none.
func (s *Service) RoutesOn(mux *http.ServeMux) {
	mux.HandleFunc("POST /v1/views", func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Route string `json:"route"`
		}
		if err := httpx.Decode(w, r, &req); err != nil {
			httpx.Error(w, err)
			return
		}
		req.Route = strings.TrimSpace(req.Route)
		if s.allowed(r.Context(), r) {
			if err := s.Record(r.Context(), req.Route); err != nil {
				httpx.Error(w, err)
				return
			}
		}
		w.WriteHeader(http.StatusNoContent)
	})
}
