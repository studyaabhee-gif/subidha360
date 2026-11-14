package auth

import (
	"context"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"subidha360/backend/internal/apperr"
)

const (
	tokenAccess  = "access"
	tokenRefresh = "refresh"
)

var errInvalidToken = apperr.Unauthorized("invalid_token", "token is invalid or expired")

type claims struct {
	jwt.RegisteredClaims
	Type string `json:"typ"`
}

// TokenPair is what clients receive after authenticating.
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

type tokens struct {
	secret     []byte
	accessTTL  time.Duration
	refreshTTL time.Duration
	rdb        *redis.Client
}

func (t *tokens) issue(userID string) (TokenPair, error) {
	access, err := t.sign(userID, tokenAccess, t.accessTTL)
	if err != nil {
		return TokenPair{}, err
	}
	refresh, err := t.sign(userID, tokenRefresh, t.refreshTTL)
	if err != nil {
		return TokenPair{}, err
	}
	return TokenPair{AccessToken: access, RefreshToken: refresh}, nil
}

func (t *tokens) sign(userID, kind string, ttl time.Duration) (string, error) {
	now := time.Now()
	c := claims{
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.NewString(),
			Subject:   userID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
		Type: kind,
	}
	signed, err := jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString(t.secret)
	if err != nil {
		return "", fmt.Errorf("sign token: %w", err)
	}
	return signed, nil
}

// parse verifies signature, expiry and token type. It does not check the blocklist.
func (t *tokens) parse(raw, kind string) (*claims, error) {
	var c claims
	_, err := jwt.ParseWithClaims(raw, &c,
		func(*jwt.Token) (any, error) { return t.secret, nil },
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithExpirationRequired(),
	)
	if err != nil || c.Type != kind || c.ID == "" || c.Subject == "" {
		return nil, errInvalidToken
	}
	return &c, nil
}

func blockKey(jti string) string { return "jwt:block:" + jti }

// block adds a token to the blocklist until it would expire anyway. It reports
// false if the token was already blocked, which makes refresh rotation atomic.
func (t *tokens) block(ctx context.Context, c *claims) (bool, error) {
	ttl := time.Until(c.ExpiresAt.Time)
	if ttl <= 0 {
		return true, nil
	}
	first, err := t.rdb.SetNX(ctx, blockKey(c.ID), 1, ttl).Result()
	if err != nil {
		return false, fmt.Errorf("block token: %w", err)
	}
	return first, nil
}

func suspendKey(userID string) string { return "user:suspended:" + userID }

// status reports in one round trip whether a token is revoked and whether its
// user is suspended.
func (t *tokens) status(ctx context.Context, c *claims) (blocked, suspended bool, err error) {
	pipe := t.rdb.Pipeline()
	b := pipe.Exists(ctx, blockKey(c.ID))
	s := pipe.Exists(ctx, suspendKey(c.Subject))
	if _, err := pipe.Exec(ctx); err != nil {
		return false, false, fmt.Errorf("check token status: %w", err)
	}
	return b.Val() > 0, s.Val() > 0, nil
}
