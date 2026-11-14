package app_test

import (
	"context"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/platform/mongodb"
)

func TestUnreadNotifications(t *testing.T) {
	h := newHarness(t)
	seeker, _, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/dispute", seeker.access, map[string]string{"reason": "Not finished"})

	_, provider, _ := h.startedJob()
	unread := func(a account) float64 {
		return h.must(200, "GET", "/v1/notifications/unread", a.access, nil)["count"].(float64)
	}
	before := unread(seeker)
	if before == 0 {
		t.Fatal("seeker has no unread notifications to test with")
	}
	h.must(204, "POST", "/v1/notifications/read", seeker.access, nil)
	if n := unread(seeker); n != 0 {
		t.Fatalf("unread after marking = %v", n)
	}
	// Reading is per person.
	if unread(provider) == 0 {
		t.Fatal("marking one inbox cleared another")
	}
	items := h.must(200, "GET", "/v1/notifications", seeker.access, nil)["items"].([]any)
	if items[0].(map[string]any)["read_at"] == nil {
		t.Fatal("inbox does not show the read time")
	}
}

func TestDeletingAnAccount(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()

	// Unfinished work blocks deletion, with a reason the person can act on.
	check := h.must(200, "GET", "/v1/me/deletion", provider.access, nil)
	if check["can_delete"] != false || check["blockers"].([]any)[0].(map[string]any)["code"] != "active_jobs" {
		t.Fatalf("check = %v", check)
	}
	h.must(400, "DELETE", "/v1/me", provider.access, map[string]string{"confirm": "yes"})
	h.must(409, "DELETE", "/v1/me", provider.access, map[string]string{"confirm": "DELETE"})

	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", seeker.access, nil)
	// Now the job is done, but the provider's earnings are still in the wallet.
	codes := map[string]bool{}
	for _, b := range h.must(200, "GET", "/v1/me/deletion", provider.access, nil)["blockers"].([]any) {
		codes[b.(map[string]any)["code"].(string)] = true
	}
	if !codes["wallet_balance"] || codes["active_jobs"] {
		t.Fatalf("blockers = %v", codes)
	}

	// The customer spent everything, so they can go.
	h.must(200, "PUT", "/v1/me", seeker.access, map[string]string{"display_name": "Sita Gurung"})
	if h.must(200, "GET", "/v1/me/deletion", seeker.access, nil)["can_delete"] != true {
		t.Fatal("customer with nothing open cannot delete")
	}
	h.must(204, "DELETE", "/v1/me", seeker.access, map[string]string{"confirm": "DELETE"})

	// Their session stops at once.
	h.must(403, "GET", "/v1/me", seeker.access, nil)
	var u bson.M
	if err := h.db.Collection(mongodb.Users).FindOne(context.Background(), bson.M{"_id": seeker.id}).Decode(&u); err != nil {
		t.Fatal(err)
	}
	if u["phone_number"] == seeker.phone || u["display_name"] != "" || u["deleted_at"] == nil {
		t.Fatalf("user still identifiable: %v", u)
	}
	// The job record stays for the provider.
	if h.jobStatus(provider, jobID) != "COMPLETED" {
		t.Fatal("job lost")
	}
	// The same number can sign up again, as a new account.
	h.clearCooldown(seeker.phone)
	fresh := h.loginAs(seeker.phone)
	me := h.must(200, "GET", "/v1/me", fresh, nil)
	if me["id"] == seeker.id || me["display_name"] != "" {
		t.Fatalf("new login reused the deleted account: %v", me)
	}
}
