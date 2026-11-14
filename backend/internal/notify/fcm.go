package notify

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"golang.org/x/oauth2/google"
)

const (
	fcmScope    = "https://www.googleapis.com/auth/firebase.messaging"
	fcmTimeout  = 10 * time.Second
	maxErrorLen = 4096
)

// FCM sends through the Firebase Cloud Messaging HTTP v1 API.
type FCM struct {
	url  string
	http *http.Client
}

// NewFCM builds a client from a Firebase service account JSON key.
func NewFCM(projectID string, serviceAccount []byte) (*FCM, error) {
	conf, err := google.JWTConfigFromJSON(serviceAccount, fcmScope)
	if err != nil {
		return nil, fmt.Errorf("read fcm credentials: %w", err)
	}
	client := conf.Client(context.Background())
	client.Timeout = fcmTimeout
	return &FCM{
		url:  "https://fcm.googleapis.com/v1/projects/" + projectID + "/messages:send",
		http: client,
	}, nil
}

type fcmError struct {
	Error struct {
		Status  string `json:"status"`
		Details []struct {
			ErrorCode string `json:"errorCode"`
		} `json:"details"`
	} `json:"error"`
}

// Push implements Pusher.
func (f *FCM) Push(ctx context.Context, p Push) error {
	body, err := json.Marshal(map[string]any{"message": map[string]any{
		"token":        p.Token,
		"notification": map[string]string{"title": p.Title, "body": p.Body},
		"data":         p.Data,
		"android":      map[string]string{"priority": "HIGH"},
		"apns":         map[string]any{"headers": map[string]string{"apns-priority": "10"}},
	}})
	if err != nil {
		return fmt.Errorf("encode fcm message: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.url, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("build fcm request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	res, err := f.http.Do(req)
	if err != nil {
		return fmt.Errorf("fcm request: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode == http.StatusOK {
		return nil
	}

	raw, _ := io.ReadAll(io.LimitReader(res.Body, maxErrorLen))
	var parsed fcmError
	_ = json.Unmarshal(raw, &parsed)
	if tokenIsDead(parsed) {
		return ErrInvalidToken
	}
	return fmt.Errorf("fcm returned %d: %s", res.StatusCode, parsed.Error.Status)
}

// tokenIsDead recognises the errors Firebase documents for tokens to discard.
// INVALID_ARGUMENT can also mean a bad payload, but ours has a fixed shape, so
// here the token is the only variable.
func tokenIsDead(e fcmError) bool {
	for _, d := range e.Error.Details {
		if d.ErrorCode == "UNREGISTERED" || d.ErrorCode == "INVALID_ARGUMENT" || d.ErrorCode == "SENDER_ID_MISMATCH" {
			return true
		}
	}
	return false
}
