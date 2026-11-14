package app_test

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/platform/mongodb"
)

// Enough of a PNG for content sniffing.
var pngBytes = append([]byte("\x89PNG\r\n\x1a\n"), make([]byte, 64)...)

func (h *harness) raw(method, path, token string, body []byte) (int, []byte, http.Header) {
	h.t.Helper()
	req, err := http.NewRequest(method, h.srv.URL+path, bytes.NewReader(body))
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
	out, _ := io.ReadAll(res.Body)
	return res.StatusCode, out, res.Header
}

// assignedJob returns a job with an accepted bid and a losing bidder.
func (h *harness) assignedJob() (seeker, provider, loser account, jobID string) {
	h.t.Helper()
	seeker = h.login()
	provider = h.provider(ktmLat, ktmLng, 5000, 1)
	loser = h.provider(ktmLat, ktmLng, 5000, 1)
	h.topUp(seeker, 500000)
	jobID = h.createJob(seeker, ktmLat, ktmLng, 1)
	bidID := h.bid(provider, jobID, 100000)
	h.bid(loser, jobID, 120000)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", seeker.access, nil)
	return seeker, provider, loser, jobID
}

func TestJobPhotos(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	offered := h.provider(ktmLat, ktmLng, 5000, 1)
	stranger := h.login()
	jobID := h.createJob(seeker, ktmLat, ktmLng, 1)
	photos := "/v1/jobs/" + jobID + "/photos"

	if status, _, _ := h.raw("POST", photos, seeker.access, []byte("<script>alert(1)</script>")); status != 400 {
		t.Fatalf("non-image upload = %d", status)
	}
	if status, _, _ := h.raw("POST", photos, seeker.access, make([]byte, 5<<20+1)); status != 413 {
		t.Fatalf("oversized upload = %d", status)
	}
	if status, _, _ := h.raw("POST", photos, offered.access, pngBytes); status != 404 {
		t.Fatalf("provider upload = %d", status)
	}

	for i := range 4 {
		if status, body, _ := h.raw("POST", photos, seeker.access, pngBytes); status != 201 {
			t.Fatalf("upload %d = %d: %s", i, status, body)
		}
	}
	if status, _, _ := h.raw("POST", photos, seeker.access, pngBytes); status != 409 {
		t.Fatalf("fifth upload = %d", status)
	}
	first := h.must(200, "GET", "/v1/jobs/"+jobID, seeker.access, nil)["photo_ids"].([]any)[0].(string)

	status, body, headers := h.raw("GET", photos+"/"+first, offered.access, nil)
	if status != 200 || !bytes.Equal(body, pngBytes) {
		t.Fatalf("offered provider read = %d", status)
	}
	if headers.Get("Content-Type") != "image/png" || headers.Get("X-Content-Type-Options") != "nosniff" {
		t.Fatalf("headers = %v", headers)
	}
	if status, _, _ := h.raw("GET", photos+"/"+first, stranger.access, nil); status != 404 {
		t.Fatalf("stranger read = %d", status)
	}
	if status, _, _ := h.raw("GET", photos+"/"+first, "", nil); status != 401 {
		t.Fatalf("anonymous read = %d", status)
	}

	h.must(404, "DELETE", photos+"/"+first, offered.access, nil)
	h.must(204, "DELETE", photos+"/"+first, seeker.access, nil)
	h.must(404, "DELETE", photos+"/"+first, seeker.access, nil)
	if status, _, _ := h.raw("POST", photos, seeker.access, pngBytes); status != 201 {
		t.Fatalf("upload after delete = %d", status)
	}
}

func TestPhotosFreezeOnceWorkStarts(t *testing.T) {
	h := newHarness(t)
	seeker, _, jobID := h.startedJob()
	if status, _, _ := h.raw("POST", "/v1/jobs/"+jobID+"/photos", seeker.access, pngBytes); status != 409 {
		t.Fatalf("upload during work = %d", status)
	}
}

func TestExactPinIsHiddenUntilAssigned(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	provider := h.provider(ktmLat, ktmLng, 5000, 1)
	h.topUp(seeker, 500000)
	lat, lng := ktmLat+0.00123, ktmLng+0.00456
	jobID := h.must(201, "POST", "/v1/jobs", seeker.access, map[string]any{
		"category_id": 1, "description": "Leak", "address": "Home", "lat": lat, "lng": lng,
	})["id"].(string)
	coords := func(a account) []any {
		loc := h.must(200, "GET", "/v1/jobs/"+jobID, a.access, nil)["job_location"].(map[string]any)
		return loc["coordinates"].([]any)
	}
	blurred := func(c []any) bool {
		for _, v := range c {
			f := v.(float64) * 100
			if f-float64(int(f+0.5)) > 1e-6 || float64(int(f+0.5))-f > 1e-6 {
				return false
			}
		}
		return true
	}

	if c := coords(seeker); c[0] != lng || c[1] != lat {
		t.Fatalf("seeker sees %v", c)
	}
	if c := coords(provider); !blurred(c) {
		t.Fatalf("offered provider sees %v", c)
	}
	feed := h.must(200, "GET", "/v1/jobs/feed", provider.access, nil)["items"].([]any)
	if c := feed[0].(map[string]any)["job_location"].(map[string]any)["coordinates"].([]any); !blurred(c) {
		t.Fatalf("feed shows %v", c)
	}

	bidID := h.bid(provider, jobID, 100000)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/bids/"+bidID+"/accept", seeker.access, nil)
	if c := coords(provider); c[0] != lng || c[1] != lat {
		t.Fatalf("assigned provider sees %v", c)
	}
}

func when(days int, slot string) map[string]any {
	return map[string]any{"preferred_date": time.Now().AddDate(0, 0, days).Format(time.DateOnly), "preferred_slot": slot}
}

func TestRescheduleBeforeAssignment(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	jobID := h.createJob(seeker, ktmLat, ktmLng, 1)
	path := "/v1/jobs/" + jobID + "/reschedule"

	h.must(400, "POST", path, seeker.access, when(1, "99-99"))
	h.must(400, "POST", path, seeker.access, when(60, "08-10"))
	h.must(404, "POST", path, h.login().access, when(1, "08-10"))
	m := h.must(200, "POST", path, seeker.access, when(1, "08-10"))
	if m["preferred_slot"] != "08-10" || m["reschedule_count"] != 1.0 {
		t.Fatalf("after reschedule: %v", m)
	}
}

func TestRescheduleTellsTheProviderAndIsLimited(t *testing.T) {
	h := newHarness(t)
	seeker, provider, _, jobID := h.assignedJob()
	path := "/v1/jobs/" + jobID + "/reschedule"

	h.must(403, "POST", path, provider.access, when(2, "10-12"))
	for i := range 3 {
		h.must(200, "POST", path, seeker.access, when(i+1, "10-12"))
	}
	h.must(409, "POST", path, seeker.access, when(4, "10-12"))
	h.deliver(time.Second)
	if got := h.inboxTypes(provider)["job.rescheduled"]; got != 3 {
		t.Fatalf("provider was told %d times", got)
	}
}

func TestRescheduleStopsOnceWorkStarts(t *testing.T) {
	h := newHarness(t)
	seeker, _, jobID := h.startedJob()
	h.must(409, "POST", "/v1/jobs/"+jobID+"/reschedule", seeker.access, when(1, "08-10"))
}

func TestLiveTracking(t *testing.T) {
	h := newHarness(t)
	seeker, provider, loser, jobID := h.assignedJob()
	path := "/v1/jobs/" + jobID + "/tracking"
	here := map[string]float64{"lat": 27.7, "lng": 85.3}

	if m := h.must(200, "GET", path, seeker.access, nil); m["active"] != false {
		t.Fatalf("before sharing: %v", m)
	}
	h.must(403, "PUT", path, seeker.access, here)
	h.must(404, "PUT", path, loser.access, here)
	h.must(404, "GET", path, loser.access, nil)
	h.must(400, "PUT", path, provider.access, map[string]float64{"lat": 200, "lng": 0})

	h.must(204, "PUT", path, provider.access, here)
	m := h.must(200, "GET", path, seeker.access, nil)
	if m["active"] != true || m["lat"] != 27.7 || m["lng"] != 85.3 {
		t.Fatalf("while sharing: %v", m)
	}
	if _, leaked := h.must(200, "GET", "/v1/jobs/"+jobID, seeker.access, nil)["provider_location"]; leaked {
		t.Fatal("position leaked into the job")
	}

	h.must(204, "DELETE", path, provider.access, nil)
	if m := h.must(200, "GET", path, seeker.access, nil); m["active"] != false {
		t.Fatalf("after stopping: %v", m)
	}
}

func TestStalePositionIsNotLive(t *testing.T) {
	h := newHarness(t)
	seeker, provider, _, jobID := h.assignedJob()
	path := "/v1/jobs/" + jobID + "/tracking"
	h.must(204, "PUT", path, provider.access, map[string]float64{"lat": 27.7, "lng": 85.3})
	_, err := h.db.Collection(mongodb.Jobs).UpdateOne(context.Background(), bson.M{"_id": jobID},
		bson.M{"$set": bson.M{"provider_location.at": time.Now().Add(-time.Hour)}})
	if err != nil {
		t.Fatal(err)
	}
	if m := h.must(200, "GET", path, seeker.access, nil); m["active"] != false {
		t.Fatalf("stale position: %v", m)
	}
}

func TestPositionIsErasedWhenTheJobEnds(t *testing.T) {
	h := newHarness(t)
	seeker, provider, jobID := h.startedJob()
	path := "/v1/jobs/" + jobID + "/tracking"
	h.must(204, "PUT", path, provider.access, map[string]float64{"lat": 27.7, "lng": 85.3})
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", provider.access, nil)
	h.must(200, "POST", "/v1/jobs/"+jobID+"/confirm", seeker.access, nil)

	h.must(409, "PUT", path, provider.access, map[string]float64{"lat": 27.7, "lng": 85.3})
	var doc bson.M
	if err := h.db.Collection(mongodb.Jobs).FindOne(context.Background(), bson.M{"_id": jobID}).Decode(&doc); err != nil {
		t.Fatal(err)
	}
	if _, kept := doc["provider_location"]; kept {
		t.Fatal("position kept after the job ended")
	}
}

func TestFavouritesAndAskingThemDirectly(t *testing.T) {
	h := newHarness(t)
	seeker := h.login()
	// Too far away to be offered the job normally.
	favourite := h.provider(ktmLat+1, ktmLng+1, 1000, 1)
	wrongTrade := h.provider(ktmLat+1, ktmLng+1, 1000, 2)
	notProvider := h.login()

	h.must(400, "PUT", "/v1/me/favorites/"+notProvider.id, seeker.access, nil)
	h.must(400, "PUT", "/v1/me/favorites/"+seeker.id, seeker.access, nil)
	h.must(404, "PUT", "/v1/me/favorites/nobody", seeker.access, nil)
	h.must(204, "PUT", "/v1/me/favorites/"+favourite.id, seeker.access, nil)
	h.must(204, "PUT", "/v1/me/favorites/"+favourite.id, seeker.access, nil)
	rows := h.must(200, "GET", "/v1/me/favorites", seeker.access, nil)["items"].([]any)
	if len(rows) != 1 || rows[0].(map[string]any)["id"] != favourite.id {
		t.Fatalf("favourites = %v", rows)
	}

	job := func(providerID string) map[string]any {
		return map[string]any{
			"category_id": 1, "description": "Same again", "address": "Home",
			"lat": ktmLat, "lng": ktmLng, "preferred_provider_id": providerID,
		}
	}
	h.must(400, "POST", "/v1/jobs", seeker.access, job(wrongTrade.id))
	h.must(400, "POST", "/v1/jobs", seeker.access, job("nobody"))
	jobID := h.must(201, "POST", "/v1/jobs", seeker.access, job(favourite.id))["id"].(string)
	h.must(200, "GET", "/v1/jobs/"+jobID, favourite.access, nil)
	h.bid(favourite, jobID, 100000)

	h.must(204, "DELETE", "/v1/me/favorites/"+favourite.id, seeker.access, nil)
	if rows := h.must(200, "GET", "/v1/me/favorites", seeker.access, nil)["items"].([]any); len(rows) != 0 {
		t.Fatalf("after removal: %v", rows)
	}
}
