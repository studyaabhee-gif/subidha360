package app_test

import (
	"context"
	"errors"
	"path/filepath"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/platform/backup"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/wallet"
)

// loginWithTerms logs in agreeing to a terms version, and returns the user
// as stored afterwards, so the test checks what was saved, not the reply.
func (h *harness) loginWithTerms(phone, version string) map[string]any {
	h.t.Helper()
	h.clearCooldown(phone)
	h.must(204, "POST", "/v1/auth/otp/request", "", map[string]string{"phone": phone})
	m := h.must(200, "POST", "/v1/auth/otp/verify", "", map[string]string{
		"phone": phone, "code": h.sms.code(phone), "terms_version": version,
	})
	token := m["tokens"].(map[string]any)["access_token"].(string)
	return h.must(200, "GET", "/v1/me", token, nil)
}

func TestTermsAcceptanceIsRecorded(t *testing.T) {
	h := newHarness(t)
	phone := "+9779811111111"
	first := h.loginWithTerms(phone, "2026-11-13")
	at := first["terms_accepted_at"]
	if first["terms_version"] != "2026-11-13" || at == nil {
		t.Fatalf("first login = %v", first)
	}
	// Agreeing to the same version again keeps the first date.
	if again := h.loginWithTerms(phone, "2026-11-13"); again["terms_accepted_at"] != at {
		t.Fatalf("date changed: %v then %v", at, again["terms_accepted_at"])
	}
	if next := h.loginWithTerms(phone, "2027-01-01"); next["terms_version"] != "2027-01-01" {
		t.Fatalf("new version = %v", next)
	}
	h.must(400, "POST", "/v1/auth/otp/verify", "", map[string]string{"phone": phone, "code": "000000", "terms_version": "this-is-far-too-long-to-be-a-version"})
}

func TestCompanyDetailsAreShown(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	settings := map[string]string{
		"helpline_phone": "01-5970000", "company_name": "Subidha360 Pvt. Ltd.",
		"registration_no": "123456/080/081", "pan": "609876543",
		"address": "Baneshwor, Kathmandu", "email": "help@subidha360.com",
	}
	bad := map[string]string{}
	for k, v := range settings {
		bad[k] = v
	}
	bad["pan"] = "60987"
	h.must(400, "PUT", "/v1/admin/settings", admin.access, bad)
	bad["pan"], bad["email"] = "609876543", "not-an-email"
	h.must(400, "PUT", "/v1/admin/settings", admin.access, bad)
	h.must(200, "PUT", "/v1/admin/settings", admin.access, settings)
	got := h.must(200, "GET", "/v1/settings", "", nil)
	for k, v := range settings {
		if got[k] != v {
			t.Errorf("%s = %v, want %s", k, got[k], v)
		}
	}
}

func TestBackupRestoresEverything(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.completedJob()
	h.must(201, "POST", "/v1/jobs/"+jobID+"/review", seeker.access, review(5))
	ctx := context.Background()
	dir := filepath.Join(t.TempDir(), "backup")

	saved, err := backup.Export(ctx, h.db, dir)
	if err != nil {
		t.Fatal(err)
	}
	if saved.Collections[mongodb.Users] != 2 || saved.Collections[mongodb.WalletLedger] == 0 {
		t.Fatalf("manifest = %v", saved.Collections)
	}
	if _, err := backup.Export(ctx, h.db, dir); err == nil {
		t.Fatal("export overwrote an existing backup")
	}

	target := h.db.Client().Database(h.db.Name() + "_restore")
	t.Cleanup(func() { target.Drop(context.Background()) })
	if _, err := backup.Import(ctx, target, dir, false); err != nil {
		t.Fatal(err)
	}
	if _, err := backup.Import(ctx, target, dir, false); !errors.Is(err, backup.ErrNotEmpty) {
		t.Fatalf("second restore = %v, want refusal", err)
	}
	if _, err := backup.Import(ctx, target, dir, true); err != nil {
		t.Fatalf("replace restore = %v", err)
	}
	for name, want := range saved.Collections {
		got, err := target.Collection(name).CountDocuments(ctx, bson.M{})
		if err != nil || got != want {
			t.Errorf("%s has %d documents, want %d (%v)", name, got, want, err)
		}
	}
	// Money survives exactly, as 64-bit integers.
	var account struct {
		Balance int64 `bson:"balance"`
	}
	if err := target.Collection(mongodb.WalletAccounts).FindOne(ctx, bson.M{"_id": wallet.UserAccount(provider.id)}).Decode(&account); err != nil {
		t.Fatal(err)
	}
	if account.Balance != 45000 {
		t.Fatalf("restored balance = %d", account.Balance)
	}
}

func TestPageViewsAreCountedWithoutTracking(t *testing.T) {
	h := newHarness(t)
	admin := h.admin()
	for _, route := range []string{"/", "/", "/", "/service/:id", "/login", "/jobs/new"} {
		h.must(204, "POST", "/v1/views", "", map[string]string{"route": route})
	}
	h.must(400, "POST", "/v1/views", "", map[string]string{"route": "/wp-admin"})

	traffic := h.must(200, "GET", "/v1/admin/traffic", admin.access, nil)
	if traffic["total_views"].(float64) != 6 {
		t.Fatalf("traffic = %v", traffic)
	}
	funnel := traffic["funnel"].([]any)
	if funnel[0].(map[string]any)["views"].(float64) != 3 || funnel[3].(map[string]any)["views"].(float64) != 1 {
		t.Fatalf("funnel = %v", funnel)
	}
	// Nothing about the visitor is kept: only a day, a page and a count.
	var row bson.M
	if err := h.db.Collection(mongodb.DailyViews).FindOne(context.Background(), bson.M{"route": "/"}).Decode(&row); err != nil {
		t.Fatal(err)
	}
	for k := range row {
		if k != "_id" && k != "day" && k != "route" && k != "views" {
			t.Fatalf("view row stores %q", k)
		}
	}
	// One address cannot inflate the numbers.
	for range 70 {
		h.must(204, "POST", "/v1/views", "", map[string]string{"route": "/guarantee"})
	}
	if got := h.must(200, "GET", "/v1/admin/traffic", admin.access, nil)["total_views"].(float64); got > 60 {
		t.Fatalf("total after flood = %v", got)
	}
}
