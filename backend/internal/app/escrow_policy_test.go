package app_test

import (
	"context"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/wallet"
)

// startedJob returns a 50,000 paisa job with work under way, leaving the seeker
// a zero balance.
func (h *harness) startedJob() (seeker, provider account, jobID string) {
	h.t.Helper()
	seeker = h.login()
	provider = h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 50000)
	jobID = h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/bids/"+h.bid(provider, jobID, 50000)+"/accept", seeker.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/start", provider.access, nil)
	return seeker, provider, jobID
}

func (h *harness) admin() account {
	h.t.Helper()
	a := h.login()
	_, err := h.db.Collection(mongodb.Users).UpdateOne(context.Background(),
		bson.M{"_id": a.id}, bson.M{"$set": bson.M{"is_admin": true}})
	if err != nil {
		h.t.Fatal(err)
	}
	return a
}

func (h *harness) advance(after time.Duration) {
	h.t.Helper()
	if err := h.app.Jobs.AdvanceExpired(context.Background(), time.Now().Add(after)); err != nil {
		h.t.Fatal(err)
	}
}

func (h *harness) resolve(a account, jobID string, percent int) map[string]any {
	h.t.Helper()
	return h.must(200, "POST", "/v1/admin/jobs/"+jobID+"/resolve-escrow", a.access, map[string]int{"provider_percent": percent})
}

func TestProviderCancellingMidWorkRefundsSeeker(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()

	m := h.must(200, "POST", "/v1/jobs/"+jobID+"/cancel", provider.access, map[string]string{"reason": "Cannot finish"})

	if m["escrow_review_required"] != false {
		t.Fatal("provider cancellation should not need escrow review")
	}
	h.wantBalance(wallet.UserAccount(seeker.id), 50000)
	h.wantBalance(wallet.EscrowAccount(jobID), 0)
	h.assertBooksBalance()
}

func TestUnreviewedSeekerCancellationSplitsEvenly(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/cancel", seeker.access, map[string]string{"reason": "Changed my mind"})

	h.advance(71 * time.Hour)
	h.wantBalance(wallet.EscrowAccount(jobID), 50000)

	h.advance(73 * time.Hour)
	h.advance(74 * time.Hour) // Running again must not pay twice.

	h.wantBalance(wallet.EscrowAccount(jobID), 0)
	h.wantBalance(wallet.UserAccount(seeker.id), 25000)
	h.wantBalance(wallet.UserAccount(provider.id), 22500)
	h.wantBalance(wallet.AccountCommission, 2500)
	m := h.must(200, "GET", "/v1/jobs/"+jobID, seeker.access, nil)
	if m["escrow_review_required"] != false {
		t.Fatal("review flag should clear")
	}
	if by := m["escrow_resolution"].(map[string]any)["resolved_by"]; by != "system" {
		t.Fatalf("resolved_by = %v", by)
	}
	h.assertBooksBalance()
}

func TestAdminDecisionBeatsDefaultSplit(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	admin := h.admin()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/cancel", seeker.access, map[string]string{"reason": "No show"})

	reviews := feedIDs(h.must(200, "GET", "/v1/admin/escrow-reviews", admin.access, nil))
	if !reviews[jobID] {
		t.Fatal("job missing from review queue")
	}

	h.resolve(admin, jobID, 0)
	h.advance(73 * time.Hour)

	h.wantBalance(wallet.UserAccount(seeker.id), 50000)
	h.wantBalance(wallet.UserAccount(provider.id), 0)
	h.must(409, "POST", "/v1/admin/jobs/"+jobID+"/resolve-escrow", admin.access, map[string]int{"provider_percent": 100})
	if feedIDs(h.must(200, "GET", "/v1/admin/escrow-reviews", admin.access, nil))[jobID] {
		t.Fatal("resolved job should leave the review queue")
	}
	h.assertBooksBalance()
}

func TestSilentSeekerAutoReleasesToProvider(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	h.advance(71 * time.Hour)
	if got := h.jobStatus(seeker, jobID); got != "IN_PROGRESS" {
		t.Fatalf("released too early: %s", got)
	}

	h.advance(73 * time.Hour)
	h.advance(74 * time.Hour)

	if got := h.jobStatus(seeker, jobID); got != "COMPLETED" {
		t.Fatalf("status = %s", got)
	}
	h.wantBalance(wallet.UserAccount(provider.id), 45000)
	h.wantBalance(wallet.AccountCommission, 5000)
	h.assertBooksBalance()
}

func TestSilentProviderAutoReleasesToo(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", seeker.access, nil)

	h.advance(73 * time.Hour)

	h.wantBalance(wallet.UserAccount(provider.id), 45000)
	h.assertBooksBalance()
}

func TestNoConfirmationMeansNoAutoRelease(t *testing.T) {
	h := newHarness(t)
	seeker, _, jobID := h.startedJob()

	h.advance(1000 * time.Hour)

	if got := h.jobStatus(seeker, jobID); got != "IN_PROGRESS" {
		t.Fatalf("status = %s", got)
	}
}

func TestDisputeStopsAutoReleaseUntilAdminDecides(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	admin := h.admin()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	h.must(400, "POST", "/v1/jobs/"+jobID+"/dispute", seeker.access, map[string]string{"reason": " "})
	h.must(200, "POST", "/v1/jobs/"+jobID+"/dispute", seeker.access, map[string]string{"reason": "Still leaking"})
	h.must(409, "POST", "/v1/jobs/"+jobID+"/dispute", provider.access, map[string]string{"reason": "Again"})
	h.must(409, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	h.must(409, "POST", "/v1/jobs/"+jobID+"/cancel", seeker.access, map[string]string{"reason": "Out"})

	h.advance(1000 * time.Hour)
	h.wantBalance(wallet.EscrowAccount(jobID), 50000)

	m := h.resolve(admin, jobID, 40)

	if m["status"] != "COMPLETED" {
		t.Fatalf("status = %v", m["status"])
	}
	h.wantBalance(wallet.UserAccount(provider.id), 18000)
	h.wantBalance(wallet.AccountCommission, 2000)
	h.wantBalance(wallet.UserAccount(seeker.id), 30000)
	h.wantBalance(wallet.EscrowAccount(jobID), 0)
	h.assertBooksBalance()
}

func TestDisputeDecidedForSeekerClosesAsCancelled(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	admin := h.admin()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/dispute", provider.access, map[string]string{"reason": "Unsafe site"})

	m := h.resolve(admin, jobID, 0)

	if m["status"] != "CANCELLED" {
		t.Fatalf("status = %v", m["status"])
	}
	h.wantBalance(wallet.UserAccount(seeker.id), 50000)
	h.wantBalance(wallet.AccountCommission, 0)
	h.assertBooksBalance()
}

func TestCancelRefusedOnceCompletionConfirmed(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	h.must(409, "POST", "/v1/jobs/"+jobID+"/cancel", seeker.access, map[string]string{"reason": "Avoid paying"})

	if got := h.jobStatus(seeker, jobID); got != "IN_PROGRESS" {
		t.Fatalf("status = %s", got)
	}
}

func TestCancelRefusedDuringDisputeWithoutConfirmations(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/dispute", seeker.access, map[string]string{"reason": "Bad work"})

	// Without this guard, a provider cancellation here would refund the seeker
	// and take the decision away from the admin.
	h.must(409, "POST", "/v1/jobs/"+jobID+"/cancel", provider.access, map[string]string{"reason": "Out"})
	h.must(409, "POST", "/v1/jobs/"+jobID+"/cancel", seeker.access, map[string]string{"reason": "Out"})

	h.wantBalance(wallet.EscrowAccount(jobID), 50000)
}

func TestOnlyPartiesCanDispute(t *testing.T) {
	h := newHarness(t)
	_, _, jobID := h.startedJob()
	stranger := h.login()
	h.must(404, "POST", "/v1/jobs/"+jobID+"/dispute", stranger.access, map[string]string{"reason": "Nosy"})
}

func TestDisputeNeedsWorkInProgress(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.must(409, "POST", "/v1/jobs/"+jobID+"/dispute", seeker.access, map[string]string{"reason": "Early"})
}

func TestAdminRoutesRefuseOrdinaryUsers(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/dispute", seeker.access, map[string]string{"reason": "Bad work"})

	body := map[string]int{"provider_percent": 0}
	h.must(403, "POST", "/v1/admin/jobs/"+jobID+"/resolve-escrow", seeker.access, body)
	h.must(403, "POST", "/v1/admin/jobs/"+jobID+"/resolve-escrow", provider.access, body)
	h.must(403, "GET", "/v1/admin/escrow-reviews", seeker.access, nil)
	h.must(401, "GET", "/v1/admin/escrow-reviews", "", nil)
	h.wantBalance(wallet.EscrowAccount(jobID), 50000)
}

func TestResolveValidatesPercent(t *testing.T) {
	h := newHarness(t)
	seeker, _, jobID := h.startedJob()
	admin := h.admin()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/dispute", seeker.access, map[string]string{"reason": "Bad work"})

	path := "/v1/admin/jobs/" + jobID + "/resolve-escrow"
	h.must(400, "POST", path, admin.access, map[string]int{"provider_percent": 101})
	h.must(400, "POST", path, admin.access, map[string]int{"provider_percent": -1})
	h.must(400, "POST", path, admin.access, map[string]any{})
	h.wantBalance(wallet.EscrowAccount(jobID), 50000)
}

func TestUnpickedBidsExpireWithoutPenalty(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 50000)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	bidID := h.bid(provider, jobID, 50000)

	h.advance(23 * time.Hour)
	if got := h.jobStatus(seeker, jobID); got != "BROADCASTING" {
		t.Fatalf("expired too early: %s", got)
	}

	h.advance(25 * time.Hour)

	m := h.must(200, "GET", "/v1/jobs/"+jobID, seeker.access, nil)
	if m["status"] != "EXPIRED" {
		t.Fatalf("status = %v", m["status"])
	}
	if m["cancellation"] != nil {
		t.Fatal("expiry must not create a cancellation for penalty review")
	}
	bids := h.must(200, "GET", "/v1/jobs/"+jobID+"/bids", seeker.access, nil)["items"].([]any)
	if s := bids[0].(map[string]any)["status"]; s != "REJECTED" {
		t.Fatalf("bid status = %v", s)
	}
	h.must(404, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", seeker.access, nil)
	h.wantBalance(wallet.UserAccount(seeker.id), 50000)
	if feedIDs(h.must(200, "GET", "/v1/jobs/feed", provider.access, nil))[jobID] {
		t.Fatal("expired job should leave the feed")
	}
}

func TestSecondBidDoesNotExtendSelectionDeadline(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	p1 := h.provider(ktmLat, ktmLng, 2000, plumbing)
	p2 := h.provider(ktmLat, ktmLng, 2000, plumbing)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)

	h.bid(p1, jobID, 50000)
	first := h.must(200, "GET", "/v1/jobs/"+jobID, seeker.access, nil)["selection_deadline"]
	time.Sleep(5 * time.Millisecond)
	h.bid(p2, jobID, 40000)
	second := h.must(200, "GET", "/v1/jobs/"+jobID, seeker.access, nil)["selection_deadline"]

	if first == nil || first != second {
		t.Fatalf("deadline moved from %v to %v", first, second)
	}
}
