// Package auth handles OTP login, JWT sessions and the current user's profile.
package auth

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/user"
)

// AccountCreator provisions a user's wallet on login.
type AccountCreator interface {
	EnsureUserAccount(ctx context.Context, userID string) error
}

type Options struct {
	Secret     string
	AccessTTL  time.Duration
	RefreshTTL time.Duration
	OTPTTL     time.Duration
}

type Service struct {
	otps     *otps
	tokens   *tokens
	users    *user.Repo
	accounts AccountCreator
}

func NewService(rdb *redis.Client, sms SMSSender, users *user.Repo, accounts AccountCreator, o Options) *Service {
	secret := []byte(o.Secret)
	return &Service{
		otps:     &otps{rdb: rdb, sms: sms, secret: secret, ttl: o.OTPTTL},
		tokens:   &tokens{secret: secret, accessTTL: o.AccessTTL, refreshTTL: o.RefreshTTL, rdb: rdb},
		users:    users,
		accounts: accounts,
	}
}

// VerifyOTP checks a code and logs the user in, creating them on first login.
func (s *Service) VerifyOTP(ctx context.Context, phone, code string) (*user.User, TokenPair, error) {
	if err := s.otps.verify(ctx, phone, code); err != nil {
		return nil, TokenPair{}, err
	}
	u, err := s.users.FindOrCreateByPhone(ctx, phone)
	if err != nil {
		return nil, TokenPair{}, err
	}
	if u.Suspension != nil {
		return nil, TokenPair{}, errSuspended
	}
	if err := s.accounts.EnsureUserAccount(ctx, u.ID); err != nil {
		return nil, TokenPair{}, err
	}
	pair, err := s.tokens.issue(u.ID)
	if err != nil {
		return nil, TokenPair{}, err
	}
	return u, pair, nil
}

// Refresh rotates a refresh token. Each one works once, so a stolen token that
// has already been used cannot be replayed.
func (s *Service) Refresh(ctx context.Context, raw string) (TokenPair, error) {
	c, err := s.tokens.parse(raw, tokenRefresh)
	if err != nil {
		return TokenPair{}, err
	}
	first, err := s.tokens.block(ctx, c)
	if err != nil {
		return TokenPair{}, err
	}
	if !first {
		return TokenPair{}, errInvalidToken
	}
	// Checked against the database, so a suspension still holds if Redis lost
	// its copy.
	u, err := s.users.Get(ctx, c.Subject)
	if err != nil {
		return TokenPair{}, err
	}
	if u.Suspension != nil {
		return TokenPair{}, errSuspended
	}
	return s.tokens.issue(c.Subject)
}

// Logout blocklists the current access token and the given refresh token.
func (s *Service) Logout(ctx context.Context, access *claims, refreshRaw string) error {
	refresh, err := s.tokens.parse(refreshRaw, tokenRefresh)
	if err != nil {
		return err
	}
	if refresh.Subject != access.Subject {
		return apperr.Forbidden("token_mismatch", "refresh token belongs to another user")
	}
	if _, err := s.tokens.block(ctx, access); err != nil {
		return err
	}
	_, err = s.tokens.block(ctx, refresh)
	return err
}

// errSuspended stops a locked account at login, refresh and every request.
var errSuspended = apperr.Forbidden("account_suspended", "this account is suspended. Contact support for help")

// MarkSuspended makes every request from a user fail at once, without waiting
// for their access token to expire. The database stays the record; this is
// the fast copy that Require reads.
func (s *Service) MarkSuspended(ctx context.Context, userID string, suspended bool) error {
	if suspended {
		return s.tokens.rdb.Set(ctx, suspendKey(userID), 1, 0).Err()
	}
	return s.tokens.rdb.Del(ctx, suspendKey(userID)).Err()
}

type ctxKey struct{}

// UserID returns the authenticated user's ID. Only valid behind Require.
func UserID(ctx context.Context) string {
	c, _ := ctx.Value(ctxKey{}).(*claims)
	if c == nil {
		return ""
	}
	return c.Subject
}

// RequireAdmin is Require plus a check of the stored is_admin flag, so revoking
// an admin takes effect immediately rather than when their token expires.
func (s *Service) RequireAdmin(next http.HandlerFunc) http.Handler {
	return s.Require(func(w http.ResponseWriter, r *http.Request) {
		u, err := s.users.Get(r.Context(), UserID(r.Context()))
		if err != nil {
			httpx.Error(w, err)
			return
		}
		if !u.IsAdmin {
			httpx.Error(w, apperr.Forbidden("admin_required", "this action needs an admin account"))
			return
		}
		next(w, r)
	})
}

// Require rejects requests without a valid, unrevoked access token. If Redis is
// unavailable the request fails, since revocation cannot be checked.
func (s *Service) Require(next http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok {
			httpx.Error(w, errInvalidToken)
			return
		}
		c, err := s.tokens.parse(raw, tokenAccess)
		if err != nil {
			httpx.Error(w, err)
			return
		}
		blocked, suspended, err := s.tokens.status(r.Context(), c)
		if err != nil {
			httpx.Error(w, err)
			return
		}
		if blocked {
			httpx.Error(w, errInvalidToken)
			return
		}
		if suspended {
			httpx.Error(w, errSuspended)
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, c)))
	})
}
