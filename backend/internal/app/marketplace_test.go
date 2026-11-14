package app_test

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/platform/mongodb"
)

// completedJob returns a finished job, leaving the provider paid.
func (h *harness) completedJob() (seeker, provider account, jobID string) {
	h.t.Helper()
	seeker, provider, jobID = h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", seeker.access, nil)
	return seeker, provider, jobID
}

func review(rating int) map[string]any {
	return map[string]any{"rating": rating, "tags": []string{"On time"}, "comment": "Great work"}
}

func TestCatalogIsPublic(t *testing.T) {
	h := newHarness(t)
	m := h.must(200, "GET", "/v1/catalog", "", nil)
	if len(m["items"].([]any)) < 6 {
		t.Fatalf("catalog = %v", m)
	}
}

func TestJobsMustUseRealServices(t *testing.T) {
	h := newHarness(t)
	a := h.login()
	base := map[string]any{"description": "x", "address": "y", "lat": ktmLat, "lng": ktmLng}
	with := func(extra map[string]any) map[string]any {
		out := map[string]any{}
		for k, v := range base {
			out[k] = v
		}
		for k, v := range extra {
			out[k] = v
		}
		return out
	}

	h.must(400, "POST", "/v1/jobs", a.access, with(map[string]any{"category_id": 999}))
	h.must(400, "POST", "/v1/jobs", a.access, with(map[string]any{"category_id": 2, "service_id": "tap-leak"}))
	h.must(201, "POST", "/v1/jobs", a.access, with(map[string]any{"category_id": 1, "service_id": "tap-leak"}))
}

func TestSchedulingRules(t *testing.T) {
	h := newHarness(t)
	a := h.login()
	job := func(date, slot string) map[string]any {
		return map[string]any{
			"category_id": 1, "description": "x", "address": "y", "lat": ktmLat, "lng": ktmLng,
			"preferred_date": date, "preferred_slot": slot,
		}
	}
	day := func(n int) string { return time.Now().AddDate(0, 0, n).Format(time.DateOnly) }

	m := h.must(201, "POST", "/v1/jobs", a.access, job(day(2), "10-12"))
	if m["preferred_slot"] != "10-12" || m["preferred_date"] != day(2) {
		t.Fatalf("schedule not stored: %v", m)
	}
	h.must(201, "POST", "/v1/jobs", a.access, job("", ""))
	h.must(400, "POST", "/v1/jobs", a.access, job(day(2), "03-05"))
	h.must(400, "POST", "/v1/jobs", a.access, job(day(2), ""))
	h.must(400, "POST", "/v1/jobs", a.access, job(day(-5), "10-12"))
	h.must(400, "POST", "/v1/jobs", a.access, job(day(40), "10-12"))
	h.must(400, "POST", "/v1/jobs", a.access, job("soon", "10-12"))
}

func TestBidsShowProviderTrustDetails(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.must(200, "PUT", "/v1/me", provider.access, map[string]string{"display_name": "Ram Shrestha"})
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.must(201, "POST", "/v1/jobs/"+jobID+"/bids", provider.access, map[string]any{
		"amount_paisa": 50000, "parts_included": true, "note": "Washer included",
	})

	bids := h.must(200, "GET", "/v1/jobs/"+jobID+"/bids", seeker.access, nil)["items"].([]any)
	b := bids[0].(map[string]any)
	if b["parts_included"] != true || b["note"] != "Washer included" {
		t.Fatalf("bid = %v", b)
	}
	p := b["provider"].(map[string]any)
	if p["name"] != "Ram Shrestha" {
		t.Fatalf("provider = %v", p)
	}
	if _, leaked := p["phone_number"]; leaked {
		t.Fatal("phone number must stay private")
	}
	if _, leaked := p["service_area"]; leaked {
		t.Fatal("service area must stay private")
	}
}

func TestNameValidation(t *testing.T) {
	h := newHarness(t)
	a := h.login()
	h.must(400, "PUT", "/v1/me", a.access, map[string]string{"display_name": " x "})
	if m := h.must(200, "PUT", "/v1/me", a.access, map[string]string{"display_name": " Sita "}); m["display_name"] != "Sita" {
		t.Fatalf("me = %v", m)
	}
}

func TestProvidersCanListTheirWork(t *testing.T) {
	h := newHarness(t)
	_, provider, jobID := h.startedJob()
	other := h.provider(ktmLat, ktmLng, 2000, plumbing)

	if !feedIDs(h.must(200, "GET", "/v1/jobs/assigned", provider.access, nil))[jobID] {
		t.Fatal("won job missing from assigned list")
	}
	if feedIDs(h.must(200, "GET", "/v1/jobs/assigned", other.access, nil))[jobID] {
		t.Fatal("job leaked to another provider")
	}
}

func TestReviewUpdatesProviderRecord(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.completedJob()

	h.must(201, "POST", "/v1/jobs/"+jobID+"/review", seeker.access, review(4))

	m := h.must(200, "GET", "/v1/providers/"+provider.id, seeker.access, nil)
	p := m["profile"].(map[string]any)
	if p["rating"] != float64(4) || p["review_count"] != float64(1) || p["jobs_completed"] != float64(1) {
		t.Fatalf("profile = %v", p)
	}
	if len(m["reviews"].([]any)) != 1 {
		t.Fatalf("reviews = %v", m["reviews"])
	}
	if h.must(200, "GET", "/v1/jobs/"+jobID, seeker.access, nil)["reviewed"] != true {
		t.Fatal("job should be marked reviewed")
	}
	if h.inboxTypes(provider)["review.received"] != 1 {
		t.Fatal("provider not told about the review")
	}
}

func TestAverageRatingAcrossJobs(t *testing.T) {
	h := newHarness(t)
	seeker, provider, first := h.completedJob()
	h.must(201, "POST", "/v1/jobs/"+first+"/review", seeker.access, review(5))

	h.topUp(seeker, 50000)
	second := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.must(200, "POST", "/v1/jobs/"+second+"/bids/"+h.bid(provider, second, 50000)+"/accept", seeker.access, nil)
	h.must(200, "POST", "/v1/jobs/"+second+"/start", provider.access, nil)
	h.must(200, "POST", "/v1/jobs/"+second+"/confirm", provider.access, nil)
	h.must(200, "POST", "/v1/jobs/"+second+"/confirm", seeker.access, nil)
	h.must(201, "POST", "/v1/jobs/"+second+"/review", seeker.access, review(2))

	p := h.must(200, "GET", "/v1/providers/"+provider.id, seeker.access, nil)["profile"].(map[string]any)
	if p["rating"] != 3.5 || p["jobs_completed"] != float64(2) {
		t.Fatalf("profile = %v", p)
	}
}

func TestReviewRules(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	path := "/v1/jobs/" + jobID + "/review"

	h.must(409, "POST", path, seeker.access, review(5)) // Not finished yet.

	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", seeker.access, nil)

	h.must(400, "POST", path, seeker.access, review(0))
	h.must(400, "POST", path, seeker.access, review(6))
	h.must(400, "POST", path, seeker.access, map[string]any{"rating": 5, "tags": []string{"Invented tag"}})
	h.must(409, "POST", path, provider.access, review(5)) // A provider can't rate themselves.
	h.must(201, "POST", path, seeker.access, review(5))
	h.must(409, "POST", path, seeker.access, review(1)) // Only one review.
}

func TestConcurrentReviewsCountOnce(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.completedJob()

	var created atomic.Int64
	var wg sync.WaitGroup
	for range 5 {
		wg.Go(func() {
			if status, _ := h.call("POST", "/v1/jobs/"+jobID+"/review", seeker.access, review(5)); status == 201 {
				created.Add(1)
			}
		})
	}
	wg.Wait()

	if created.Load() != 1 {
		t.Fatalf("%d reviews created", created.Load())
	}
	p := h.must(200, "GET", "/v1/providers/"+provider.id, seeker.access, nil)["profile"].(map[string]any)
	if p["review_count"] != float64(1) {
		t.Fatalf("profile = %v", p)
	}
}

func TestEditingAProfileKeepsItsRecord(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.completedJob()
	h.must(201, "POST", "/v1/jobs/"+jobID+"/review", seeker.access, review(5))

	h.must(200, "PUT", "/v1/me/provider-profile", provider.access, map[string]any{
		"category_ids": []int{electrical},
		"bio":          "Ten years of experience",
		"radius":       map[string]float64{"lat": ktmLat, "lng": ktmLng, "meters": 3000},
	})

	p := h.must(200, "GET", "/v1/providers/"+provider.id, seeker.access, nil)["profile"].(map[string]any)
	if p["review_count"] != float64(1) || p["jobs_completed"] != float64(1) || p["bio"] != "Ten years of experience" {
		t.Fatalf("profile = %v", p)
	}
}

func TestOnlyAdminsCanVerifyProviders(t *testing.T) {
	h := newHarness(t)
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	admin := h.admin()
	path := "/v1/admin/providers/" + provider.id + "/verified"

	h.must(403, "PUT", path, provider.access, map[string]bool{"verified": true})
	h.must(204, "PUT", path, admin.access, map[string]bool{"verified": true})

	p := h.must(200, "GET", "/v1/providers/"+provider.id, admin.access, nil)["profile"].(map[string]any)
	if p["verified"] != true {
		t.Fatalf("profile = %v", p)
	}
}

func TestWarrantyClaim(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.completedJob()
	admin := h.admin()
	path := "/v1/jobs/" + jobID + "/warranty-claim"
	reason := map[string]string{"reason": "Tap leaking again"}

	h.must(400, "POST", path, seeker.access, map[string]string{"reason": " "})
	h.must(409, "POST", path, provider.access, reason)

	m := h.must(200, "POST", path, seeker.access, reason)
	if m["warranty_claim"].(map[string]any)["status"] != "OPEN" {
		t.Fatalf("job = %v", m)
	}
	h.must(409, "POST", path, seeker.access, reason) // One claim per job.
	if h.inboxTypes(provider)["warranty.claim"] != 1 {
		t.Fatal("provider not told")
	}

	if !feedIDs(h.must(200, "GET", "/v1/admin/warranty-claims", admin.access, nil))[jobID] {
		t.Fatal("claim missing from admin queue")
	}
	h.must(403, "GET", "/v1/admin/warranty-claims", seeker.access, nil)

	close := "/v1/admin/jobs/" + jobID + "/warranty-claim/close"
	h.must(400, "POST", close, admin.access, map[string]string{"note": ""})
	h.must(200, "POST", close, admin.access, map[string]string{"note": "Free re-visit booked"})
	if feedIDs(h.must(200, "GET", "/v1/admin/warranty-claims", admin.access, nil))[jobID] {
		t.Fatal("closed claim should leave the queue")
	}
}

func TestWarrantyExpires(t *testing.T) {
	h := newHarness(t)
	seeker, _, jobID := h.completedJob()
	_, err := h.db.Collection(mongodb.Jobs).UpdateOne(context.Background(), bson.M{"_id": jobID},
		bson.M{"$set": bson.M{"warranty_ends_at": time.Now().Add(-time.Hour)}})
	if err != nil {
		t.Fatal(err)
	}
	h.must(409, "POST", "/v1/jobs/"+jobID+"/warranty-claim", seeker.access, map[string]string{"reason": "Too late"})
}

func TestNoWarrantyBeforeCompletion(t *testing.T) {
	h := newHarness(t)
	seeker, _, jobID := h.startedJob()
	h.must(409, "POST", "/v1/jobs/"+jobID+"/warranty-claim", seeker.access, map[string]string{"reason": "Early"})
}

func TestChatBetweenParties(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	stranger := h.login()
	path := "/v1/jobs/" + jobID + "/messages"

	h.must(201, "POST", path, seeker.access, map[string]string{"body": "Gate code is 4412"})
	h.must(201, "POST", path, provider.access, map[string]string{"body": "On my way"})

	rows := h.must(200, "GET", path, provider.access, nil)["items"].([]any)
	if len(rows) != 2 || rows[0].(map[string]any)["body"] != "Gate code is 4412" {
		t.Fatalf("messages = %v", rows)
	}
	if h.inboxTypes(provider)["chat.message"] != 1 {
		t.Fatal("recipient not notified")
	}
	if h.inboxTypes(seeker)["chat.message"] != 1 {
		t.Fatal("recipient not notified")
	}

	h.must(404, "GET", path, stranger.access, nil)
	h.must(404, "POST", path, stranger.access, map[string]string{"body": "Hello"})
	h.must(400, "POST", path, seeker.access, map[string]string{"body": "   "})
}

func TestChatRequiresAnAssignedJob(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)

	h.must(409, "POST", "/v1/jobs/"+jobID+"/messages", seeker.access, map[string]string{"body": "Hi"})
	h.must(404, "POST", "/v1/jobs/"+jobID+"/messages", provider.access, map[string]string{"body": "Hi"})
}

func TestChatClosesWithTheJob(t *testing.T) {
	h := newHarness(t)
	seeker, _, jobID := h.completedJob()
	h.must(409, "POST", "/v1/jobs/"+jobID+"/messages", seeker.access, map[string]string{"body": "Thanks"})
	h.must(200, "GET", "/v1/jobs/"+jobID+"/messages", seeker.access, nil)
}
