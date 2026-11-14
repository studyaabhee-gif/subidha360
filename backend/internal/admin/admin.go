// Package admin is the back office: people, jobs, money and reports, plus an
// audit log of every change an admin makes.
//
// Admin reads go straight to the collections, because they cut across every
// module. Admin writes go through the owning module, so its rules still apply.
package admin

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/analytics"
	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/catalog"
	"subidha360/backend/internal/job"
	"subidha360/backend/internal/notify"
	"subidha360/backend/internal/payout"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/provider"
	"subidha360/backend/internal/safety"
	"subidha360/backend/internal/support"
	"subidha360/backend/internal/user"
)

// pageSize is how many rows each admin list returns at a time.
const pageSize = 50

// Audit actions.
const (
	ActionSuspend        = "user.suspend"
	ActionUnsuspend      = "user.unsuspend"
	ActionVerify         = "provider.verify"
	ActionUnverify       = "provider.unverify"
	ActionResolveEscrow  = "job.resolve_escrow"
	ActionCloseClaim     = "job.close_claim"
	ActionApproveCheck   = "provider.check_approve"
	ActionRejectCheck    = "provider.check_reject"
	ActionPayWithdrawal  = "withdrawal.paid"
	ActionRefuseWithdraw = "withdrawal.refused"
	TargetUser           = "user"
	TargetJob            = "job"
	maxReasonLength      = 500
	pendingBidStatus     = "PENDING"
	withdrawnByAdminNote = "REJECTED"
)

// Action is one row of the audit log. Rows are only ever inserted.
type Action struct {
	ID         string    `bson:"_id" json:"id"`
	AdminID    string    `bson:"admin_id" json:"admin_id"`
	AdminName  string    `bson:"-" json:"admin_name"`
	Action     string    `bson:"action" json:"action"`
	TargetType string    `bson:"target_type" json:"target_type"`
	TargetID   string    `bson:"target_id" json:"target_id"`
	Detail     string    `bson:"detail,omitempty" json:"detail,omitempty"`
	At         time.Time `bson:"at" json:"at"`
}

type Service struct {
	client      *mongo.Client
	users       *mongo.Collection
	jobs        *mongo.Collection
	bids        *mongo.Collection
	messages    *mongo.Collection
	reviews     *mongo.Collection
	entries     *mongo.Collection
	accounts    *mongo.Collection
	actions     *mongo.Collection
	withdrawals *mongo.Collection
	threads     *mongo.Collection
	flags       *mongo.Collection
	userRepo    *user.Repo
	jobSvc      *job.Service
	auth        *auth.Service
	provider    *provider.Service
	payouts     *payout.Service
	notify      *notify.Service
	catalog     *catalog.Store
	support     *support.Service
	safety      *safety.Service
	analytics   *analytics.Service
	now         func() time.Time
}

func NewService(client *mongo.Client, db *mongo.Database, users *user.Repo, jobs *job.Service, a *auth.Service, p *provider.Service, payouts *payout.Service, n *notify.Service, cat *catalog.Store, sup *support.Service, safe *safety.Service, views *analytics.Service) *Service {
	return &Service{
		client:      client,
		users:       db.Collection(mongodb.Users),
		jobs:        db.Collection(mongodb.Jobs),
		bids:        db.Collection(mongodb.Bids),
		messages:    db.Collection(mongodb.Messages),
		reviews:     db.Collection(mongodb.Reviews),
		entries:     db.Collection(mongodb.WalletLedger),
		accounts:    db.Collection(mongodb.WalletAccounts),
		actions:     db.Collection(mongodb.AdminActions),
		withdrawals: db.Collection(mongodb.Withdrawals),
		threads:     db.Collection(mongodb.SupportThreads),
		flags:       db.Collection(mongodb.Flags),
		userRepo:    users,
		jobSvc:      jobs,
		auth:        a,
		provider:    p,
		payouts:     payouts,
		notify:      n,
		catalog:     cat,
		support:     sup,
		safety:      safe,
		analytics:   views,
		now:         func() time.Time { return time.Now().UTC() },
	}
}

// record writes an audit row. Inside a transaction it commits or rolls back
// with the change it describes.
func (s *Service) record(ctx context.Context, adminID, action, targetType, targetID, detail string) error {
	_, err := s.actions.InsertOne(ctx, Action{
		ID:         uuid.NewString(),
		AdminID:    adminID,
		Action:     action,
		TargetType: targetType,
		TargetID:   targetID,
		Detail:     detail,
		At:         s.now(),
	})
	if err != nil {
		return fmt.Errorf("record admin action: %w", err)
	}
	return nil
}

func cleanReason(reason string) (string, error) {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return "", apperr.BadRequest("reason_required", "give a reason, so other admins know why")
	}
	if utf8.RuneCountInString(reason) > maxReasonLength {
		return "", apperr.BadRequest("reason_too_long", "keep the reason under 500 characters")
	}
	return reason, nil
}

// Suspend locks an account: no login, no requests, no new jobs offered, and
// any bids still waiting are withdrawn so no one can accept them.
func (s *Service) Suspend(ctx context.Context, adminID, userID, reason string) error {
	reason, err := cleanReason(reason)
	if err != nil {
		return err
	}
	if adminID == userID {
		return apperr.Conflict("cannot_suspend_self", "you cannot suspend your own account")
	}
	err = mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		err := s.userRepo.SetSuspension(ctx, userID, user.Suspension{Reason: reason, By: adminID, At: s.now()})
		if err != nil {
			return err
		}
		res, err := s.bids.UpdateMany(ctx,
			bson.M{"provider_id": userID, "status": pendingBidStatus},
			bson.M{"$set": bson.M{"status": withdrawnByAdminNote}},
		)
		if err != nil {
			return fmt.Errorf("withdraw bids: %w", err)
		}
		detail := reason
		if res.ModifiedCount > 0 {
			detail = fmt.Sprintf("%s (withdrew %d waiting bids)", reason, res.ModifiedCount)
		}
		return s.record(ctx, adminID, ActionSuspend, TargetUser, userID, detail)
	})
	if err != nil {
		return err
	}
	// After the commit, so a rolled-back suspension never locks anyone out.
	// Login and refresh already read the database, so a failure here only
	// delays the lock until the user's current access token expires.
	if err := s.auth.MarkSuspended(ctx, userID, true); err != nil {
		slog.Error("suspension saved but not yet enforced on open sessions", "user", userID, "err", err)
		return fmt.Errorf("mark suspended: %w", err)
	}
	return nil
}

// Unsuspend restores an account.
func (s *Service) Unsuspend(ctx context.Context, adminID, userID, note string) error {
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		u, err := s.userRepo.Get(ctx, userID)
		if err != nil {
			return err
		}
		if u.Suspension == nil {
			return apperr.Conflict("not_suspended", "this account is not suspended")
		}
		if err := s.userRepo.ClearSuspension(ctx, userID); err != nil {
			return err
		}
		return s.record(ctx, adminID, ActionUnsuspend, TargetUser, userID, strings.TrimSpace(note))
	})
	if err != nil {
		return err
	}
	return s.auth.MarkSuspended(ctx, userID, false)
}

// SetVerified records an identity check on a provider.
func (s *Service) SetVerified(ctx context.Context, adminID, userID string, verified bool, note string) error {
	action := ActionVerify
	if !verified {
		action = ActionUnverify
	}
	return mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		if err := s.userRepo.SetVerified(ctx, userID, verified); err != nil {
			return err
		}
		return s.record(ctx, adminID, action, TargetUser, userID, strings.TrimSpace(note))
	})
}

// ResolveEscrow decides a dispute or a mid-work cancellation.
func (s *Service) ResolveEscrow(ctx context.Context, adminID, jobID string, providerPercent int64, note string) (*job.Job, error) {
	var out *job.Job
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		j, err := s.jobSvc.ResolveEscrow(ctx, adminID, jobID, providerPercent)
		if err != nil {
			return err
		}
		out = j
		detail := fmt.Sprintf("%d%% to the provider", providerPercent)
		if note = strings.TrimSpace(note); note != "" {
			detail += ": " + note
		}
		return s.record(ctx, adminID, ActionResolveEscrow, TargetJob, jobID, detail)
	})
	return out, err
}

// CloseClaim records how a guarantee claim was settled.
func (s *Service) CloseClaim(ctx context.Context, adminID, jobID, note string) (*job.Job, error) {
	var out *job.Job
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		j, err := s.jobSvc.CloseWarrantyClaim(ctx, jobID, note)
		if err != nil {
			return err
		}
		out = j
		return s.record(ctx, adminID, ActionCloseClaim, TargetJob, jobID, strings.TrimSpace(note))
	})
	return out, err
}

// Actions returns the audit log, newest first, optionally for one target.
func (s *Service) Actions(ctx context.Context, targetID string, page int) ([]Action, bool, error) {
	filter := bson.M{}
	if targetID != "" {
		filter["target_id"] = targetID
	}
	var rows []Action
	more, err := findPage(ctx, s.actions, filter, bson.D{{Key: "at", Value: -1}}, page, &rows)
	if err != nil {
		return nil, false, err
	}
	if rows == nil {
		rows = []Action{}
	}
	ids := make([]string, len(rows))
	for i := range rows {
		ids[i] = rows[i].AdminID
	}
	names, err := s.names(ctx, ids)
	if err != nil {
		return nil, false, err
	}
	for i := range rows {
		rows[i].AdminName = names[rows[i].AdminID].Name
	}
	return rows, more, nil
}

// findPage reads one page into out and reports whether more rows follow.
func findPage[T any](ctx context.Context, c *mongo.Collection, filter any, sort bson.D, page int, out *[]T) (bool, error) {
	if page < 1 {
		page = 1
	}
	opts := options.Find().SetSort(sort).SetSkip(int64((page - 1) * pageSize)).SetLimit(pageSize + 1)
	cur, err := c.Find(ctx, filter, opts)
	if err != nil {
		return false, fmt.Errorf("find %s: %w", c.Name(), err)
	}
	if err := cur.All(ctx, out); err != nil {
		return false, fmt.Errorf("read %s: %w", c.Name(), err)
	}
	more := len(*out) > pageSize
	if more {
		*out = (*out)[:pageSize]
	}
	return more, nil
}

// Person is the short form of a user that admin lists show next to a record.
type Person struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Phone string `json:"phone"`
}

// names looks up several users at once. Missing users are left out.
func (s *Service) names(ctx context.Context, ids []string) (map[string]Person, error) {
	out := map[string]Person{}
	unique := make([]string, 0, len(ids))
	seen := map[string]bool{}
	for _, id := range ids {
		if id != "" && !seen[id] {
			seen[id] = true
			unique = append(unique, id)
		}
	}
	if len(unique) == 0 {
		return out, nil
	}
	cur, err := s.users.Find(ctx, bson.M{"_id": bson.M{"$in": unique}},
		options.Find().SetProjection(bson.M{"_id": 1, "display_name": 1, "phone_number": 1}))
	if err != nil {
		return nil, fmt.Errorf("find names: %w", err)
	}
	var rows []struct {
		ID    string `bson:"_id"`
		Name  string `bson:"display_name"`
		Phone string `bson:"phone_number"`
	}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read names: %w", err)
	}
	for _, r := range rows {
		out[r.ID] = Person{ID: r.ID, Name: r.Name, Phone: r.Phone}
	}
	return out, nil
}

// DecideCheck approves or rejects a provider's identity check and tells them.
// Approval grants the verified badge.
func (s *Service) DecideCheck(ctx context.Context, adminID, userID string, approve bool, reason string) error {
	reason = strings.TrimSpace(reason)
	if !approve {
		var err error
		if reason, err = cleanReason(reason); err != nil {
			return err
		}
	}
	return mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		if err := s.userRepo.DecideCheck(ctx, userID, approve, reason, adminID, s.now()); err != nil {
			return err
		}
		msg := notify.Message{UserID: userID, Type: "provider.verification", Critical: true}
		action := ActionApproveCheck
		if approve {
			msg.Title = "You are verified"
			msg.Body = "Your identity check passed. Customers now see a Verified badge on your bids."
		} else {
			action = ActionRejectCheck
			msg.Title = "Identity check not passed"
			msg.Body = reason + " Update your documents in the app and send them again."
		}
		if err := s.notify.Enqueue(ctx, msg); err != nil {
			return err
		}
		return s.record(ctx, adminID, action, TargetUser, userID, reason)
	})
}

// DecideWithdrawal records a withdrawal as sent, with its transfer reference,
// or refuses it and returns the money.
func (s *Service) DecideWithdrawal(ctx context.Context, adminID, id string, paid bool, note string) (*payout.Withdrawal, error) {
	var out *payout.Withdrawal
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		w, err := s.payouts.Decide(ctx, adminID, id, paid, note)
		if err != nil {
			return err
		}
		out = w
		action, verb := ActionPayWithdrawal, "Sent"
		if !paid {
			action, verb = ActionRefuseWithdraw, "Refused"
		}
		detail := fmt.Sprintf("%s Rs %d.%02d: %s", verb, w.Amount/100, w.Amount%100, strings.TrimSpace(note))
		return s.record(ctx, adminID, action, TargetUser, w.UserID, detail)
	})
	return out, err
}

// WithdrawalRow is a withdrawal with the person asking for it.
type WithdrawalRow struct {
	payout.Withdrawal
	Person   Person `json:"person"`
	Verified bool   `json:"verified"`
}

// Withdrawals lists withdrawals, waiting ones first when no status is given.
func (s *Service) Withdrawals(ctx context.Context, status string, page int) ([]WithdrawalRow, bool, error) {
	filter := bson.M{}
	switch status {
	case "":
	case payout.StatusPending, payout.StatusPaid, payout.StatusRejected:
		filter["status"] = status
	default:
		return nil, false, apperr.BadRequest("invalid_status", "unknown withdrawal status")
	}
	var rows []payout.Withdrawal
	more, err := findPage(ctx, s.withdrawals, filter, bson.D{{Key: "created_at", Value: -1}}, page, &rows)
	if err != nil {
		return nil, false, err
	}
	ids := make([]string, len(rows))
	for i := range rows {
		ids[i] = rows[i].UserID
	}
	people, err := s.names(ctx, ids)
	if err != nil {
		return nil, false, err
	}
	verified := map[string]bool{}
	cur, err := s.users.Find(ctx, bson.M{"_id": bson.M{"$in": ids}, "is_verified": true}, options.Find().SetProjection(bson.M{"_id": 1}))
	if err != nil {
		return nil, false, fmt.Errorf("find verified: %w", err)
	}
	var vs []struct {
		ID string `bson:"_id"`
	}
	if err := cur.All(ctx, &vs); err != nil {
		return nil, false, fmt.Errorf("read verified: %w", err)
	}
	for _, v := range vs {
		verified[v.ID] = true
	}
	out := make([]WithdrawalRow, len(rows))
	for i, w := range rows {
		p := people[w.UserID]
		p.ID = w.UserID
		out[i] = WithdrawalRow{Withdrawal: w, Person: p, Verified: verified[w.UserID]}
	}
	return out, more, nil
}
