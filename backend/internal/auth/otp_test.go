package auth

import (
	"context"
	"errors"
	"net/http"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"

	"subidha360/backend/internal/apperr"
)

type failingSMS struct {
	err   error
	calls int
}

func (f *failingSMS) Send(context.Context, string, string) error {
	f.calls++
	return f.err
}

func TestFailedSMSAllowsAnImmediateRetry(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { rdb.Close() })
	sms := &failingSMS{err: errors.New("gateway down")}
	o := &otps{rdb: rdb, sms: sms, secret: []byte("secret"), ttl: time.Minute}
	const phone = "+9779812345678"
	ctx := context.Background()

	err := o.request(ctx, phone)

	var e *apperr.Error
	if !errors.As(err, &e) || e.Status != http.StatusServiceUnavailable {
		t.Fatalf("err = %v", err)
	}
	if mr.Exists(otpKey(phone)) {
		t.Fatal("an undelivered code must not stay valid")
	}

	sms.err = nil
	if err := o.request(ctx, phone); err != nil {
		t.Fatalf("user should be able to retry straight away: %v", err)
	}
	if sms.calls != 2 {
		t.Fatalf("calls = %d", sms.calls)
	}
}
