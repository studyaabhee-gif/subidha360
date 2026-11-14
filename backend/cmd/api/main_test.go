package main

import (
	"strings"
	"testing"

	"subidha360/backend/internal/config"
)

func TestRedisOptionsUsesPlainAddressByDefault(t *testing.T) {
	opts, err := redisOptions(config.Config{RedisAddr: "localhost:6379"})
	if err != nil {
		t.Fatal(err)
	}
	if opts.Addr != "localhost:6379" || opts.TLSConfig != nil {
		t.Fatalf("addr = %s, tls = %v", opts.Addr, opts.TLSConfig != nil)
	}
}

func TestRedisOptionsReadsHostedURLWithTLS(t *testing.T) {
	opts, err := redisOptions(config.Config{
		RedisAddr: "localhost:6379",
		RedisURL:  "rediss://default:secret@example.upstash.io:6379",
	})
	if err != nil {
		t.Fatal(err)
	}
	if opts.Addr != "example.upstash.io:6379" || opts.Password != "secret" || opts.TLSConfig == nil {
		t.Fatalf("addr = %s, tls = %v", opts.Addr, opts.TLSConfig != nil)
	}
}

func TestRedisOptionsHidesBadURL(t *testing.T) {
	_, err := redisOptions(config.Config{RedisURL: "http://default:secret@example.com"})
	if err == nil {
		t.Fatal("expected error")
	}
	if strings.Contains(err.Error(), "secret") {
		t.Fatalf("error leaked the password: %v", err)
	}
}
