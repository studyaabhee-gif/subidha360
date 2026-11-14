// Package app wires the modules into one HTTP server.
package app

import (
	"context"
	"fmt"
	"net/http"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"subidha360/backend/internal/account"
	"subidha360/backend/internal/admin"
	"subidha360/backend/internal/analytics"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/bid"
	"subidha360/backend/internal/catalog"
	"subidha360/backend/internal/chat"
	"subidha360/backend/internal/config"
	"subidha360/backend/internal/job"
	"subidha360/backend/internal/notify"
	"subidha360/backend/internal/payout"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/provider"
	"subidha360/backend/internal/review"
	"subidha360/backend/internal/safety"
	"subidha360/backend/internal/support"
	"subidha360/backend/internal/user"
	"subidha360/backend/internal/wallet"
)

type Deps struct {
	Config config.Config
	Mongo  *mongo.Client
	Redis  *redis.Client
	SMS    auth.SMSSender
	Push   notify.Pusher
}

type App struct {
	Handler http.Handler
	Jobs    *job.Service
	Ledger  *wallet.Ledger
	Notify  *notify.Service
	Catalog *catalog.Store
}

// New prepares the database and builds the HTTP handler.
func New(ctx context.Context, d Deps) (*App, error) {
	cfg := d.Config
	db := d.Mongo.Database(cfg.MongoDB)
	if err := mongodb.EnsureIndexes(ctx, db); err != nil {
		return nil, err
	}

	ledger := wallet.NewLedger(d.Mongo, db)
	if err := ledger.EnsureAccounts(ctx, wallet.AccountCommission, wallet.AccountGateway); err != nil {
		return nil, fmt.Errorf("seed system accounts: %w", err)
	}

	catalogStore := catalog.NewStore(db)
	if err := catalogStore.Load(ctx); err != nil {
		return nil, err
	}

	users := user.NewRepo(db)
	authSvc := auth.NewService(d.Redis, d.SMS, users, ledger, auth.Options{
		Secret:     cfg.JWTSecret,
		AccessTTL:  cfg.AccessTTL,
		RefreshTTL: cfg.RefreshTTL,
		OTPTTL:     cfg.OTPTTL,
	})
	notifications := notify.NewService(db, users, d.Push, d.SMS)
	jobs := job.NewService(d.Mongo, db, users, ledger, notifications, job.Options{
		BidWindow:          cfg.BidWindow,
		SelectionWindow:    cfg.SelectionWindow,
		AutoReleaseAfter:   cfg.AutoReleaseAfter,
		EscrowReviewWindow: cfg.EscrowReviewWindow,
		WarrantyDays:       cfg.WarrantyDays,
		EscalationMeters:   cfg.EscalationMeters,
		CommissionBPS:      cfg.CommissionBPS,
	})
	bids := bid.NewService(d.Mongo, db, jobs, ledger, users)
	jobs.SetBidCloser(bids)
	reviews := review.NewService(d.Mongo, db, jobs, users, notifications)
	safe := safety.NewService(db, jobs)
	chats := chat.NewService(db, jobs, notifications, safe)
	supportSvc := support.NewService(d.Mongo, db, jobs, notifications)
	views := analytics.NewService(db, d.Redis, cfg.TrustProxy)
	providers := provider.NewService(d.Mongo, db, users)
	payouts := payout.NewService(d.Mongo, db, ledger, users, notifications)
	admins := admin.NewService(d.Mongo, db, users, jobs, authSvc, providers, payouts, notifications, catalogStore, supportSvc, safe, views)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		if err := d.Mongo.Ping(r.Context(), nil); err != nil {
			httpx.JSON(w, http.StatusServiceUnavailable, map[string]string{"status": "mongo unavailable"})
			return
		}
		if err := d.Redis.Ping(r.Context()).Err(); err != nil {
			httpx.JSON(w, http.StatusServiceUnavailable, map[string]string{"status": "redis unavailable"})
			return
		}
		httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	authSvc.Routes(mux)
	ledger.Routes(mux, authSvc, cfg.Env == config.EnvDevelopment)
	jobs.Routes(mux, authSvc)
	bids.Routes(mux, authSvc)
	notifications.Routes(mux, authSvc)
	reviews.Routes(mux, authSvc)
	chats.Routes(mux, authSvc)
	admins.Routes(mux, authSvc)
	providers.Routes(mux, authSvc)
	payouts.Routes(mux, authSvc)
	supportSvc.Routes(mux, authSvc)
	safe.Routes(mux, authSvc)
	views.RoutesOn(mux)
	account.NewService(d.Mongo, db, users, ledger, authSvc).Routes(mux, authSvc)
	catalog.Routes(mux)
	catalog.SEORoutes(mux, cfg.SiteURL)

	var handler http.Handler = mux
	if cfg.Env == config.EnvDevelopment {
		handler = httpx.DevCORS(mux)
	}
	handler = httpx.Observe(handler)
	return &App{Handler: handler, Jobs: jobs, Ledger: ledger, Notify: notifications, Catalog: catalogStore}, nil
}
