package notify

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func fakeFCM(t *testing.T, status int, body string, seen *map[string]any) *FCM {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if seen != nil {
			if err := json.NewDecoder(r.Body).Decode(seen); err != nil {
				t.Error(err)
			}
		}
		w.WriteHeader(status)
		w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	return &FCM{url: srv.URL, http: srv.Client()}
}

func TestFCMSendsTheDocumentedMessageShape(t *testing.T) {
	var seen map[string]any
	f := fakeFCM(t, 200, `{"name":"projects/p/messages/1"}`, &seen)

	err := f.Push(context.Background(), Push{
		Token: "tok", Title: "Hi", Body: "There", Data: map[string]string{"job_id": "j1"},
	})
	if err != nil {
		t.Fatal(err)
	}
	m := seen["message"].(map[string]any)
	if m["token"] != "tok" {
		t.Errorf("token = %v", m["token"])
	}
	if n := m["notification"].(map[string]any); n["title"] != "Hi" || n["body"] != "There" {
		t.Errorf("notification = %v", n)
	}
	if d := m["data"].(map[string]any); d["job_id"] != "j1" {
		t.Errorf("data = %v", d)
	}
}

func TestFCMDeadTokens(t *testing.T) {
	for _, code := range []string{"UNREGISTERED", "INVALID_ARGUMENT", "SENDER_ID_MISMATCH"} {
		f := fakeFCM(t, 404, `{"error":{"status":"NOT_FOUND","details":[{"errorCode":"`+code+`"}]}}`, nil)
		if err := f.Push(context.Background(), Push{Token: "tok"}); !errors.Is(err, ErrInvalidToken) {
			t.Errorf("%s: err = %v", code, err)
		}
	}
}

func TestFCMTemporaryFailuresAreRetryable(t *testing.T) {
	cases := map[string]struct {
		status int
		body   string
	}{
		"unavailable":  {503, `{"error":{"status":"UNAVAILABLE","details":[{"errorCode":"UNAVAILABLE"}]}}`},
		"rate limited": {429, `{"error":{"status":"RESOURCE_EXHAUSTED","details":[{"errorCode":"QUOTA_EXCEEDED"}]}}`},
		"bad auth":     {401, `{"error":{"status":"UNAUTHENTICATED"}}`},
		"not json":     {502, `<html>bad gateway</html>`},
	}
	for name, c := range cases {
		f := fakeFCM(t, c.status, c.body, nil)
		err := f.Push(context.Background(), Push{Token: "tok"})
		if err == nil || errors.Is(err, ErrInvalidToken) {
			t.Errorf("%s: err = %v", name, err)
		}
	}
}

func TestBackoffDoublesThenCaps(t *testing.T) {
	want := map[int]time.Duration{1: 30 * time.Second, 2: time.Minute, 3: 2 * time.Minute, 20: time.Hour}
	for attempts, d := range want {
		if got := backoff(attempts); got != d {
			t.Errorf("backoff(%d) = %v, want %v", attempts, got, d)
		}
	}
}
