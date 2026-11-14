package app_test

import (
	"bytes"
	"context"
	"encoding/json"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/wallet"
)

// Enough of a PDF for content sniffing to recognise it.
var (
	pdfBytes = append([]byte("%PDF-1.4\n"), bytes.Repeat([]byte{' '}, 64)...)
)

func (h *harness) upload(a account, path string, data []byte, want int) map[string]any {
	h.t.Helper()
	status, body, _ := h.raw("POST", path, a.access, data)
	if status != want {
		h.t.Fatalf("POST %s = %d, want %d: %s", path, status, want, body)
	}
	var m map[string]any
	json.Unmarshal(body, &m)
	return m
}

func (h *harness) checkStatus(a account) string {
	h.t.Helper()
	v, _ := h.must(200, "GET", "/v1/me", a.access, nil)["verification"].(map[string]any)
	status, _ := v["status"].(string)
	return status
}

func (h *harness) isVerified(id string, viewer account) bool {
	h.t.Helper()
	return h.must(200, "GET", "/v1/providers/"+id, viewer.access, nil)["profile"].(map[string]any)["verified"] == true
}

func TestIdentityCheck(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	seeker := h.login()
	p := h.provider(ktmLat, ktmLng, 2000, plumbing)

	h.upload(seeker, "/v1/me/documents?kind=citizenship_front", pngBytes, 409)
	h.upload(p, "/v1/me/documents?kind=passport", pngBytes, 400)
	// The card must be a photo; certificates may be PDFs.
	h.upload(p, "/v1/me/documents?kind=citizenship_front", pdfBytes, 400)
	h.upload(p, "/v1/me/documents?kind=certificate&label=CTEVT+plumbing", pdfBytes, 201)

	front := h.upload(p, "/v1/me/documents?kind=citizenship_front", pngBytes, 201)["id"].(string)
	h.must(400, "POST", "/v1/me/verification", p.access, nil)
	h.upload(p, "/v1/me/documents?kind=citizenship_back", pngBytes, 201)
	// A second front replaces the first.
	front2 := h.upload(p, "/v1/me/documents?kind=citizenship_front", pngBytes, 201)["id"].(string)
	if n := len(h.must(200, "GET", "/v1/me/documents", p.access, nil)["items"].([]any)); n != 3 {
		t.Fatalf("documents = %d, want 3", n)
	}
	if status, _, _ := h.raw("GET", "/v1/me/documents/"+front, p.access, nil); status != 404 {
		t.Fatalf("replaced document still served: %d", status)
	}

	h.must(200, "POST", "/v1/me/verification", p.access, nil)
	if h.checkStatus(p) != "PENDING" {
		t.Fatal("check not pending")
	}
	h.must(409, "POST", "/v1/me/verification", p.access, nil)
	h.upload(p, "/v1/me/documents?kind=citizenship_back", pngBytes, 409)

	// Documents are private to the owner and admins.
	if status, _, _ := h.raw("GET", "/v1/me/documents/"+front2, seeker.access, nil); status != 404 {
		t.Fatalf("another user read a document: %d", status)
	}
	h.must(403, "GET", "/v1/admin/documents/"+front2, seeker.access, nil)
	status, body, header := h.raw("GET", "/v1/admin/documents/"+front2, admin.access, nil)
	if status != 200 || !bytes.Equal(body, pngBytes) || header.Get("Content-Type") != "image/png" {
		t.Fatalf("admin document read = %d %s", status, header.Get("Content-Type"))
	}
	if got := items(h.must(200, "GET", "/v1/admin/users?filter=checks", admin.access, nil)); len(got) != 1 || got[0]["id"] != p.id {
		t.Fatalf("checks queue = %v", got)
	}

	h.must(400, "POST", "/v1/admin/users/"+p.id+"/verification", admin.access, map[string]any{"approve": false})
	h.must(200, "POST", "/v1/admin/users/"+p.id+"/verification", admin.access, map[string]any{"approve": false, "reason": "The photo is blurred."})
	if h.checkStatus(p) != "REJECTED" || h.isVerified(p.id, seeker) {
		t.Fatal("rejection not recorded")
	}
	h.must(409, "POST", "/v1/admin/users/"+p.id+"/verification", admin.access, map[string]any{"approve": true})

	h.must(200, "POST", "/v1/me/verification", p.access, nil)
	h.must(200, "POST", "/v1/admin/users/"+p.id+"/verification", admin.access, map[string]any{"approve": true})
	if h.checkStatus(p) != "APPROVED" || !h.isVerified(p.id, seeker) {
		t.Fatal("approval did not verify")
	}
	h.deliver(0)
	if h.inboxTypes(p)["provider.verification"] != 2 {
		t.Fatalf("provider told %v", h.inboxTypes(p))
	}

	// Swapping the card after approval takes the badge away.
	h.upload(p, "/v1/me/documents?kind=citizenship_front", pngBytes, 201)
	if h.checkStatus(p) != "" || h.isVerified(p.id, seeker) {
		t.Fatal("badge kept after the card changed")
	}

	rows := items(h.must(200, "GET", "/v1/admin/actions?target="+p.id, admin.access, nil))
	if !hasAction(rows, "provider.check_approve", p.id) || !hasAction(rows, "provider.check_reject", p.id) {
		t.Fatalf("audit = %v", rows)
	}
}

func TestWithdrawals(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	_, p, _ := h.completedJob()
	h.wantBalance(wallet.UserAccount(p.id), 45000)
	esewa := map[string]string{"method": "esewa", "wallet_id": "9812345678", "account_name": "Ram Thapa"}

	status, body := h.call("POST", "/v1/me/withdrawals", p.access, map[string]any{"amount_paisa": 20000, "destination": esewa})
	if status != 403 || errorCode(body) != "verification_required" {
		t.Fatalf("unverified withdrawal = %d %v", status, body)
	}
	h.must(204, "PUT", "/v1/admin/providers/"+p.id+"/verified", admin.access, map[string]bool{"verified": true})

	h.must(400, "POST", "/v1/me/withdrawals", p.access, map[string]any{"amount_paisa": 9999, "destination": esewa})
	h.must(400, "POST", "/v1/me/withdrawals", p.access, map[string]any{"amount_paisa": 20000,
		"destination": map[string]string{"method": "esewa", "wallet_id": "12345", "account_name": "Ram"}})
	h.must(400, "POST", "/v1/me/withdrawals", p.access, map[string]any{"amount_paisa": 20000,
		"destination": map[string]string{"method": "bank", "bank_name": "NIC Asia", "account_name": "Ram", "account_number": "12-ab"}})
	h.must(409, "POST", "/v1/me/withdrawals", p.access, map[string]any{"amount_paisa": 45001, "destination": esewa})
	h.wantBalance(wallet.UserAccount(p.id), 45000)

	first := h.must(201, "POST", "/v1/me/withdrawals", p.access, map[string]any{"amount_paisa": 30000, "destination": esewa})["id"].(string)
	h.wantBalance(wallet.UserAccount(p.id), 15000)
	h.wantBalance(wallet.WithdrawalAccount(first), 30000)
	status, body = h.call("POST", "/v1/me/withdrawals", p.access, map[string]any{"amount_paisa": 10000, "destination": esewa})
	if status != 409 || errorCode(body) != "withdrawal_waiting" {
		t.Fatalf("second withdrawal = %d %v", status, body)
	}

	e := h.must(200, "GET", "/v1/me/earnings", p.access, nil)
	if e["available_paisa"].(float64) != 15000 || e["withdrawing_paisa"].(float64) != 30000 ||
		e["total_earned_paisa"].(float64) != 45000 || e["commission_paid_paisa"].(float64) != 5000 ||
		e["jobs_paid"].(float64) != 1 || e["this_month_paisa"].(float64) != 45000 {
		t.Fatalf("earnings = %v", e)
	}
	if m := h.must(200, "GET", "/v1/admin/money", admin.access, nil); m["withdrawals_waiting_paisa"].(float64) != 30000 || m["healthy"] != true {
		t.Fatalf("money = %v", m)
	}

	queue := items(h.must(200, "GET", "/v1/admin/withdrawals?status=PENDING", admin.access, nil))
	if len(queue) != 1 || queue[0]["person"].(map[string]any)["id"] != p.id || queue[0]["verified"] != true {
		t.Fatalf("queue = %v", queue)
	}
	h.must(400, "POST", "/v1/admin/withdrawals/"+first+"/pay", admin.access, map[string]string{"note": " "})
	h.must(403, "POST", "/v1/admin/withdrawals/"+first+"/pay", p.access, map[string]string{"note": "self"})
	h.must(200, "POST", "/v1/admin/withdrawals/"+first+"/pay", admin.access, map[string]string{"note": "ESW-7781"})
	h.must(409, "POST", "/v1/admin/withdrawals/"+first+"/refuse", admin.access, map[string]string{"note": "late"})
	h.wantBalance(wallet.WithdrawalAccount(first), 0)
	h.wantBalance(wallet.UserAccount(p.id), 15000)

	second := h.must(201, "POST", "/v1/me/withdrawals", p.access, map[string]any{"amount_paisa": 10000,
		"destination": map[string]string{"method": "bank", "bank_name": "NIC Asia Bank", "account_name": "Ram Thapa", "account_number": "0123 4567 8901"}})["id"].(string)
	h.must(200, "POST", "/v1/admin/withdrawals/"+second+"/refuse", admin.access, map[string]string{"note": "The account name does not match your ID."})
	h.wantBalance(wallet.UserAccount(p.id), 15000)
	h.assertBooksBalance()

	h.deliver(0)
	if h.inboxTypes(p)["wallet.withdrawal"] != 2 {
		t.Fatalf("provider told %v", h.inboxTypes(p))
	}
	rows := items(h.must(200, "GET", "/v1/admin/actions?target="+p.id, admin.access, nil))
	if !hasAction(rows, "withdrawal.paid", p.id) || !hasAction(rows, "withdrawal.refused", p.id) {
		t.Fatalf("audit = %v", rows)
	}
	today := time.Now().In(time.FixedZone("NPT", 5*3600+45*60)).Format("2006-01-02")
	rep := h.must(200, "GET", "/v1/admin/reports?from="+today+"&to="+today, admin.access, nil)
	if rep["totals"].(map[string]any)["withdrawals_paisa"].(float64) != 30000 {
		t.Fatalf("report = %v", rep["totals"])
	}
}

// nextWeekday returns a date 2 to 8 days ahead, and its weekday key.
func nextWeekday() (string, string) {
	d := time.Now().UTC().AddDate(0, 0, 3)
	return d.Format("2006-01-02"), []string{"sun", "mon", "tue", "wed", "thu", "fri", "sat"}[d.Weekday()]
}

func (h *harness) eligible(jobID string) map[string]bool {
	h.t.Helper()
	var j struct {
		Eligible []string `bson:"eligible_provider_ids"`
	}
	if err := h.db.Collection(mongodb.Jobs).FindOne(context.Background(), bson.M{"_id": jobID}).Decode(&j); err != nil {
		h.t.Fatal(err)
	}
	out := map[string]bool{}
	for _, id := range j.Eligible {
		out[id] = true
	}
	return out
}

func TestAvailabilityLimitsWhoIsOffered(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	busy := h.provider(ktmLat, ktmLng, 2000, plumbing)
	anytime := h.provider(ktmLat, ktmLng, 2000, plumbing)
	date, day := nextWeekday()

	h.must(400, "PUT", "/v1/me/availability", busy.access, map[string]any{"weekly": map[string][]string{"funday": {"08-10"}}, "days_off": []string{}})
	h.must(400, "PUT", "/v1/me/availability", busy.access, map[string]any{"weekly": map[string][]string{"mon": {"07-09"}}, "days_off": []string{}})
	h.must(400, "PUT", "/v1/me/availability", busy.access, map[string]any{"weekly": map[string][]string{}, "days_off": []string{}})
	h.must(409, "PUT", "/v1/me/availability", seeker.access, map[string]any{"weekly": map[string][]string{"mon": {"08-10"}}, "days_off": []string{}})
	a := h.must(200, "PUT", "/v1/me/availability", busy.access, map[string]any{
		"weekly":   map[string][]string{day: {"08-10"}},
		"days_off": []string{"2020-01-01"},
	})
	if len(a["days_off"].([]any)) != 0 {
		t.Fatalf("past day off kept: %v", a)
	}

	post := func(date, slot string) string {
		return h.must(201, "POST", "/v1/jobs", seeker.access, map[string]any{
			"category_id": plumbing, "description": "Leaking tap", "address": "Baneshwor",
			"lat": ktmLat, "lng": ktmLng, "preferred_date": date, "preferred_slot": slot,
		})["id"].(string)
	}
	if got := h.eligible(post(date, "08-10")); !got[busy.id] || !got[anytime.id] {
		t.Fatalf("slot they work: %v", got)
	}
	if got := h.eligible(post(date, "10-12")); got[busy.id] || !got[anytime.id] {
		t.Fatalf("slot they do not work: %v", got)
	}
	if got := h.eligible(post("", "")); !got[busy.id] {
		t.Fatalf("as soon as possible: %v", got)
	}

	h.must(200, "PUT", "/v1/me/availability", busy.access, map[string]any{
		"weekly": map[string][]string{day: {"08-10"}}, "days_off": []string{date},
	})
	if got := h.eligible(post(date, "08-10")); got[busy.id] {
		t.Fatalf("day off: %v", got)
	}
	if h.must(200, "GET", "/v1/providers/"+busy.id, seeker.access, nil)["profile"].(map[string]any)["availability"] == nil {
		t.Fatal("schedule not shown to customers")
	}

	h.must(204, "DELETE", "/v1/me/availability", busy.access, nil)
	if got := h.eligible(post(date, "10-12")); !got[busy.id] {
		t.Fatalf("cleared schedule: %v", got)
	}
}

func TestGallery(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	p := h.provider(ktmLat, ktmLng, 2000, plumbing)

	h.upload(seeker, "/v1/me/gallery", pngBytes, 409)
	h.upload(p, "/v1/me/gallery", pdfBytes, 400)
	id := h.upload(p, "/v1/me/gallery?caption=New+bathroom+fittings", pngBytes, 201)["id"].(string)

	rows := h.must(200, "GET", "/v1/providers/"+p.id+"/gallery", seeker.access, nil)["items"].([]any)
	if len(rows) != 1 || rows[0].(map[string]any)["caption"] != "New bathroom fittings" {
		t.Fatalf("gallery = %v", rows)
	}
	status, body, _ := h.raw("GET", "/v1/providers/"+p.id+"/gallery/"+id, seeker.access, nil)
	if status != 200 || !bytes.Equal(body, pngBytes) {
		t.Fatalf("photo = %d", status)
	}
	h.must(404, "DELETE", "/v1/me/gallery/"+id, seeker.access, nil)
	h.must(204, "DELETE", "/v1/me/gallery/"+id, p.access, nil)
	if rows := h.must(200, "GET", "/v1/providers/"+p.id+"/gallery", seeker.access, nil)["items"].([]any); len(rows) != 0 {
		t.Fatalf("gallery after delete = %v", rows)
	}
}
