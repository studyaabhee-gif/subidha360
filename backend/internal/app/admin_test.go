package app_test

import (
	"context"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/wallet"
)

func items(m map[string]any) []map[string]any {
	raw, _ := m["items"].([]any)
	out := make([]map[string]any, len(raw))
	for i, r := range raw {
		out[i] = r.(map[string]any)
	}
	return out
}

func hasAction(rows []map[string]any, action, target string) bool {
	for _, r := range rows {
		if r["action"] == action && r["target_id"] == target {
			return true
		}
	}
	return false
}

func errorCode(m map[string]any) string {
	e, _ := m["error"].(map[string]any)
	code, _ := e["code"].(string)
	return code
}

func TestAdminPagesRefuseOrdinaryUsers(t *testing.T) {
	h := newHarness(t)
	user := h.login()
	other := h.login()
	for _, path := range []string{
		"/v1/admin/overview", "/v1/admin/users", "/v1/admin/users/" + other.id, "/v1/admin/jobs",
		"/v1/admin/payments", "/v1/admin/money", "/v1/admin/reports", "/v1/admin/reports.csv", "/v1/admin/actions",
	} {
		h.must(403, "GET", path, user.access, nil)
		h.must(401, "GET", path, "", nil)
	}
	h.must(403, "POST", "/v1/admin/users/"+other.id+"/suspend", user.access, map[string]string{"reason": "x"})
	h.must(403, "PUT", "/v1/admin/providers/"+other.id+"/verified", user.access, map[string]bool{"verified": true})
}

func TestSuspensionLocksTheAccountEverywhere(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.topUp(seeker, 50000)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	bidID := h.bid(provider, jobID, 40000)

	h.must(200, "POST", "/v1/admin/users/"+provider.id+"/suspend", admin.access, map[string]string{"reason": "Fake identity documents"})

	// The session they already hold stops working at once.
	status, body := h.call("GET", "/v1/me", provider.access, nil)
	if status != 403 || errorCode(body) != "account_suspended" {
		t.Fatalf("suspended request = %d %v", status, body)
	}
	// They cannot renew it either, even if the fast copy in Redis is lost.
	h.redis.FlushAll()
	status, body = h.call("POST", "/v1/auth/refresh", "", map[string]string{"refresh_token": provider.refresh})
	if status != 403 || errorCode(body) != "account_suspended" {
		t.Fatalf("suspended refresh = %d %v", status, body)
	}
	// Nor log in again.
	h.clearCooldown(provider.phone)
	h.must(204, "POST", "/v1/auth/otp/request", "", map[string]string{"phone": provider.phone})
	h.must(403, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": provider.phone, "code": h.sms.code(provider.phone)})

	// Their waiting bid can no longer be accepted, so no money moves to them.
	h.must(404, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", seeker.access, nil)
	h.wantBalance(wallet.UserAccount(seeker.id), 50000)

	// New jobs are not offered to them.
	second := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	var j struct {
		Eligible []string `bson:"eligible_provider_ids"`
	}
	if err := h.db.Collection(mongodb.Jobs).FindOne(context.Background(), bson.M{"_id": second}).Decode(&j); err != nil {
		t.Fatal(err)
	}
	if len(j.Eligible) != 0 {
		t.Fatalf("suspended provider was offered a job: %v", j.Eligible)
	}

	detail := h.must(200, "GET", "/v1/admin/users/"+provider.id, admin.access, nil)
	if detail["user"].(map[string]any)["suspension"].(map[string]any)["reason"] != "Fake identity documents" {
		t.Fatalf("detail = %v", detail["user"])
	}
	actions := items(h.must(200, "GET", "/v1/admin/actions", admin.access, nil))
	if !hasAction(actions, "user.suspend", provider.id) {
		t.Fatalf("suspension not in audit log: %v", actions)
	}

	// Lifting it restores everything.
	h.must(200, "POST", "/v1/admin/users/"+provider.id+"/unsuspend", admin.access, map[string]string{"reason": "Documents checked in person"})
	h.clearCooldown(provider.phone)
	again := h.loginAs(provider.phone)
	h.must(200, "GET", "/v1/me", again, nil)
	if !hasAction(items(h.must(200, "GET", "/v1/admin/actions?target="+provider.id, admin.access, nil)), "user.unsuspend", provider.id) {
		t.Fatal("unsuspension not in audit log")
	}
}

// loginAs logs in an existing phone number and returns an access token.
func (h *harness) loginAs(phone string) string {
	h.t.Helper()
	h.must(204, "POST", "/v1/auth/otp/request", "", map[string]string{"phone": phone})
	m := h.must(200, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": phone, "code": h.sms.code(phone)})
	return m["tokens"].(map[string]any)["access_token"].(string)
}

func TestSuspensionRules(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	other := h.admin()
	user := h.login()

	status, body := h.call("POST", "/v1/admin/users/"+admin.id+"/suspend", admin.access, map[string]string{"reason": "x"})
	if status != 409 || errorCode(body) != "cannot_suspend_self" {
		t.Fatalf("self = %d %v", status, body)
	}
	status, body = h.call("POST", "/v1/admin/users/"+other.id+"/suspend", admin.access, map[string]string{"reason": "x"})
	if status != 409 || errorCode(body) != "cannot_suspend_admin" {
		t.Fatalf("other admin = %d %v", status, body)
	}
	h.must(400, "POST", "/v1/admin/users/"+user.id+"/suspend", admin.access, map[string]string{"reason": "  "})
	h.must(404, "POST", "/v1/admin/users/nobody/suspend", admin.access, map[string]string{"reason": "x"})
	h.must(409, "POST", "/v1/admin/users/"+user.id+"/unsuspend", admin.access, map[string]string{})
	h.must(200, "GET", "/v1/me", user.access, nil)
}

func TestVerifyingAProviderIsAudited(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	h.must(200, "PUT", "/v1/me", admin.access, map[string]string{"display_name": "Asha Admin"})
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	seeker := h.login()

	h.must(404, "PUT", "/v1/admin/providers/"+seeker.id+"/verified", admin.access, map[string]bool{"verified": true})
	h.must(204, "PUT", "/v1/admin/providers/"+provider.id+"/verified", admin.access, map[string]any{"verified": true, "note": "Citizenship seen"})
	if h.must(200, "GET", "/v1/providers/"+provider.id, seeker.access, nil)["profile"].(map[string]any)["verified"] != true {
		t.Fatal("provider not shown as verified")
	}
	rows := items(h.must(200, "GET", "/v1/admin/actions", admin.access, nil))
	if len(rows) != 1 || rows[0]["action"] != "provider.verify" || rows[0]["admin_name"] != "Asha Admin" || rows[0]["detail"] != "Citizenship seen" {
		t.Fatalf("audit = %v", rows)
	}
}

func TestEscrowDecisionIsAudited(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/dispute", seeker.access, map[string]string{"reason": "Leak is back"})

	list := items(h.must(200, "GET", "/v1/admin/jobs?status=attention", admin.access, nil))
	if len(list) != 1 || list[0]["id"] != jobID || list[0]["disputed"] != true {
		t.Fatalf("attention list = %v", list)
	}
	h.must(200, "POST", "/v1/admin/jobs/"+jobID+"/resolve-escrow", admin.access, map[string]any{"provider_percent": 40, "note": "Half the work was done"})
	h.wantBalance(wallet.UserAccount(seeker.id), 30000)
	h.wantBalance(wallet.UserAccount(provider.id), 18000)
	h.assertBooksBalance()

	rows := items(h.must(200, "GET", "/v1/admin/actions?target="+jobID, admin.access, nil))
	if len(rows) != 1 || rows[0]["detail"] != "40% to the provider: Half the work was done" {
		t.Fatalf("audit = %v", rows)
	}
	// A decision is final: the second attempt changes nothing and logs nothing.
	h.must(409, "POST", "/v1/admin/jobs/"+jobID+"/resolve-escrow", admin.access, map[string]any{"provider_percent": 100})
	if n := len(items(h.must(200, "GET", "/v1/admin/actions?target="+jobID, admin.access, nil))); n != 1 {
		t.Fatalf("audit rows after refused decision = %d", n)
	}
	if len(items(h.must(200, "GET", "/v1/admin/jobs?status=attention", admin.access, nil))) != 0 {
		t.Fatal("decided job still needs attention")
	}
}

func TestPeopleSearchAndFilters(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	seeker := h.login()
	h.must(200, "PUT", "/v1/me", seeker.access, map[string]string{"display_name": "Sita Sharma"})
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)

	ids := func(path string) map[string]bool {
		out := map[string]bool{}
		for _, r := range items(h.must(200, "GET", path, admin.access, nil)) {
			out[r["id"].(string)] = true
		}
		return out
	}
	if got := ids("/v1/admin/users?q=sita"); !got[seeker.id] || len(got) != 1 {
		t.Fatalf("name search = %v", got)
	}
	if got := ids("/v1/admin/users?q=" + provider.phone[len(provider.phone)-6:]); !got[provider.id] || len(got) != 1 {
		t.Fatalf("phone search = %v", got)
	}
	if got := ids("/v1/admin/users?filter=providers"); !got[provider.id] || got[seeker.id] {
		t.Fatalf("providers = %v", got)
	}
	if got := ids("/v1/admin/users?filter=unverified"); !got[provider.id] {
		t.Fatalf("unverified = %v", got)
	}
	if got := ids("/v1/admin/users?filter=admins"); !got[admin.id] || len(got) != 1 {
		t.Fatalf("admins = %v", got)
	}
	// Search text is never treated as a pattern.
	if got := ids("/v1/admin/users?q=%2B977(.*"); len(got) != 0 {
		t.Fatalf("pattern search = %v", got)
	}
	h.must(400, "GET", "/v1/admin/users?filter=everyone", admin.access, nil)
}

func TestJobDetailShowsTheWholeStory(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	seeker, provider, jobID := h.startedJob()
	h.must(201, "POST", "/v1/jobs/"+jobID+"/messages", seeker.access, map[string]string{"body": "Please bring a washer"})
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", seeker.access, nil)

	d := h.must(200, "GET", "/v1/admin/jobs/"+jobID, admin.access, nil)
	if d["job"].(map[string]any)["status"] != "COMPLETED" {
		t.Fatalf("job = %v", d["job"])
	}
	if s := d["summary"].(map[string]any); s["seeker"].(map[string]any)["phone"] != seeker.phone || s["provider"].(map[string]any)["id"] != provider.id {
		t.Fatalf("summary = %v", s)
	}
	if bids := d["bids"].([]any); len(bids) != 1 {
		t.Fatalf("bids = %v", bids)
	}
	if msgs := d["messages"].([]any); len(msgs) != 1 || msgs[0].(map[string]any)["body"] != "Please bring a washer" {
		t.Fatalf("messages = %v", msgs)
	}
	// Hold (2 legs) and settlement (escrow, payout, commission).
	if legs := d["ledger"].([]any); len(legs) != 5 {
		t.Fatalf("ledger = %v", legs)
	}
	h.must(404, "GET", "/v1/admin/jobs/missing", admin.access, nil)

	user := h.must(200, "GET", "/v1/admin/users/"+provider.id, admin.access, nil)
	if user["balance_paisa"].(float64) != 45000 || len(user["jobs"].([]any)) != 1 {
		t.Fatalf("provider detail = %v", user)
	}
}

func TestMoneyAndReportsMatchTheLedger(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	h.completedJob()
	seeker := h.login()
	h.topUp(seeker, 20000)

	o := h.must(200, "GET", "/v1/admin/overview", admin.access, nil)
	money := o["money"].(map[string]any)
	if money["healthy"] != true || money["commission_paisa"].(float64) != 5000 ||
		money["wallets_paisa"].(float64) != 65000 || money["topped_up_paisa"].(float64) != 70000 ||
		money["escrow_held_paisa"].(float64) != 0 {
		t.Fatalf("money = %v", money)
	}
	last30 := o["last_30_days"].(map[string]any)
	if last30["jobs_posted"].(float64) != 1 || last30["jobs_completed"].(float64) != 1 ||
		last30["gmv_paisa"].(float64) != 50000 || last30["commission_paisa"].(float64) != 5000 ||
		last30["payouts_paisa"].(float64) != 45000 || last30["top_ups_paisa"].(float64) != 70000 {
		t.Fatalf("last 30 days = %v", last30)
	}
	if days := o["days"].([]any); len(days) != 14 {
		t.Fatalf("days = %d", len(days))
	}
	if o["users"].(map[string]any)["total"].(float64) != 4 {
		t.Fatalf("users = %v", o["users"])
	}

	today := time.Now().In(time.FixedZone("NPT", 5*3600+45*60)).Format("2006-01-02")
	rep := h.must(200, "GET", "/v1/admin/reports?from="+today+"&to="+today, admin.access, nil)
	if days := rep["days"].([]any); len(days) != 1 || days[0].(map[string]any)["jobs_completed"].(float64) != 1 {
		t.Fatalf("report days = %v", rep["days"])
	}
	cats := rep["categories"].([]any)
	if top := cats[0].(map[string]any); top["category_id"].(float64) != plumbing || top["completed_value_paisa"].(float64) != 50000 {
		t.Fatalf("categories = %v", cats[0])
	}
	if p := rep["top_providers"].([]any); len(p) != 1 {
		t.Fatalf("top providers = %v", p)
	}

	req, _ := http.NewRequest("GET", h.srv.URL+"/v1/admin/reports.csv?from="+today+"&to="+today, nil)
	req.Header.Set("Authorization", "Bearer "+admin.access)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	csv, _ := io.ReadAll(res.Body)
	res.Body.Close()
	if !strings.Contains(string(csv), today+",1,1,0,4,500.00,50.00,450.00,0.00,700.00") {
		t.Fatalf("csv = %s", csv)
	}

	for _, q := range []string{"from=13-11-2026", "from=2026-11-10&to=2026-11-01", "from=2020-01-01&to=2026-01-01"} {
		h.must(400, "GET", "/v1/admin/reports?"+q, admin.access, nil)
	}

	// A balance changed behind the ledger's back is caught.
	_, err = h.db.Collection(mongodb.WalletAccounts).UpdateOne(context.Background(),
		bson.M{"_id": wallet.UserAccount(seeker.id)}, bson.M{"$inc": bson.M{"balance": 100}})
	if err != nil {
		t.Fatal(err)
	}
	money = h.must(200, "GET", "/v1/admin/money", admin.access, nil)
	bad := money["mismatched_accounts"].([]any)
	if money["healthy"] != false || len(bad) != 1 || bad[0] != wallet.UserAccount(seeker.id) {
		t.Fatalf("tampered money = %v", money)
	}

	pay := items(h.must(200, "GET", "/v1/admin/payments?type=COMMISSION", admin.access, nil))
	if len(pay) != 1 || pay[0]["amount_paisa"].(float64) != 5000 {
		t.Fatalf("commission entries = %v", pay)
	}
	h.must(400, "GET", "/v1/admin/payments?type=GIFT", admin.access, nil)
}
