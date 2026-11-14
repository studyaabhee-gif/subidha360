package sms

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

const testToken = "secret-test-token"

func fakeSparrow(t *testing.T, status int, body string, seen *http.Request) *Sparrow {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if seen != nil {
			if err := r.ParseForm(); err != nil {
				t.Error(err)
			}
			*seen = *r
		}
		w.WriteHeader(status)
		w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	s := NewSparrow(testToken, "Subidha")
	s.url = srv.URL
	s.http = srv.Client()
	return s
}

func TestDefaultURLIsEncrypted(t *testing.T) {
	if s := NewSparrow("t", "f"); !strings.HasPrefix(s.url, "https://") {
		t.Fatalf("url = %s", s.url)
	}
}

func TestSendPostsTheDocumentedForm(t *testing.T) {
	var seen http.Request
	s := fakeSparrow(t, 200, `{"count":1,"response_code":200,"response":"1 mesages has been queued for delivery"}`, &seen)

	if err := s.Send(context.Background(), "+9779812345678", "Your code is 123456"); err != nil {
		t.Fatal(err)
	}
	if seen.Method != "POST" || seen.URL.Path != "/sms/" {
		t.Errorf("%s %s", seen.Method, seen.URL.Path)
	}
	want := map[string]string{"token": testToken, "from": "Subidha", "to": "9812345678", "text": "Your code is 123456"}
	for k, v := range want {
		if got := seen.PostForm.Get(k); got != v {
			t.Errorf("%s = %q, want %q", k, got, v)
		}
	}
	if seen.URL.RawQuery != "" {
		t.Errorf("message must not travel in the URL: %q", seen.URL.RawQuery)
	}
}

func TestLocalNumber(t *testing.T) {
	valid := map[string]string{"+9779812345678": "9812345678", "9812345678": "9812345678"}
	for in, want := range valid {
		if got, err := localNumber(in); err != nil || got != want {
			t.Errorf("localNumber(%s) = %s, %v", in, got, err)
		}
	}
	for _, in := range []string{"", "+977981234567", "+97798123456789", "+9771234567890", "+15551234567", "98123abc78"} {
		if _, err := localNumber(in); err == nil {
			t.Errorf("localNumber(%q) should fail", in)
		}
	}
}

func TestInvalidNumberIsNotSent(t *testing.T) {
	called := false
	srv := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { called = true }))
	t.Cleanup(srv.Close)
	s := NewSparrow(testToken, "Subidha")
	s.url = srv.URL

	if err := s.Send(context.Background(), "+15551234567", "hi"); err == nil {
		t.Fatal("expected error")
	}
	if called {
		t.Fatal("must not call the API")
	}
}

func TestAPIErrors(t *testing.T) {
	tests := []struct {
		name     string
		body     string
		code     int
		operator bool
	}{
		{"bad token", `{"response_code":1002,"response":"Invalid Token","requested_ip":"1.2.3.4"}`, 1002, true},
		{"ip blocked", `{"response_code":1001,"response":"Invalid IP Address"}`, 1001, true},
		{"no credits", `{"response_code":1012,"response":"No Credits Available"}`, 1012, true},
		{"bad sender", `{"response_code":1008,"response":"Invalid Sender"}`, 1008, true},
		{"bad receiver", `{"response_code":1007,"response":"Invalid Receiver"}`, 1007, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s := fakeSparrow(t, 403, tt.body, nil)
			err := s.Send(context.Background(), "+9779812345678", "hi")
			var apiErr *APIError
			if !errors.As(err, &apiErr) {
				t.Fatalf("err = %v", err)
			}
			if apiErr.Code != tt.code || apiErr.NeedsOperator() != tt.operator {
				t.Fatalf("code = %d, operator = %v", apiErr.Code, apiErr.NeedsOperator())
			}
		})
	}
}

func TestUntrustworthyReplies(t *testing.T) {
	tests := map[string]struct {
		status int
		body   string
	}{
		"status ok but error code": {200, `{"response_code":1013,"response":"Insufficient Credits"}`},
		"nothing queued":           {200, `{"count":0,"response_code":200,"response":"0 mesages"}`},
		"html error page":          {502, `<html>bad gateway</html>`},
		"empty body":               {200, ``},
		"no response code":         {200, `{"hello":"world"}`},
	}
	for name, tt := range tests {
		s := fakeSparrow(t, tt.status, tt.body, nil)
		if err := s.Send(context.Background(), "+9779812345678", "hi"); err == nil {
			t.Errorf("%s: expected error", name)
		}
	}
}

func TestCredits(t *testing.T) {
	var seen http.Request
	s := fakeSparrow(t, 200, `{"credits_available":1250,"credits_consumed":3,"response_code":200}`, &seen)

	got, err := s.Credits(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if got != 1250 {
		t.Fatalf("credits = %v", got)
	}
	if seen.Method != "GET" || seen.URL.Path != "/credit/" || seen.URL.Query().Get("token") != testToken {
		t.Fatalf("%s %s", seen.Method, seen.URL.Path)
	}
}

func TestNetworkErrorsDoNotLeakTheToken(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	dead := srv.URL
	srv.Close()

	s := NewSparrow(testToken, "Subidha")
	s.url = dead

	_, creditsErr := s.Credits(context.Background())
	sendErr := s.Send(context.Background(), "+9779812345678", "code 123456")
	for name, err := range map[string]error{"credits": creditsErr, "send": sendErr} {
		if err == nil {
			t.Fatalf("%s: expected error", name)
		}
		if strings.Contains(err.Error(), testToken) || strings.Contains(err.Error(), url.QueryEscape(testToken)) {
			t.Errorf("%s leaked the token: %v", name, err)
		}
	}
}

// TestSparrowLive checks the client against the real API. A made-up token is
// always rejected, so that part sends nothing and costs nothing. With a real
// SPARROW_TOKEN it also reads the balance, which is free. It never sends an SMS.
func TestSparrowLive(t *testing.T) {
	if os.Getenv("SPARROW_LIVE_TEST") != "1" {
		t.Skip("set SPARROW_LIVE_TEST=1 to run")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	fake := NewSparrow("subidha360-fake-live-test", "Test")
	var apiErr *APIError
	if err := fake.Send(ctx, "+9779800000000", "test"); !errors.As(err, &apiErr) || apiErr.Code != codeInvalidToken {
		t.Fatalf("send with fake token: %v", err)
	}
	if _, err := fake.Credits(ctx); !errors.As(err, &apiErr) || apiErr.Code != codeInvalidToken {
		t.Fatalf("credits with fake token: %v", err)
	}

	token := os.Getenv("SPARROW_TOKEN")
	if token == "" {
		t.Log("SPARROW_TOKEN not set; skipped the real balance check")
		return
	}
	credits, err := NewSparrow(token, "").Credits(ctx)
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("credits available: %v", credits)
}
