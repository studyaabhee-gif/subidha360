package notify

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"
)

// TestFCMLiveRejectsFakeToken checks the credentials and client against real
// Firebase. It sends to a made-up token, so no device can receive anything. A
// rejected token proves authentication worked, since Firebase checks that first.
// It runs only when FCM_LIVE_TEST=1.
func TestFCMLiveRejectsFakeToken(t *testing.T) {
	if os.Getenv("FCM_LIVE_TEST") != "1" {
		t.Skip("set FCM_LIVE_TEST=1, FCM_PROJECT_ID and FCM_CREDENTIALS_FILE to run")
	}
	credentials, err := os.ReadFile(os.Getenv("FCM_CREDENTIALS_FILE"))
	if err != nil {
		t.Fatal("cannot read credentials file")
	}
	f, err := NewFCM(os.Getenv("FCM_PROJECT_ID"), credentials)
	if err != nil {
		t.Fatal(err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	err = f.Push(ctx, Push{
		Token: "subidha360-live-test-not-a-real-device",
		Title: "Test",
		Body:  "Test",
		Data:  map[string]string{"type": "test"},
	})
	if !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("want ErrInvalidToken from Firebase, got: %v", err)
	}
}
