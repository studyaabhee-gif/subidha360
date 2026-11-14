// Package config loads runtime configuration from environment variables.
package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"time"
)

const EnvDevelopment = "development"

type Config struct {
	Env       string
	HTTPAddr  string
	MongoURI  string
	MongoDB   string
	RedisAddr string
	// RedisURL takes priority over RedisAddr, for hosted Redis that needs a
	// password and TLS (rediss://).
	RedisURL   string
	JWTSecret  string
	AccessTTL  time.Duration
	RefreshTTL time.Duration
	OTPTTL     time.Duration
	// BidWindow is how long a job waits for bids before it escalates.
	BidWindow time.Duration
	// SelectionWindow is how long after the first bid a seeker has to pick one.
	SelectionWindow time.Duration
	// AutoReleaseAfter is how long after the first completion confirmation
	// escrow is released, unless a dispute is raised.
	AutoReleaseAfter time.Duration
	// EscrowReviewWindow is how long admins have to decide a seeker's mid-work
	// cancellation before the default split applies.
	EscrowReviewWindow time.Duration
	// WarrantyDays is how long after completion a seeker can claim on the
	// service guarantee.
	WarrantyDays int
	// EscalationMeters is how far past a provider's service area an escalated
	// broadcast reaches.
	EscalationMeters float64
	// CommissionBPS is the platform commission in basis points (1000 = 10%).
	CommissionBPS int64
	// FCMProjectID and FCMCredentialsFile enable real push. Without them,
	// pushes are only logged.
	FCMProjectID       string
	FCMCredentialsFile string
	// SparrowToken and SparrowFrom enable real SMS. Without them, messages,
	// including login codes, are only logged.
	SparrowToken string
	SparrowFrom  string
	// TrustProxy reads visitor addresses from X-Forwarded-For. Turn it on
	// only behind a proxy that sets that header, such as the Caddy setup in
	// deploy/.
	TrustProxy bool
	// SiteURL is the public address, such as https://subidha360.com, used in
	// the sitemap.
	SiteURL string
}

// Load reads configuration. APP_ENV must be set explicitly because development
// mode logs OTP codes and exposes a wallet top-up endpoint.
func Load() (Config, error) {
	c := Config{
		Env:                os.Getenv("APP_ENV"),
		HTTPAddr:           get("HTTP_ADDR", ":8080"),
		MongoURI:           get("MONGO_URI", "mongodb://localhost:27017/?replicaSet=rs0"),
		MongoDB:            get("MONGO_DB", "subidha360"),
		RedisAddr:          get("REDIS_ADDR", "localhost:6379"),
		RedisURL:           os.Getenv("REDIS_URL"),
		JWTSecret:          os.Getenv("JWT_SECRET"),
		AccessTTL:          15 * time.Minute,
		RefreshTTL:         30 * 24 * time.Hour,
		OTPTTL:             5 * time.Minute,
		BidWindow:          5 * time.Minute,
		SelectionWindow:    24 * time.Hour,
		AutoReleaseAfter:   72 * time.Hour,
		EscrowReviewWindow: 72 * time.Hour,
		WarrantyDays:       30,
		EscalationMeters:   5000,
		CommissionBPS:      1000,
		FCMProjectID:       os.Getenv("FCM_PROJECT_ID"),
		FCMCredentialsFile: os.Getenv("FCM_CREDENTIALS_FILE"),
		SparrowToken:       os.Getenv("SPARROW_TOKEN"),
		SparrowFrom:        os.Getenv("SPARROW_FROM"),
		TrustProxy:         os.Getenv("TRUST_PROXY") == "1",
		SiteURL:            os.Getenv("SITE_URL"),
	}

	if (c.FCMProjectID == "") != (c.FCMCredentialsFile == "") {
		return c, errors.New("FCM_PROJECT_ID and FCM_CREDENTIALS_FILE must be set together")
	}
	if (c.SparrowToken == "") != (c.SparrowFrom == "") {
		return c, errors.New("SPARROW_TOKEN and SPARROW_FROM must be set together")
	}
	if c.Env == "" {
		return c, errors.New("APP_ENV is required")
	}
	if c.Env != EnvDevelopment {
		return c, fmt.Errorf("APP_ENV=%q is not supported yet: payment gateways are still development stubs", c.Env)
	}
	if len(c.JWTSecret) < 32 {
		return c, errors.New("JWT_SECRET must be at least 32 characters")
	}

	var err error
	if c.BidWindow, err = duration("BID_WINDOW", c.BidWindow); err != nil {
		return c, err
	}
	if c.SelectionWindow, err = duration("SELECTION_WINDOW", c.SelectionWindow); err != nil {
		return c, err
	}
	if c.AutoReleaseAfter, err = duration("AUTO_RELEASE_AFTER", c.AutoReleaseAfter); err != nil {
		return c, err
	}
	if c.EscrowReviewWindow, err = duration("ESCROW_REVIEW_WINDOW", c.EscrowReviewWindow); err != nil {
		return c, err
	}
	if v := os.Getenv("ESCALATION_METERS"); v != "" {
		if c.EscalationMeters, err = strconv.ParseFloat(v, 64); err != nil {
			return c, fmt.Errorf("ESCALATION_METERS: %w", err)
		}
	}
	if v := os.Getenv("COMMISSION_BPS"); v != "" {
		if c.CommissionBPS, err = strconv.ParseInt(v, 10, 64); err != nil {
			return c, fmt.Errorf("COMMISSION_BPS: %w", err)
		}
	}
	if c.CommissionBPS < 0 || c.CommissionBPS > 10000 {
		return c, errors.New("COMMISSION_BPS must be between 0 and 10000")
	}
	return c, nil
}

func get(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func duration(key string, fallback time.Duration) (time.Duration, error) {
	v := os.Getenv(key)
	if v == "" {
		return fallback, nil
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		return 0, fmt.Errorf("%s: %w", key, err)
	}
	return d, nil
}
