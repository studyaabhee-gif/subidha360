package app_test

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/notify"
	"subidha360/backend/internal/platform/mongodb"
)

type fakePusher struct {
	mu   sync.Mutex
	sent []notify.Push
	errs map[string]error
}

func (f *fakePusher) Push(_ context.Context, p notify.Push) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if err := f.errs[p.Token]; err != nil {
		return err
	}
	f.sent = append(f.sent, p)
	return nil
}

func (f *fakePusher) failToken(token string, err error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.errs[token] = err
}

// to returns pushes that reached a token, optionally of one notification type.
func (f *fakePusher) to(token, kind string) []notify.Push {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []notify.Push
	for _, p := range f.sent {
		if p.Token == token && (kind == "" || p.Data["type"] == kind) {
			out = append(out, p)
		}
	}
	return out
}

func (c *captureSMS) alertsTo(phone string) []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.alerts[phone]
}

func (c *captureSMS) setFail(fail bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.fail = fail
}

func (h *harness) device(a account, token string) {
	h.t.Helper()
	h.must(204, "PUT", "/v1/me/devices", a.access, map[string]string{"token": token, "platform": "android"})
}

func (h *harness) deliver(after time.Duration) {
	h.t.Helper()
	if err := h.app.Notify.Deliver(context.Background(), time.Now().Add(after)); err != nil {
		h.t.Fatal(err)
	}
}

func (h *harness) inboxTypes(a account) map[string]int {
	h.t.Helper()
	types := map[string]int{}
	items, _ := h.must(200, "GET", "/v1/notifications", a.access, nil)["items"].([]any)
	for _, it := range items {
		types[it.(map[string]any)["type"].(string)]++
	}
	return types
}

func (h *harness) messageStatus(a account, kind string) (status, channel string) {
	h.t.Helper()
	var m struct {
		Status  string `bson:"status"`
		Channel string `bson:"channel"`
	}
	err := h.db.Collection(mongodb.Notifications).FindOne(context.Background(), bson.M{"user_id": a.id, "type": kind}).Decode(&m)
	if err != nil {
		h.t.Fatalf("no %s message for user: %v", kind, err)
	}
	return m.Status, m.Channel
}

const confirmNeeded = "completion.confirm_needed"

func TestLifecycleNotifiesEachParty(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.device(seeker, "seeker-phone")
	h.device(provider, "provider-phone")
	h.topUp(seeker, 50000)

	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	bidID := h.bid(provider, jobID, 50000)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", seeker.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/start", provider.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", seeker.access, nil)
	h.deliver(0)

	for token, kinds := range map[string][]string{
		"seeker-phone":   {"bid.received", "job.started", confirmNeeded, "job.completed"},
		"provider-phone": {"job.broadcast", "bid.accepted", "job.completed"},
	} {
		for _, kind := range kinds {
			if n := len(h.push.to(token, kind)); n != 1 {
				t.Errorf("%s got %d %s pushes", token, n, kind)
			}
		}
	}
	got := h.push.to("seeker-phone", confirmNeeded)[0]
	if got.Data["job_id"] != jobID {
		t.Errorf("job_id = %q", got.Data["job_id"])
	}
	if !strings.Contains(got.Body, "72 hours") {
		t.Errorf("warning must state the deadline: %q", got.Body)
	}
}

func TestDeliveringTwiceSendsOnce(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.device(seeker, "seeker-phone")
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	h.deliver(0)
	h.deliver(time.Hour)

	if n := len(h.push.to("seeker-phone", confirmNeeded)); n != 1 {
		t.Fatalf("sent %d times", n)
	}
}

func TestConcurrentWorkersDoNotDoubleSend(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	h.device(provider, "provider-phone")
	for range 10 {
		h.createJob(seeker, ktmLat, ktmLng, plumbing)
	}

	var wg sync.WaitGroup
	for range 4 {
		wg.Go(func() {
			if err := h.app.Notify.Deliver(context.Background(), time.Now()); err != nil {
				t.Error(err)
			}
		})
	}
	wg.Wait()

	if n := len(h.push.to("provider-phone", "job.broadcast")); n != 10 {
		t.Fatalf("sent %d pushes for 10 jobs", n)
	}
}

func TestRolledBackActionSendsNothing(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	bidID := h.bid(provider, jobID, 50000)

	// The seeker cannot afford this, so the acceptance rolls back.
	h.must(409, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", seeker.access, nil)
	h.must(409, "POST", "/v1/jobs/"+jobID+"/bids", provider.access, map[string]int64{"amount_paisa": 100})

	if n := h.inboxTypes(provider)["bid.accepted"]; n != 0 {
		t.Fatal("provider was told they won a rolled-back bid")
	}
	if n := h.inboxTypes(seeker)["bid.received"]; n != 1 {
		t.Fatalf("seeker has %d bid notifications, want 1", n)
	}
}

func TestCriticalMessageFallsBackToSMSWithoutADevice(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	h.deliver(0)

	alerts := h.sms.alertsTo(seeker.phone)
	if len(alerts) != 1 || !strings.Contains(alerts[0], "72 hours") {
		t.Fatalf("alerts = %v", alerts)
	}
	if status, channel := h.messageStatus(seeker, confirmNeeded); status != notify.StatusSent || channel != notify.ChannelSMS {
		t.Fatalf("status = %s, channel = %s", status, channel)
	}
}

func TestOrdinaryMessageWithoutADeviceStaysInInbox(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	jobID := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.bid(provider, jobID, 50000)

	h.deliver(0)

	if alerts := h.sms.alertsTo(seeker.phone); len(alerts) != 0 {
		t.Fatalf("bid alert must not cost an SMS: %v", alerts)
	}
	if status, _ := h.messageStatus(seeker, "bid.received"); status != notify.StatusInboxOnly {
		t.Fatalf("status = %s", status)
	}
	if h.inboxTypes(seeker)["bid.received"] != 1 {
		t.Fatal("message missing from inbox")
	}
}

func TestPushRetriesThenRecovers(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.device(seeker, "seeker-phone")
	h.push.failToken("seeker-phone", errors.New("fcm unavailable"))
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	h.deliver(0)
	if status, _ := h.messageStatus(seeker, confirmNeeded); status != notify.StatusPending {
		t.Fatalf("status = %s", status)
	}

	h.deliver(time.Second) // Too soon: the backoff has not passed.
	h.push.failToken("seeker-phone", nil)
	if n := len(h.push.to("seeker-phone", confirmNeeded)); n != 0 {
		t.Fatal("retried before the backoff")
	}

	h.deliver(5 * time.Minute)

	if n := len(h.push.to("seeker-phone", confirmNeeded)); n != 1 {
		t.Fatalf("delivered %d times", n)
	}
	if alerts := h.sms.alertsTo(seeker.phone); len(alerts) != 0 {
		t.Fatalf("recovered push must not also SMS: %v", alerts)
	}
}

func TestPersistentPushFailureFallsBackToSMS(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.device(seeker, "seeker-phone")
	h.push.failToken("seeker-phone", errors.New("fcm unavailable"))
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	for i := range 5 {
		h.deliver(time.Duration(i) * 2 * time.Hour)
	}

	if alerts := h.sms.alertsTo(seeker.phone); len(alerts) != 1 {
		t.Fatalf("alerts = %v", alerts)
	}
}

func TestDeadTokenIsRemovedAndCriticalGoesBySMS(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.device(seeker, "old-phone")
	h.push.failToken("old-phone", notify.ErrInvalidToken)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	h.deliver(0)

	n, err := h.db.Collection(mongodb.Devices).CountDocuments(context.Background(), bson.M{"_id": "old-phone"})
	if err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatal("dead token should be removed")
	}
	if alerts := h.sms.alertsTo(seeker.phone); len(alerts) != 1 {
		t.Fatalf("alerts = %v", alerts)
	}
}

func TestOneWorkingDeviceIsEnough(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.device(seeker, "broken-tablet")
	h.device(seeker, "phone")
	h.push.failToken("broken-tablet", errors.New("fcm unavailable"))
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	h.deliver(0)

	if status, channel := h.messageStatus(seeker, confirmNeeded); status != notify.StatusSent || channel != notify.ChannelPush {
		t.Fatalf("status = %s, channel = %s", status, channel)
	}
}

func TestSMSOutageKeepsRetryingThenGivesUp(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.sms.setFail(true)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)

	h.deliver(0)
	if status, _ := h.messageStatus(seeker, confirmNeeded); status != notify.StatusPending {
		t.Fatalf("status = %s", status)
	}

	for i := 1; i <= 12; i++ {
		h.deliver(time.Duration(i) * 2 * time.Hour)
	}
	if status, _ := h.messageStatus(seeker, confirmNeeded); status != notify.StatusFailed {
		t.Fatalf("status = %s", status)
	}
}

func TestSilentSeekerGetsOneReminderBeforeAutoRelease(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	const reminder = "completion.auto_release_warning"

	h.advance(47 * time.Hour)
	if n := h.inboxTypes(seeker)[reminder]; n != 0 {
		t.Fatal("reminded too early")
	}

	h.advance(49 * time.Hour)
	h.advance(50 * time.Hour)
	if n := h.inboxTypes(seeker)[reminder]; n != 1 {
		t.Fatalf("%d reminders", n)
	}
	if n := h.inboxTypes(provider)[reminder]; n != 0 {
		t.Fatal("provider should not be reminded")
	}
}

func TestSeekerWhoConfirmedIsNotReminded(t *testing.T) {
	h := newHarness(t)
	seeker, _, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", seeker.access, nil)

	h.advance(49 * time.Hour)

	if n := h.inboxTypes(seeker)["completion.auto_release_warning"]; n != 0 {
		t.Fatal("seeker already agreed")
	}
}

func TestMoneyOutcomesNotifyBothParties(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	admin := h.admin()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/dispute", seeker.access, map[string]string{"reason": "Bad work"})
	if h.inboxTypes(provider)["dispute.raised"] != 1 {
		t.Fatal("provider not told about dispute")
	}

	h.resolve(admin, jobID, 40)

	for _, a := range []account{seeker, provider} {
		if h.inboxTypes(a)["escrow.resolved"] != 1 {
			t.Errorf("user %s not told about resolution", a.id)
		}
	}
}

func TestProviderCancellationTellsSeekerAboutRefund(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.device(seeker, "seeker-phone")
	h.must(200, "POST", "/v1/jobs/"+jobID+"/cancel", provider.access, map[string]string{"reason": "Cannot finish"})

	h.deliver(0)

	got := h.push.to("seeker-phone", "job.cancelled")
	if len(got) != 1 || !strings.Contains(got[0].Body, "refunded") {
		t.Fatalf("pushes = %v", got)
	}
}

func TestExpiryAndFallbackTellSeeker(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 2000, plumbing)
	withBid := h.createJob(seeker, ktmLat, ktmLng, plumbing)
	h.bid(provider, withBid, 50000)
	h.createJob(seeker, farLat, farLng, plumbing)

	h.advance(6 * time.Minute)
	h.advance(12 * time.Minute)
	h.advance(25 * time.Hour)

	types := h.inboxTypes(seeker)
	if types["job.expired"] != 1 || types["job.manual_fallback"] != 1 {
		t.Fatalf("inbox = %v", types)
	}
}

func TestEscalationNotifiesOnlyNewProviders(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	covering := h.provider(ktmLat, ktmLng, 2000, plumbing)
	nearby := h.provider(nearbyLat, nearLng, 2000, plumbing)
	h.createJob(seeker, ktmLat, ktmLng, plumbing)

	h.advance(6 * time.Minute)

	if n := h.inboxTypes(covering)["job.broadcast"]; n != 1 {
		t.Fatalf("covering provider got %d broadcasts", n)
	}
	if n := h.inboxTypes(nearby)["job.broadcast"]; n != 1 {
		t.Fatalf("nearby provider got %d broadcasts", n)
	}
}

func TestDeviceTokenMovesToTheNewUser(t *testing.T) {
	h := newHarness(t)
	first := h.login()
	seeker, provider, jobID := h.startedJob()
	h.device(first, "shared-phone")
	h.device(seeker, "shared-phone")

	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	h.deliver(0)

	if n := len(h.push.to("shared-phone", confirmNeeded)); n != 1 {
		t.Fatalf("delivered %d", n)
	}
	h.must(204, "DELETE", "/v1/me/devices", first.access, map[string]string{"token": "shared-phone"})
	n, err := h.db.Collection(mongodb.Devices).CountDocuments(context.Background(), bson.M{"_id": "shared-phone"})
	if err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatal("a previous owner must not be able to remove the token")
	}
}

func TestDeviceValidationAndAuth(t *testing.T) {
	h := newHarness(t)
	a := h.login()
	h.must(400, "PUT", "/v1/me/devices", a.access, map[string]string{"token": " ", "platform": "android"})
	h.must(400, "PUT", "/v1/me/devices", a.access, map[string]string{"token": "t", "platform": "windows"})
	h.must(401, "PUT", "/v1/me/devices", "", map[string]string{"token": "t", "platform": "ios"})
	h.must(401, "GET", "/v1/notifications", "", nil)
}

func TestInboxIsPrivate(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	stranger := h.login()

	if types := h.inboxTypes(stranger); len(types) != 0 {
		t.Fatalf("stranger sees %v", types)
	}
	if h.inboxTypes(seeker)[confirmNeeded] != 1 {
		t.Fatal("seeker should see it")
	}
}
