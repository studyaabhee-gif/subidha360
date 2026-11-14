// Command api runs the Subidha360 backend.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/redis/go-redis/v9"

	"subidha360/backend/internal/app"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/config"
	"subidha360/backend/internal/notify"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/sms"
)

const (
	startupTimeout   = 30 * time.Second
	shutdownTimeout  = 15 * time.Second
	timeoutInterval  = 15 * time.Second
	deliveryInterval = 5 * time.Second
)

func main() {
	// Container images have no curl, so the binary checks itself.
	if len(os.Args) > 1 && os.Args[1] == "-healthcheck" {
		os.Exit(healthcheck())
	}
	if err := run(); err != nil {
		slog.Error("fatal", "err", err)
		os.Exit(1)
	}
}

func newPusher(cfg config.Config) (notify.Pusher, error) {
	if cfg.FCMProjectID == "" {
		slog.Warn("FCM is not configured; push notifications will only be logged")
		return notify.LogPusher{}, nil
	}
	credentials, err := os.ReadFile(cfg.FCMCredentialsFile)
	if err != nil {
		return nil, fmt.Errorf("fcm credentials: %w", err)
	}
	return notify.NewFCM(cfg.FCMProjectID, credentials)
}

// redisOptions prefers REDIS_URL. Its parse error is replaced because the
// original can quote the URL, which contains the password.
func redisOptions(cfg config.Config) (*redis.Options, error) {
	if cfg.RedisURL == "" {
		return &redis.Options{Addr: cfg.RedisAddr}, nil
	}
	opts, err := redis.ParseURL(cfg.RedisURL)
	if err != nil {
		return nil, errors.New("REDIS_URL is not a valid Redis URL")
	}
	return opts, nil
}

// newSMS picks the SMS sender. A failed balance check only warns, so a brief
// Sparrow outage cannot stop the server from starting.
func newSMS(ctx context.Context, cfg config.Config) auth.SMSSender {
	if cfg.SparrowToken == "" {
		slog.Warn("Sparrow SMS is not configured; messages and login codes will only be logged")
		return auth.LogSMSSender{}
	}
	client := sms.NewSparrow(cfg.SparrowToken, cfg.SparrowFrom)
	credits, err := client.Credits(ctx)
	if err != nil {
		slog.Warn("could not check Sparrow balance", "err", err)
		return client
	}
	slog.Info("Sparrow SMS ready", "credits", credits)
	return client
}

func run() error {
	if os.Getenv("LOG_FORMAT") == "json" {
		// One JSON object per line, which hosted log tools can search.
		slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	}
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	startCtx, cancel := context.WithTimeout(ctx, startupTimeout)
	defer cancel()

	client, err := mongodb.Connect(startCtx, cfg.MongoURI)
	if err != nil {
		return fmt.Errorf("mongo: %w", err)
	}
	defer client.Disconnect(context.Background())

	redisOpts, err := redisOptions(cfg)
	if err != nil {
		return err
	}
	rdb := redis.NewClient(redisOpts)
	defer rdb.Close()
	if err := rdb.Ping(startCtx).Err(); err != nil {
		return fmt.Errorf("redis: %w", err)
	}

	pusher, err := newPusher(cfg)
	if err != nil {
		return err
	}

	a, err := app.New(startCtx, app.Deps{
		Config: cfg,
		Mongo:  client,
		Redis:  rdb,
		SMS:    newSMS(startCtx, cfg),
		Push:   pusher,
	})
	if err != nil {
		return err
	}

	go a.Jobs.RunTimeouts(ctx, timeoutInterval)
	go a.Notify.Run(ctx, deliveryInterval)
	// Picks up catalogue edits made through another server instance.
	go a.Catalog.Refresh(ctx, time.Minute)

	server := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           a.Handler,
		ReadHeaderTimeout: 5 * time.Second,
	}
	serveErr := make(chan error, 1)
	go func() { serveErr <- server.ListenAndServe() }()
	slog.Info("listening", "addr", cfg.HTTPAddr, "env", cfg.Env)

	select {
	case err := <-serveErr:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
		return nil
	case <-ctx.Done():
	}

	shutdownCtx, cancelShutdown := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancelShutdown()
	return server.Shutdown(shutdownCtx)
}

// healthcheck asks the running server whether it can reach its databases.
func healthcheck() int {
	addr := os.Getenv("HTTP_ADDR")
	if addr == "" || addr[0] == ':' {
		addr = "localhost" + addr
	}
	if addr == "localhost" {
		addr = "localhost:8080"
	}
	client := http.Client{Timeout: 4 * time.Second}
	res, err := client.Get("http://" + addr + "/healthz")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	res.Body.Close()
	if res.StatusCode != http.StatusOK {
		fmt.Fprintln(os.Stderr, "status", res.StatusCode)
		return 1
	}
	return 0
}
