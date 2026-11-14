// Package sms sends text messages through Sparrow SMS.
package sms

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

// Sparrow's docs only show http, but https works, and this traffic carries the
// API token and login codes.
const (
	sparrowURL     = "https://api.sparrowsms.com/v2"
	sparrowTimeout = 10 * time.Second
	maxResponseLen = 4096
	successCode    = 200
)

// Sparrow error codes that need an operator rather than a retry.
const (
	codeInvalidIP          = 1001
	codeInvalidToken       = 1002
	codeAccountInactive    = 1003
	codeAccountInactive2   = 1004
	codeAccountExpired     = 1005
	codeAccountExpired2    = 1006
	codeInvalidSender      = 1008
	codeNoCredits          = 1012
	codeInsufficientCredit = 1013
)

var localMobile = regexp.MustCompile(`^9\d{9}$`)

// APIError is an error reported by Sparrow itself.
type APIError struct {
	Code    int
	Message string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("sparrow error %d: %s", e.Code, e.Message)
}

// NeedsOperator reports whether the account or setup is at fault, so every send
// will fail until a person fixes it.
func (e *APIError) NeedsOperator() bool {
	switch e.Code {
	case codeInvalidIP, codeInvalidToken, codeAccountInactive, codeAccountInactive2,
		codeAccountExpired, codeAccountExpired2, codeInvalidSender, codeNoCredits, codeInsufficientCredit:
		return true
	}
	return false
}

// Sparrow implements auth.SMSSender and notify.SMSSender.
type Sparrow struct {
	url   string
	token string
	from  string
	http  *http.Client
}

// NewSparrow builds a client from an API token and approved sender identity.
func NewSparrow(token, from string) *Sparrow {
	return &Sparrow{
		url:   sparrowURL,
		token: token,
		from:  from,
		http:  &http.Client{Timeout: sparrowTimeout},
	}
}

// localNumber converts +9779XXXXXXXXX to the 10-digit form Sparrow documents.
func localNumber(phone string) (string, error) {
	local := strings.TrimPrefix(phone, "+977")
	if !localMobile.MatchString(local) {
		return "", errors.New("not a Nepali mobile number")
	}
	return local, nil
}

type response struct {
	ResponseCode     int     `json:"response_code"`
	Response         string  `json:"response"`
	Count            *int    `json:"count"`
	CreditsAvailable float64 `json:"credits_available"`
}

// do sends a request and returns Sparrow's reply. A successful HTTP status alone
// is not trusted: the reply must also carry the success code.
func (s *Sparrow) do(req *http.Request) (*response, error) {
	res, err := s.http.Do(req)
	if err != nil {
		// The default message includes the URL, which can contain the token.
		var urlErr *url.Error
		if errors.As(err, &urlErr) {
			err = urlErr.Err
		}
		return nil, fmt.Errorf("sparrow request: %w", err)
	}
	defer res.Body.Close()

	raw, err := io.ReadAll(io.LimitReader(res.Body, maxResponseLen))
	if err != nil {
		return nil, fmt.Errorf("read sparrow response: %w", err)
	}
	var parsed response
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return nil, fmt.Errorf("sparrow returned status %d with an unreadable body", res.StatusCode)
	}
	if parsed.ResponseCode != successCode {
		apiErr := &APIError{Code: parsed.ResponseCode, Message: parsed.Response}
		if apiErr.NeedsOperator() {
			slog.Error("sparrow account needs attention", "code", apiErr.Code, "message", apiErr.Message)
		}
		return nil, apiErr
	}
	return &parsed, nil
}

// Send delivers one message. Sparrow queues it, so success means accepted, not
// yet received.
func (s *Sparrow) Send(ctx context.Context, phone, message string) error {
	to, err := localNumber(phone)
	if err != nil {
		return err
	}
	form := url.Values{"token": {s.token}, "from": {s.from}, "to": {to}, "text": {message}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.url+"/sms/", strings.NewReader(form.Encode()))
	if err != nil {
		return errors.New("build sparrow request failed")
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	parsed, err := s.do(req)
	if err != nil {
		return err
	}
	if parsed.Count != nil && *parsed.Count < 1 {
		return errors.New("sparrow accepted the request but queued no messages")
	}
	return nil
}

// Credits returns the remaining balance. It sends nothing and costs nothing, so
// it doubles as a check that the token works.
func (s *Sparrow) Credits(ctx context.Context) (float64, error) {
	query := url.Values{"token": {s.token}}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.url+"/credit/?"+query.Encode(), nil)
	if err != nil {
		return 0, errors.New("build sparrow request failed")
	}
	parsed, err := s.do(req)
	if err != nil {
		return 0, err
	}
	return parsed.CreditsAvailable, nil
}
