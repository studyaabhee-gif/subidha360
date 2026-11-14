package auth

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"regexp"
	"time"

	"github.com/redis/go-redis/v9"

	"subidha360/backend/internal/apperr"
)

const (
	otpMaxAttempts = 5
	otpCooldown    = time.Minute
)

var (
	nepalMobile   = regexp.MustCompile(`^\+9779\d{9}$`)
	errInvalidOTP = apperr.Unauthorized("invalid_otp", "code is incorrect or expired")
)

// SMSSender delivers a text message.
type SMSSender interface {
	Send(ctx context.Context, phone, message string) error
}

// LogSMSSender writes messages to the log, including OTP codes. Development only.
type LogSMSSender struct{}

func (LogSMSSender) Send(_ context.Context, phone, message string) error {
	slog.Info("dev sms", "to", phone, "message", message)
	return nil
}

type otps struct {
	rdb    *redis.Client
	sms    SMSSender
	secret []byte
	ttl    time.Duration
}

func otpKey(phone string) string      { return "otp:code:" + phone }
func attemptsKey(phone string) string { return "otp:attempts:" + phone }
func cooldownKey(phone string) string { return "otp:cooldown:" + phone }

// hash keys the digest with a server secret, since an unkeyed hash of a 6-digit
// code could be reversed instantly by anyone who can read Redis.
func (o *otps) hash(phone, code string) string {
	mac := hmac.New(sha256.New, o.secret)
	mac.Write([]byte(phone + ":" + code))
	return hex.EncodeToString(mac.Sum(nil))
}

func (o *otps) request(ctx context.Context, phone string) error {
	if !nepalMobile.MatchString(phone) {
		return apperr.BadRequest("invalid_phone", "phone must look like +9779XXXXXXXXX")
	}
	allowed, err := o.rdb.SetNX(ctx, cooldownKey(phone), 1, otpCooldown).Result()
	if err != nil {
		return fmt.Errorf("otp cooldown: %w", err)
	}
	if !allowed {
		return apperr.TooManyRequests("otp_cooldown", "wait a minute before requesting another code")
	}

	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return fmt.Errorf("generate otp: %w", err)
	}
	code := fmt.Sprintf("%06d", n.Int64())
	if err := o.rdb.Set(ctx, otpKey(phone), o.hash(phone, code), o.ttl).Err(); err != nil {
		return fmt.Errorf("store otp: %w", err)
	}
	if err := o.sms.Send(ctx, phone, "Your Subidha360 code is "+code); err != nil {
		o.rdb.Del(ctx, otpKey(phone), cooldownKey(phone))
		slog.Error("send otp failed", "err", err)
		return apperr.New(http.StatusServiceUnavailable, "sms_unavailable", "could not send a code right now, please try again")
	}
	return nil
}

func (o *otps) verify(ctx context.Context, phone, code string) error {
	// Attempts are not reset by requesting a new code, so resending cannot be
	// used to get more guesses.
	attempts, err := o.rdb.Incr(ctx, attemptsKey(phone)).Result()
	if err != nil {
		return fmt.Errorf("count otp attempts: %w", err)
	}
	if attempts == 1 {
		if err := o.rdb.Expire(ctx, attemptsKey(phone), o.ttl).Err(); err != nil {
			return fmt.Errorf("expire otp attempts: %w", err)
		}
	}
	if attempts > otpMaxAttempts {
		o.rdb.Del(ctx, otpKey(phone))
		return apperr.TooManyRequests("otp_locked", "too many attempts, try again later")
	}

	stored, err := o.rdb.Get(ctx, otpKey(phone)).Result()
	if errors.Is(err, redis.Nil) {
		return errInvalidOTP
	}
	if err != nil {
		return fmt.Errorf("read otp: %w", err)
	}
	if !hmac.Equal([]byte(stored), []byte(o.hash(phone, code))) {
		return errInvalidOTP
	}

	// Del reports how many keys it removed, so only one caller can consume a code.
	deleted, err := o.rdb.Del(ctx, otpKey(phone)).Result()
	if err != nil {
		return fmt.Errorf("consume otp: %w", err)
	}
	if deleted == 0 {
		return errInvalidOTP
	}
	o.rdb.Del(ctx, attemptsKey(phone))
	return nil
}
