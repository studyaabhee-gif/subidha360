package app_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"regexp"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"subidha360/backend/internal/app"
	"subidha360/backend/internal/config"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/wallet"
)

// Kathmandu, plus a point about 3.3 km north of a 2 km service area around it.
const (
	ktmLat, ktmLng     = 27.7172, 85.3240
	nearbyLat, nearLng = 27.7650, 85.3240
	farLat, farLng     = 28.2096, 83.9856 // Pokhara
	plumbing           = 7
	electrical         = 8
)

type captureSMS struct {
	mu   sync.Mutex
	last map[string]string
	// alerts holds non-OTP messages by phone.
	alerts map[string][]string
	// fail makes alert delivery return an error.
	fail bool
}

var digits = regexp.MustCompile(`\d{6}`)

func (c *captureSMS) Send(_ context.Context, phone, message string) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	code := digits.FindString(message)
	if code != "" {
		c.last[phone] = code
		return nil
	}
	if c.fail {
		return errors.New("sms gateway down")
	}
	c.alerts[phone] = append(c.alerts[phone], message)
	return nil
}

func (c *captureSMS) code(phone string) string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.last[phone]
}

type harness struct {
	t     *testing.T
	srv   *httptest.Server
	app   *app.App
	sms   *captureSMS
	push  *fakePusher
	db    *mongo.Database
	redis *miniredis.Miniredis
	phone atomic.Int64
}

func (h *harness) clearCooldown(phone string) {
	h.redis.Del("otp:cooldown:" + phone)
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	uri := os.Getenv("TEST_MONGO_URI")
	if uri == "" {
		t.Skip("TEST_MONGO_URI not set; needs a MongoDB replica set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	client, err := mongodb.Connect(ctx, uri)
	if err != nil {
		t.Fatal(err)
	}
	name := "test_" + uuid.NewString()[:8]
	t.Cleanup(func() {
		client.Database(name).Drop(context.Background())
		client.Disconnect(context.Background())
	})

	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { rdb.Close() })

	sms := &captureSMS{last: map[string]string{}, alerts: map[string][]string{}}
	push := &fakePusher{errs: map[string]error{}}
	a, err := app.New(ctx, app.Deps{
		Config: config.Config{
			Env:                config.EnvDevelopment,
			MongoDB:            name,
			JWTSecret:          "test-secret-test-secret-test-secret",
			AccessTTL:          15 * time.Minute,
			RefreshTTL:         time.Hour,
			OTPTTL:             5 * time.Minute,
			BidWindow:          5 * time.Minute,
			SelectionWindow:    24 * time.Hour,
			AutoReleaseAfter:   72 * time.Hour,
			EscrowReviewWindow: 72 * time.Hour,
			WarrantyDays:       30,
			EscalationMeters:   5000,
			CommissionBPS:      1000,
		},
		Mongo: client,
		Redis: rdb,
		SMS:   sms,
		Push:  push,
	})
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(a.Handler)
	t.Cleanup(srv.Close)
	return &harness{t: t, srv: srv, app: a, sms: sms, push: push, db: client.Database(name), redis: mr}
}

// call sends a request and returns the status and decoded JSON body.
func (h *harness) call(method, path, token string, body any) (int, map[string]any) {
	h.t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			h.t.Fatal(err)
		}
	}
	req, err := http.NewRequest(method, h.srv.URL+path, &buf)
	if err != nil {
		h.t.Fatal(err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		h.t.Fatal(err)
	}
	defer res.Body.Close()
	var out any
	json.NewDecoder(res.Body).Decode(&out)
	m, _ := out.(map[string]any)
	if list, ok := out.([]any); ok {
		m = map[string]any{"items": list}
	}
	return res.StatusCode, m
}

// must is call plus a status assertion.
func (h *harness) must(want int, method, path, token string, body any) map[string]any {
	h.t.Helper()
	status, m := h.call(method, path, token, body)
	if status != want {
		h.t.Fatalf("%s %s = %d, want %d: %v", method, path, status, want, m)
	}
	return m
}

type account struct {
	id, phone, access, refresh string
}

func (h *harness) login() account {
	h.t.Helper()
	phone := fmt.Sprintf("+9779%09d", h.phone.Add(1))
	h.must(204, "POST", "/v1/auth/otp/request", "", map[string]string{"phone": phone})
	m := h.must(200, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": phone, "code": h.sms.code(phone)})
	tokens := m["tokens"].(map[string]any)
	return account{
		id:      m["user"].(map[string]any)["id"].(string),
		phone:   phone,
		access:  tokens["access_token"].(string),
		refresh: tokens["refresh_token"].(string),
	}
}

func (h *harness) provider(lat, lng, meters float64, categories ...int) account {
	h.t.Helper()
	a := h.login()
	h.must(200, "PUT", "/v1/me/provider-profile", a.access, map[string]any{
		"category_ids": categories,
		"radius":       map[string]float64{"lat": lat, "lng": lng, "meters": meters},
	})
	return a
}

func (h *harness) topUp(a account, paisa int64) {
	h.t.Helper()
	h.must(204, "POST", "/v1/dev/wallet/top-up", a.access, map[string]int64{"amount_paisa": paisa})
}

func (h *harness) createJob(a account, lat, lng float64, category int) string {
	h.t.Helper()
	m := h.must(201, "POST", "/v1/jobs", a.access, map[string]any{
		"category_id": category, "description": "Leaking tap", "address": "Baneshwor", "lat": lat, "lng": lng,
	})
	return m["id"].(string)
}

func (h *harness) bid(p account, jobID string, paisa int64) string {
	h.t.Helper()
	m := h.must(201, "POST", "/v1/jobs/"+jobID+"/bids", p.access, map[string]int64{"amount_paisa": paisa})
	return m["id"].(string)
}

func (h *harness) jobStatus(a account, jobID string) string {
	h.t.Helper()
	return h.must(200, "GET", "/v1/jobs/"+jobID, a.access, nil)["status"].(string)
}

func (h *harness) balance(account string) int64 {
	h.t.Helper()
	b, err := h.app.Ledger.AccountBalance(context.Background(), account)
	if err != nil {
		h.t.Fatal(err)
	}
	return b
}

func (h *harness) wantBalance(account string, want int64) {
	h.t.Helper()
	if got := h.balance(account); got != want {
		h.t.Fatalf("balance of %s = %d, want %d", account, got, want)
	}
}

// assertBooksBalance checks the invariants that define a sound ledger: every
// group sums to zero, and every account balance equals the sum of its entries.
func (h *harness) assertBooksBalance() {
	h.t.Helper()
	ctx := context.Background()
	var rows []struct {
		Group   string `bson:"group_key"`
		Account string `bson:"account_id"`
		Amount  int64  `bson:"amount"`
	}
	cur, err := h.db.Collection(mongodb.WalletLedger).Find(ctx, bson.M{})
	if err != nil {
		h.t.Fatal(err)
	}
	if err := cur.All(ctx, &rows); err != nil {
		h.t.Fatal(err)
	}
	groups := map[string]int64{}
	accounts := map[string]int64{}
	for _, r := range rows {
		groups[r.Group] += r.Amount
		accounts[r.Account] += r.Amount
	}
	for g, sum := range groups {
		if sum != 0 {
			h.t.Errorf("group %s sums to %d", g, sum)
		}
	}
	for a, sum := range accounts {
		if got := h.balance(a); got != sum {
			h.t.Errorf("account %s balance %d, ledger says %d", a, got, sum)
		}
	}
}

func feedIDs(m map[string]any) map[string]bool {
	ids := map[string]bool{}
	items, _ := m["items"].([]any)
	for _, it := range items {
		ids[it.(map[string]any)["id"].(string)] = true
	}
	return ids
}

func TestFullLifecycleSettlesEscrow(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 100000)

	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	if !feedIDs(h.must(200, "GET", "/v1/jobs/feed", provider.access, nil))[jobID] {
		t.Fatal("job missing from provider feed")
	}

	bidID := h.bid(provider, jobID, 50000)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", seeker.access, nil)
	h.wantBalance(wallet.UserAccount(seeker.id), 50000)
	h.wantBalance(wallet.EscrowAccount(jobID), 50000)

	h.must(200, "POST", "/v1/jobs/"+jobID+"/start", provider.access, nil)

	m := h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", seeker.access, nil)
	if m["status"] != "IN_PROGRESS" {
		t.Fatalf("one confirmation must not complete the job: %v", m["status"])
	}
	h.wantBalance(wallet.UserAccount(provider.id), 0)

	m = h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	if m["status"] != "COMPLETED" {
		t.Fatalf("status = %v", m["status"])
	}
	h.wantBalance(wallet.EscrowAccount(jobID), 0)
	h.wantBalance(wallet.UserAccount(provider.id), 45000)
	h.wantBalance(wallet.AccountCommission, 5000)
	h.assertBooksBalance()
}

func TestAcceptWithoutFundsChangesNothing(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 1000)

	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	bidID := h.bid(provider, jobID, 50000)
	h.must(409, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", seeker.access, nil)

	if got := h.jobStatus(seeker, jobID); got != "BROADCASTING" {
		t.Fatalf("status = %s", got)
	}
	bids := h.must(200, "GET", "/v1/jobs/"+jobID+"/bids", seeker.access, nil)["items"].([]any)
	if s := bids[0].(map[string]any)["status"]; s != "PENDING" {
		t.Fatalf("bid status = %v", s)
	}
	h.wantBalance(wallet.UserAccount(seeker.id), 1000)
	h.assertBooksBalance()
}

func TestConcurrentAcceptsCannotOverdraw(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 50000) // Enough for exactly one of the jobs.

	const n = 6
	paths := make([]string, n)
	for i := range paths {
		jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
		paths[i] = "/v1/jobs/" + jobID + "/bids/" + h.bid(provider, jobID, 50000) + "/accept"
	}

	var ok, refused atomic.Int64
	var wg sync.WaitGroup
	for _, p := range paths {
		wg.Go(func() {
			switch status, _ := h.call("POST", p, seeker.access, nil); status {
			case 200:
				ok.Add(1)
			case 409:
				refused.Add(1)
			default:
				t.Errorf("unexpected status %d", status)
			}
		})
	}
	wg.Wait()

	if ok.Load() != 1 || refused.Load() != n-1 {
		t.Fatalf("ok=%d refused=%d", ok.Load(), refused.Load())
	}
	h.wantBalance(wallet.UserAccount(seeker.id), 0)
	h.assertBooksBalance()
}

func TestConcurrentAcceptOfTwoBidsPicksOneWinner(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	p1 := h.provider(ktmLat, ktmLng, 2000, plumbing)
	p2 := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 200000)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	b1, b2 := h.bid(p1, jobID, 50000), h.bid(p2, jobID, 60000)

	var ok atomic.Int64
	var wg sync.WaitGroup
	for _, b := range []string{b1, b2} {
		wg.Go(func() {
			if status, _ := h.call("POST", "/v1/jobs/"+jobID+"/bids/"+b+"/accept", seeker.access, nil); status == 200 {
				ok.Add(1)
			}
		})
	}
	wg.Wait()

	if ok.Load() != 1 {
		t.Fatalf("%d bids accepted", ok.Load())
	}
	h.assertBooksBalance()
}

func TestConcurrentConfirmationsSettleOnce(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 50000)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/bids/"+h.bid(provider, jobID, 50000)+"/accept", seeker.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/start", provider.access, nil)

	var wg sync.WaitGroup
	for _, a := range []account{seeker, provider} {
		wg.Go(func() { h.call("POST", "/v1/jobs/"+jobID+"/confirm", a.access, nil) })
	}
	wg.Wait()

	if got := h.jobStatus(seeker, jobID); got != "COMPLETED" {
		t.Fatalf("status = %s", got)
	}
	h.wantBalance(wallet.UserAccount(provider.id), 45000)
	h.assertBooksBalance()
}

func TestPostingIsIdempotent(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	ctx := context.Background()
	if err := h.app.Ledger.TopUp(ctx, seeker.id, 5000, "esewa-123"); err != nil {
		t.Fatal(err)
	}
	if err := h.app.Ledger.TopUp(ctx, seeker.id, 5000, "esewa-123"); err == nil {
		t.Fatal("replayed top-up must fail")
	}
	h.wantBalance(wallet.UserAccount(seeker.id), 5000)
	h.assertBooksBalance()
}

func TestCancelBeforeWorkRefundsSeeker(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 50000)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/bids/"+h.bid(provider, jobID, 50000)+"/accept", seeker.access, nil)

	h.must(400, "POST", "/v1/jobs/"+jobID+"/cancel", provider.access, map[string]string{"reason": "  "})
	m := h.must(200, "POST", "/v1/jobs/"+jobID+"/cancel", provider.access, map[string]string{"reason": "Van broke down"})

	if m["status"] != "CANCELLED" {
		t.Fatalf("status = %v", m["status"])
	}
	if r := m["cancellation"].(map[string]any)["review"]; r != "PENDING" {
		t.Fatalf("review = %v", r)
	}
	h.wantBalance(wallet.UserAccount(seeker.id), 50000)
	h.wantBalance(wallet.EscrowAccount(jobID), 0)
	h.assertBooksBalance()
}

func TestCancelDuringWorkKeepsEscrowForReview(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 50000)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/bids/"+h.bid(provider, jobID, 50000)+"/accept", seeker.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/start", provider.access, nil)

	m := h.must(200, "POST", "/v1/jobs/"+jobID+"/cancel", seeker.access, map[string]string{"reason": "Dispute"})

	if m["escrow_review_required"] != true {
		t.Fatal("job must be flagged for escrow review")
	}
	h.wantBalance(wallet.EscrowAccount(jobID), 50000)
	h.wantBalance(wallet.UserAccount(seeker.id), 0)
	h.assertBooksBalance()
}

func TestCancelOpenJobRejectsBids(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.bid(provider, jobID, 50000)

	// A provider who only bid is not a party to the job.
	h.must(403, "POST", "/v1/jobs/"+jobID+"/cancel", provider.access, map[string]string{"reason": "No"})
	h.must(200, "POST", "/v1/jobs/"+jobID+"/cancel", seeker.access, map[string]string{"reason": "Fixed it"})

	bids := h.must(200, "GET", "/v1/jobs/"+jobID+"/bids", seeker.access, nil)["items"].([]any)
	if s := bids[0].(map[string]any)["status"]; s != "REJECTED" {
		t.Fatalf("bid status = %v", s)
	}
	h.must(409, "POST", "/v1/jobs/"+jobID+"/cancel", seeker.access, map[string]string{"reason": "Again"})
}

func TestMatchingFiltersProviders(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	covering := h.provider(ktmLat, ktmLng, 2000, plumbing)
	wrongCategory := h.provider(ktmLat, ktmLng, 2000, electrical)
	elsewhere := h.provider(farLat, farLng, 2000, plumbing)
	offline := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.must(204, "PUT", "/v1/me/online", offline.access, map[string]bool{"online": false})

	polygon := h.login()
	h.must(200, "PUT", "/v1/me/provider-profile", polygon.access, map[string]any{
		"category_ids": []int{plumbing},
		"polygon":      [][2]float64{{85.30, 27.70}, {85.35, 27.70}, {85.35, 27.74}, {85.30, 27.74}},
	})

	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)

	for name, tc := range map[string]struct {
		a    account
		want bool
	}{
		"covering":       {covering, true},
		"polygon":        {polygon, true},
		"wrong category": {wrongCategory, false},
		"elsewhere":      {elsewhere, false},
		"offline":        {offline, false},
	} {
		got := feedIDs(h.must(200, "GET", "/v1/jobs/feed", tc.a.access, nil))[jobID]
		if got != tc.want {
			t.Errorf("%s: in feed = %v, want %v", name, got, tc.want)
		}
	}

	h.must(409, "POST", "/v1/jobs/"+jobID+"/bids", elsewhere.access, map[string]int64{"amount_paisa": 100})
	h.must(404, "GET", "/v1/jobs/"+jobID, elsewhere.access, nil)
}

func TestSeekerDoesNotMatchOwnJob(t *testing.T) {
	h := newHarness(t)
	both := h.provider(ktmLat, ktmLng, 2000, plumbing)
	jobID := h.createJob(both, ktmLat, ktmLng, plumbing)
	if feedIDs(h.must(200, "GET", "/v1/jobs/feed", both.access, nil))[jobID] {
		t.Fatal("seeker must not be offered their own job")
	}
}

func TestDuplicateBidRefused(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.bid(provider, jobID, 50000)
	h.must(409, "POST", "/v1/jobs/"+jobID+"/bids", provider.access, map[string]int64{"amount_paisa": 40000})

	m := h.must(200, "GET", "/v1/jobs/"+jobID, seeker.access, nil)
	if m["bid_count"] != float64(1) {
		t.Fatalf("bid_count = %v", m["bid_count"])
	}
}

func TestProvidersSeeOnlyTheirOwnBids(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	p1 := h.provider(ktmLat, ktmLng, 2000, plumbing)
	p2 := h.provider(ktmLat, ktmLng, 2000, plumbing)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.bid(p1, jobID, 50000)
	h.bid(p2, jobID, 40000)

	if n := len(h.must(200, "GET", "/v1/jobs/"+jobID+"/bids", p1.access, nil)["items"].([]any)); n != 1 {
		t.Fatalf("provider saw %d bids", n)
	}
	if n := len(h.must(200, "GET", "/v1/jobs/"+jobID+"/bids", seeker.access, nil)["items"].([]any)); n != 2 {
		t.Fatalf("seeker saw %d bids", n)
	}
}

func TestOnlySeekerCanAcceptAndOnlyProviderCanStart(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 50000)
	h.topUp(provider, 50000)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	bidID := h.bid(provider, jobID, 50000)

	h.must(409, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", provider.access, nil)
	h.wantBalance(wallet.UserAccount(provider.id), 50000)

	h.must(200, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", seeker.access, nil)
	h.must(409, "POST", "/v1/jobs/"+jobID+"/start", seeker.access, nil)
}

func TestEscalationReachesNearbyProvidersThenFallsBack(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	// Its service area stops about 3.3 km short of the job.
	nearby := h.provider(nearbyLat, nearLng, 2000, plumbing)
	distant := h.provider(farLat, farLng, 2000, plumbing)

	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	otherJob := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	if feedIDs(h.must(200, "GET", "/v1/jobs/feed", nearby.access, nil))[jobID] {
		t.Fatal("nearby provider should not match before escalation")
	}

	ctx := context.Background()
	if err := h.app.Jobs.AdvanceExpired(ctx, time.Now()); err != nil {
		t.Fatal(err)
	}
	if got := h.jobStatus(seeker, jobID); got != "BROADCASTING" {
		t.Fatalf("window still open, status = %s", got)
	}

	later := time.Now().Add(6 * time.Minute)
	if err := h.app.Jobs.AdvanceExpired(ctx, later); err != nil {
		t.Fatal(err)
	}
	if got := h.jobStatus(seeker, jobID); got != "ESCALATING" {
		t.Fatalf("status = %s", got)
	}
	feed := feedIDs(h.must(200, "GET", "/v1/jobs/feed", nearby.access, nil))
	if !feed[jobID] {
		t.Fatal("nearby provider should match after escalation")
	}
	if feedIDs(h.must(200, "GET", "/v1/jobs/feed", distant.access, nil))[jobID] {
		t.Fatal("distant provider should not match after escalation")
	}

	// A bid on one job keeps it open while the other falls back.
	h.bid(nearby, otherJob, 30000)
	if err := h.app.Jobs.AdvanceExpired(ctx, later.Add(6*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if got := h.jobStatus(seeker, jobID); got != "MANUAL_FALLBACK" {
		t.Fatalf("status = %s", got)
	}
	if got := h.jobStatus(seeker, otherJob); got != "ESCALATING" {
		t.Fatalf("job with a bid must stay open, status = %s", got)
	}
}

func TestAllExpiredEscalatingJobsFallBack(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	jobs := []string{
		h.createJob(seeker, ktmLat, ktmLng, plumbing),
		h.createJob(seeker, ktmLat, ktmLng, plumbing),
		h.createJob(seeker, ktmLat, ktmLng, plumbing),
	}
	ctx := context.Background()
	for _, offset := range []time.Duration{6 * time.Minute, 12 * time.Minute} {
		if err := h.app.Jobs.AdvanceExpired(ctx, time.Now().Add(offset)); err != nil {
			t.Fatal(err)
		}
	}
	for _, id := range jobs {
		if got := h.jobStatus(seeker, id); got != "MANUAL_FALLBACK" {
			t.Errorf("job %s status = %s", id, got)
		}
	}
}

func TestInvalidPolygonRefused(t *testing.T) {
	h := newHarness(t)
	a := h.login()
	// A bowtie: its edges cross, so it is not valid GeoJSON.
	h.must(400, "PUT", "/v1/me/provider-profile", a.access, map[string]any{
		"category_ids": []int{plumbing},
		"polygon":      [][2]float64{{85.30, 27.70}, {85.35, 27.74}, {85.35, 27.70}, {85.30, 27.74}},
	})
}

func TestOTPRules(t *testing.T) {
	h := newHarness(t)
	const phone = "+9779812345678"

	h.must(400, "POST", "/v1/auth/otp/request", "", map[string]string{"phone": "12345"})
	h.must(204, "POST", "/v1/auth/otp/request", "", map[string]string{"phone": phone})
	h.must(429, "POST", "/v1/auth/otp/request", "", map[string]string{"phone": phone})

	code := h.sms.code(phone)
	wrong := "000000"
	if code == wrong {
		wrong = "000001"
	}
	h.must(401, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": phone, "code": wrong})
	h.must(200, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": phone, "code": code})
	h.must(401, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": phone, "code": code})
}

func TestOTPLocksAfterTooManyGuesses(t *testing.T) {
	h := newHarness(t)
	const phone = "+9779812345679"
	h.must(204, "POST", "/v1/auth/otp/request", "", map[string]string{"phone": phone})
	code := h.sms.code(phone)
	wrong := "000000"
	if code == wrong {
		wrong = "000001"
	}
	for range 5 {
		h.must(401, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": phone, "code": wrong})
	}
	h.must(429, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": phone, "code": code})
}

func TestSameUserOnSecondLogin(t *testing.T) {
	h := newHarness(t)
	const phone = "+9779812345670"
	ids := make([]string, 2)
	for i := range ids {
		h.must(204, "POST", "/v1/auth/otp/request", "", map[string]string{"phone": phone})
		m := h.must(200, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": phone, "code": h.sms.code(phone)})
		ids[i] = m["user"].(map[string]any)["id"].(string)
		// Clear the resend cooldown without waiting a minute.
		h.clearCooldown(phone)
	}
	if ids[0] != ids[1] {
		t.Fatalf("second login created a new user: %v", ids)
	}
}

func TestRefreshRotatesAndLogoutRevokes(t *testing.T) {
	h := newHarness(t)
	a := h.login()

	h.must(401, "GET", "/v1/me", a.refresh, nil) // A refresh token is not an access token.
	h.must(401, "POST", "/v1/auth/refresh", "", map[string]string{"refresh_token": a.access})

	pair := h.must(200, "POST", "/v1/auth/refresh", "", map[string]string{"refresh_token": a.refresh})
	h.must(401, "POST", "/v1/auth/refresh", "", map[string]string{"refresh_token": a.refresh})

	access, refresh := pair["access_token"].(string), pair["refresh_token"].(string)
	h.must(200, "GET", "/v1/me", access, nil)
	h.must(204, "POST", "/v1/auth/logout", access, map[string]string{"refresh_token": refresh})
	h.must(401, "GET", "/v1/me", access, nil)
	h.must(401, "POST", "/v1/auth/refresh", "", map[string]string{"refresh_token": refresh})
}

func TestProtectedRoutesNeedAToken(t *testing.T) {
	h := newHarness(t)
	h.must(401, "GET", "/v1/me", "", nil)
	h.must(401, "GET", "/v1/me", "not-a-token", nil)
	h.must(401, "POST", "/v1/jobs", "", map[string]any{})
	h.must(401, "GET", "/v1/wallet", "", nil)
}
