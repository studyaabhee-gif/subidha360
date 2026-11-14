package app_test

import (
	"testing"
)

func TestSupportConversation(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	seeker, provider, jobID := h.startedJob()
	stranger := h.login()

	open := map[string]any{"subject": "Provider left early", "topic": "job", "job_id": jobID, "body": "He left before fixing the leak."}
	h.must(404, "POST", "/v1/support/threads", stranger.access, open)
	h.must(400, "POST", "/v1/support/threads", seeker.access, map[string]any{"subject": "Hi", "topic": "job", "body": "x"})
	h.must(400, "POST", "/v1/support/threads", seeker.access, map[string]any{"subject": "Something", "topic": "gossip", "body": "x"})
	thread := h.must(201, "POST", "/v1/support/threads", seeker.access, open)["thread"].(map[string]any)
	id := thread["id"].(string)

	// Only the writer and staff can see it.
	h.must(404, "GET", "/v1/support/threads/"+id, provider.access, nil)
	h.must(403, "GET", "/v1/admin/support", seeker.access, nil)
	inbox := items(h.must(200, "GET", "/v1/admin/support?status=OPEN", admin.access, nil))
	if len(inbox) != 1 || inbox[0]["unread_by_staff"] != true || inbox[0]["person"].(map[string]any)["id"] != seeker.id {
		t.Fatalf("inbox = %v", inbox)
	}
	if h.must(200, "GET", "/v1/admin/overview", admin.access, nil)["attention"].(map[string]any)["support"].(float64) != 1 {
		t.Fatal("overview does not count the waiting conversation")
	}

	h.must(200, "GET", "/v1/admin/support/"+id, admin.access, nil)
	reply := h.must(200, "POST", "/v1/admin/support/"+id+"/messages", admin.access, map[string]string{"body": "We are calling the provider now."})
	if msgs := reply["messages"].([]any); len(msgs) != 2 || msgs[1].(map[string]any)["from_staff"] != true {
		t.Fatalf("messages = %v", msgs)
	}
	h.deliver(0)
	if h.inboxTypes(seeker)["support.reply"] != 1 {
		t.Fatalf("seeker told %v", h.inboxTypes(seeker))
	}
	mine := h.must(200, "GET", "/v1/support/threads", seeker.access, nil)["items"].([]any)
	if mine[0].(map[string]any)["unread_by_user"] != true {
		t.Fatalf("reply not marked unread: %v", mine)
	}
	h.must(200, "GET", "/v1/support/threads/"+id, seeker.access, nil)

	h.must(200, "POST", "/v1/admin/support/"+id+"/close", admin.access, nil)
	h.must(409, "POST", "/v1/admin/support/"+id+"/close", admin.access, nil)
	// Replying reopens it for the team.
	again := h.must(200, "POST", "/v1/support/threads/"+id+"/messages", seeker.access, map[string]string{"body": "It is leaking again."})
	if again["thread"].(map[string]any)["status"] != "OPEN" {
		t.Fatalf("reply did not reopen: %v", again["thread"])
	}
	if !hasAction(items(h.must(200, "GET", "/v1/admin/actions?target="+seeker.id, admin.access, nil)), "support.close", seeker.id) {
		t.Fatal("close not audited")
	}

	// Three open conversations at most.
	other := map[string]any{"subject": "Wallet question", "topic": "payment", "body": "Where is my refund?"}
	h.must(201, "POST", "/v1/support/threads", seeker.access, other)
	h.must(201, "POST", "/v1/support/threads", seeker.access, other)
	h.must(409, "POST", "/v1/support/threads", seeker.access, other)
}

func TestReportsAndAutomaticFlags(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	seeker, provider, jobID := h.startedJob()
	stranger := h.login()

	report := map[string]string{"reason": "asked_cash", "details": "Asked me to pay cash and cancel in the app."}
	h.must(404, "POST", "/v1/jobs/"+jobID+"/report", stranger.access, report)
	h.must(400, "POST", "/v1/jobs/"+jobID+"/report", seeker.access, map[string]string{"reason": "smelly"})
	h.must(400, "POST", "/v1/jobs/"+jobID+"/report", seeker.access, map[string]string{"reason": "other"})
	f := h.must(201, "POST", "/v1/jobs/"+jobID+"/report", seeker.access, report)
	if f["reported_id"] != provider.id {
		t.Fatalf("report = %v", f)
	}
	h.must(409, "POST", "/v1/jobs/"+jobID+"/report", seeker.access, map[string]string{"reason": "rude"})

	// Sharing a number or asking for cash in chat is flagged, once per sign.
	h.must(201, "POST", "/v1/jobs/"+jobID+"/messages", provider.access, map[string]string{"body": "Call me on 9841234567, you can pay cash"})
	h.must(201, "POST", "/v1/jobs/"+jobID+"/messages", provider.access, map[string]string{"body": "My number again: 9841234567"})
	h.must(201, "POST", "/v1/jobs/"+jobID+"/messages", seeker.access, map[string]string{"body": "OK, see you at 10"})

	flags := items(h.must(200, "GET", "/v1/admin/flags?status=OPEN", admin.access, nil))
	reasons := map[string]int{}
	for _, f := range flags {
		if f["reported"].(map[string]any)["id"] != provider.id {
			t.Fatalf("flag about the wrong person: %v", f)
		}
		reasons[f["reason"].(string)]++
	}
	if len(flags) != 3 || reasons["asked_cash"] != 1 || reasons["contact_shared"] != 1 || reasons["off_platform"] != 1 {
		t.Fatalf("flags = %v", reasons)
	}

	detail := h.must(200, "GET", "/v1/admin/users/"+provider.id, admin.access, nil)
	risk := detail["risk"].(map[string]any)
	if risk["flags_open"].(float64) != 3 || len(detail["flags"].([]any)) != 3 {
		t.Fatalf("risk = %v", risk)
	}

	id := flags[0]["id"].(string)
	h.must(400, "POST", "/v1/admin/flags/"+id+"/review", admin.access, map[string]string{"outcome": ""})
	h.must(200, "POST", "/v1/admin/flags/"+id+"/review", admin.access, map[string]string{"outcome": "Warned by phone."})
	h.must(409, "POST", "/v1/admin/flags/"+id+"/review", admin.access, map[string]string{"outcome": "Again"})
	if n := len(items(h.must(200, "GET", "/v1/admin/flags?status=OPEN", admin.access, nil))); n != 2 {
		t.Fatalf("open flags after review = %d", n)
	}
	if !hasAction(items(h.must(200, "GET", "/v1/admin/actions?target="+provider.id, admin.access, nil)), "flag.review", provider.id) {
		t.Fatal("review not audited")
	}
}

func service(id string, category int, name string, hidden bool) map[string]any {
	return map[string]any{
		"category_id": category, "name": name, "summary": "Fix gas stoves that will not light or leak.",
		"symptoms": []string{"stove not lighting", "gas smell"}, "includes": []string{"Safety check", "Burner cleaning"},
		"guide_from_paisa": 50000, "guide_to_paisa": 150000, "name_ne": "ग्यास चुलो मर्मत", "hidden": hidden,
	}
}

func TestAdminsEditTheCatalog(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	seeker := h.login()

	h.must(403, "PUT", "/v1/admin/catalog/services/gas-stove", seeker.access, service("gas-stove", 6, "Gas stove repair", false))
	bad := service("gas-stove", 6, "Gas stove repair", false)
	bad["guide_to_paisa"] = 100
	h.must(400, "PUT", "/v1/admin/catalog/services/gas-stove", admin.access, bad)
	h.must(400, "PUT", "/v1/admin/catalog/services/Gas_Stove", admin.access, service("x", 6, "Gas stove repair", false))
	h.must(400, "PUT", "/v1/admin/catalog/services/gas-stove", admin.access, service("x", 99, "Gas stove repair", false))
	h.must(200, "PUT", "/v1/admin/catalog/services/gas-stove", admin.access, service("x", 6, "Gas stove repair", false))

	find := func(id string) map[string]any {
		cats := h.must(200, "GET", "/v1/catalog", "", nil)["items"].([]any)
		for _, c := range cats {
			for _, s := range c.(map[string]any)["services"].([]any) {
				if s.(map[string]any)["id"] == id {
					return s.(map[string]any)
				}
			}
		}
		return nil
	}
	if s := find("gas-stove"); s == nil || s["name_ne"] != "ग्यास चुलो मर्मत" || s["category_id"].(float64) != 6 {
		t.Fatalf("new service = %v", s)
	}
	job := map[string]any{"category_id": 6, "service_id": "gas-stove", "description": "Stove will not light", "address": "Baneshwor", "lat": ktmLat, "lng": ktmLng}
	h.must(201, "POST", "/v1/jobs", seeker.access, job)

	// Hidden services stay on old jobs but cannot be booked or seen.
	h.must(200, "PUT", "/v1/admin/catalog/services/gas-stove", admin.access, service("x", 6, "Gas stove repair", true))
	if find("gas-stove") != nil {
		t.Fatal("hidden service still listed")
	}
	h.must(400, "POST", "/v1/jobs", seeker.access, job)

	// Prices of built-in services change without a release.
	tap := service("tap-leak", 1, "Leaking tap repair", false)
	tap["guide_from_paisa"], tap["guide_to_paisa"] = 50000, 140000
	h.must(200, "PUT", "/v1/admin/catalog/services/tap-leak", admin.access, tap)
	if s := find("tap-leak"); s["guide_to_paisa"].(float64) != 140000 {
		t.Fatalf("tap = %v", s)
	}

	h.must(200, "PUT", "/v1/admin/catalog/categories/1", admin.access, map[string]string{"name": "Plumbing", "tagline": "Taps, tanks, pumps and pipes", "name_ne": "प्लम्बिङ"})
	h.must(404, "PUT", "/v1/admin/catalog/categories/99", admin.access, map[string]string{"name": "Gardening", "tagline": "Lawns and hedges"})
	h.must(400, "PUT", "/v1/admin/settings", admin.access, map[string]string{"helpline_phone": "call us"})
	h.must(200, "PUT", "/v1/admin/settings", admin.access, map[string]string{"helpline_phone": "01-5970000", "helpline_hours": "9 AM to 6 PM, Sunday to Friday"})
	if s := h.must(200, "GET", "/v1/settings", "", nil); s["helpline_phone"] != "01-5970000" {
		t.Fatalf("settings = %v", s)
	}

	// Edits are saved, not just held in memory: a restart keeps them.
	if err := h.app.Catalog.Load(t.Context()); err != nil {
		t.Fatal(err)
	}
	if s := find("tap-leak"); s["guide_to_paisa"].(float64) != 140000 {
		t.Fatal("edit lost on reload")
	}
	rows := items(h.must(200, "GET", "/v1/admin/actions", admin.access, nil))
	if !hasAction(rows, "catalog.service", "tap-leak") || !hasAction(rows, "settings.save", "settings") {
		t.Fatalf("catalog edits not audited: %v", rows)
	}
}
