// Package notify delivers user notifications through a transactional outbox.
//
// Callers write a Message in the same transaction as the change it describes,
// so a crash cannot lose a warning and a rollback cannot send a false one. A
// worker then delivers by push, falling back to SMS for critical messages.
// Delivery is at-least-once: a crash mid-send can repeat a message. Every message
// also stays readable in the user's in-app inbox.
package notify

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/user"
)

// Delivery statuses.
const (
	StatusPending = "PENDING"
	StatusSent    = "SENT"
	// StatusInboxOnly means no push reached the user and the message was not
	// critical enough for SMS. It is still in their inbox.
	StatusInboxOnly = "INBOX_ONLY"
	StatusFailed    = "FAILED"
)

// Delivery channels.
const (
	ChannelPush = "PUSH"
	ChannelSMS  = "SMS"
)

const (
	inboxLimit = 50
	batchSize  = 200
	// claimLease is how long a claimed message is hidden from other workers. A
	// worker that crashes mid-send has its message picked up after this.
	claimLease = 2 * time.Minute
	// maxPushAttempts is when a critical message gives up on push and tries SMS.
	maxPushAttempts = 4
	// maxAttempts is when a message stops being retried at all.
	maxAttempts = 10
	baseBackoff = 30 * time.Second
	maxBackoff  = time.Hour
)

// ErrInvalidToken means a device token will never work again.
var ErrInvalidToken = errors.New("invalid device token")

// Push is one notification to one device.
type Push struct {
	Token string
	Title string
	Body  string
	Data  map[string]string
}

// Pusher sends to a device. Errors other than ErrInvalidToken are retried.
type Pusher interface {
	Push(ctx context.Context, p Push) error
}

// LogPusher logs pushes instead of sending them. Development only.
type LogPusher struct{}

func (LogPusher) Push(_ context.Context, p Push) error {
	slog.Info("dev push", "title", p.Title, "body", p.Body)
	return nil
}

// SMSSender matches auth.SMSSender.
type SMSSender interface {
	Send(ctx context.Context, phone, message string) error
}

// Message is a row in the outbox and the user's inbox.
type Message struct {
	ID     string `bson:"_id" json:"id"`
	UserID string `bson:"user_id" json:"-"`
	Type   string `bson:"type" json:"type"`
	Title  string `bson:"title" json:"title"`
	Body   string `bson:"body" json:"body"`
	JobID  string `bson:"job_id,omitempty" json:"job_id,omitempty"`
	// Critical messages fall back to SMS when push cannot reach the user.
	Critical      bool       `bson:"critical" json:"-"`
	Status        string     `bson:"status" json:"-"`
	Channel       string     `bson:"channel,omitempty" json:"-"`
	Attempts      int        `bson:"attempts" json:"-"`
	NextAttemptAt time.Time  `bson:"next_attempt_at" json:"-"`
	SentAt        *time.Time `bson:"sent_at,omitempty" json:"-"`
	// ReadAt is when the person opened their inbox after this arrived.
	ReadAt    *time.Time `bson:"read_at,omitempty" json:"read_at,omitempty"`
	CreatedAt time.Time  `bson:"created_at" json:"created_at"`
}

type device struct {
	Token     string    `bson:"_id"`
	UserID    string    `bson:"user_id"`
	Platform  string    `bson:"platform"`
	UpdatedAt time.Time `bson:"updated_at"`
}

type Service struct {
	messages *mongo.Collection
	devices  *mongo.Collection
	users    *user.Repo
	push     Pusher
	sms      SMSSender
}

func NewService(db *mongo.Database, users *user.Repo, push Pusher, sms SMSSender) *Service {
	return &Service{
		messages: db.Collection(mongodb.Notifications),
		devices:  db.Collection(mongodb.Devices),
		users:    users,
		push:     push,
		sms:      sms,
	}
}

// Enqueue stores messages for delivery. Passing a transaction's ctx ties them
// to that transaction's outcome.
func (s *Service) Enqueue(ctx context.Context, msgs ...Message) error {
	if len(msgs) == 0 {
		return nil
	}
	now := time.Now().UTC()
	rows := make([]Message, len(msgs))
	for i, m := range msgs {
		m.ID = uuid.NewString()
		m.Status = StatusPending
		m.NextAttemptAt = now
		m.CreatedAt = now
		rows[i] = m
	}
	if _, err := s.messages.InsertMany(ctx, rows); err != nil {
		return fmt.Errorf("enqueue notifications: %w", err)
	}
	return nil
}

// Deliver sends messages that are due. Claims are atomic, so it is safe to run
// on several instances at once.
func (s *Service) Deliver(ctx context.Context, now time.Time) error {
	var errs []error
	for range batchSize {
		m, err := s.claim(ctx, now)
		if err != nil {
			return errors.Join(append(errs, err)...)
		}
		if m == nil {
			break
		}
		if err := s.deliver(ctx, m, now); err != nil {
			errs = append(errs, fmt.Errorf("notification %s: %w", m.ID, err))
		}
	}
	return errors.Join(errs...)
}

func (s *Service) claim(ctx context.Context, now time.Time) (*Message, error) {
	var m Message
	err := s.messages.FindOneAndUpdate(ctx,
		bson.M{"status": StatusPending, "next_attempt_at": bson.M{"$lte": now}},
		bson.M{"$set": bson.M{"next_attempt_at": now.Add(claimLease)}, "$inc": bson.M{"attempts": 1}},
		options.FindOneAndUpdate().
			SetSort(bson.D{{Key: "next_attempt_at", Value: 1}}).
			SetReturnDocument(options.After),
	).Decode(&m)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("claim notification: %w", err)
	}
	return &m, nil
}

func (s *Service) deliver(ctx context.Context, m *Message, now time.Time) error {
	delivered, retryable, err := s.pushToDevices(ctx, m)
	if err != nil {
		return err
	}
	switch {
	case delivered:
		return s.finish(ctx, m, StatusSent, ChannelPush, now)
	case retryable && m.Attempts < maxPushAttempts:
		return s.retry(ctx, m, now)
	case !m.Critical:
		return s.finish(ctx, m, StatusInboxOnly, "", now)
	}

	u, err := s.users.Get(ctx, m.UserID)
	if err != nil {
		return err
	}
	err = s.sms.Send(ctx, u.PhoneNumber, "Subidha360: "+m.Body)
	if err == nil {
		return s.finish(ctx, m, StatusSent, ChannelSMS, now)
	}
	slog.Warn("sms fallback failed", "notification", m.ID, "attempts", m.Attempts, "err", err)
	if m.Attempts >= maxAttempts {
		slog.Error("critical notification undelivered", "notification", m.ID, "type", m.Type, "job", m.JobID)
		return s.finish(ctx, m, StatusFailed, "", now)
	}
	return s.retry(ctx, m, now)
}

// pushToDevices tries every device. One success counts as delivered. Devices
// whose token is dead are removed. The error is reserved for database failures.
func (s *Service) pushToDevices(ctx context.Context, m *Message) (delivered, retryable bool, err error) {
	cur, err := s.devices.Find(ctx, bson.M{"user_id": m.UserID})
	if err != nil {
		return false, false, fmt.Errorf("find devices: %w", err)
	}
	var rows []device
	if err := cur.All(ctx, &rows); err != nil {
		return false, false, fmt.Errorf("read devices: %w", err)
	}

	data := map[string]string{"notification_id": m.ID, "type": m.Type}
	if m.JobID != "" {
		data["job_id"] = m.JobID
	}
	for _, d := range rows {
		err := s.push.Push(ctx, Push{Token: d.Token, Title: m.Title, Body: m.Body, Data: data})
		switch {
		case err == nil:
			delivered = true
		case errors.Is(err, ErrInvalidToken):
			if _, err := s.devices.DeleteOne(ctx, bson.M{"_id": d.Token}); err != nil {
				return delivered, retryable, fmt.Errorf("remove dead device: %w", err)
			}
		default:
			retryable = true
			slog.Warn("push failed", "notification", m.ID, "err", err)
		}
	}
	return delivered, retryable, nil
}

func (s *Service) finish(ctx context.Context, m *Message, status, channel string, now time.Time) error {
	set := bson.M{"status": status, "sent_at": now}
	if channel != "" {
		set["channel"] = channel
	}
	if _, err := s.messages.UpdateOne(ctx, bson.M{"_id": m.ID}, bson.M{"$set": set}); err != nil {
		return fmt.Errorf("finish notification: %w", err)
	}
	return nil
}

func (s *Service) retry(ctx context.Context, m *Message, now time.Time) error {
	_, err := s.messages.UpdateOne(ctx, bson.M{"_id": m.ID},
		bson.M{"$set": bson.M{"next_attempt_at": now.Add(backoff(m.Attempts))}})
	if err != nil {
		return fmt.Errorf("reschedule notification: %w", err)
	}
	return nil
}

// backoff doubles the wait after each attempt, up to maxBackoff.
func backoff(attempts int) time.Duration {
	d := baseBackoff
	for range attempts - 1 {
		d *= 2
		if d >= maxBackoff {
			return maxBackoff
		}
	}
	return d
}

// Run calls Deliver on an interval until ctx is cancelled.
func (s *Service) Run(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			if err := s.Deliver(ctx, now.UTC()); err != nil {
				slog.Error("deliver notifications", "err", err)
			}
		}
	}
}

// RegisterDevice links a push token to a user. Tokens belong to an app install,
// so a new login on the same phone takes the token over from the previous user.
func (s *Service) RegisterDevice(ctx context.Context, userID, token, platform string) error {
	if strings.TrimSpace(token) == "" || len(token) > 4096 {
		return apperr.BadRequest("invalid_token", "device token is missing or too long")
	}
	if platform != "android" && platform != "ios" {
		return apperr.BadRequest("invalid_platform", "platform must be android or ios")
	}
	_, err := s.devices.UpdateOne(ctx, bson.M{"_id": token},
		bson.M{"$set": bson.M{"user_id": userID, "platform": platform, "updated_at": time.Now().UTC()}},
		options.UpdateOne().SetUpsert(true),
	)
	if err != nil && !mongo.IsDuplicateKeyError(err) {
		return fmt.Errorf("register device: %w", err)
	}
	return nil
}

// RemoveDevice unlinks a push token, for use on logout.
func (s *Service) RemoveDevice(ctx context.Context, userID, token string) error {
	if _, err := s.devices.DeleteOne(ctx, bson.M{"_id": token, "user_id": userID}); err != nil {
		return fmt.Errorf("remove device: %w", err)
	}
	return nil
}

// Inbox returns a user's latest notifications, newest first.
func (s *Service) Inbox(ctx context.Context, userID string) ([]Message, error) {
	cur, err := s.messages.Find(ctx, bson.M{"user_id": userID},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(inboxLimit))
	if err != nil {
		return nil, fmt.Errorf("find notifications: %w", err)
	}
	rows := []Message{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read notifications: %w", err)
	}
	return rows, nil
}

// Routes registers device and inbox endpoints.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("PUT /v1/me/devices", a.Require(s.handleRegister))
	mux.Handle("DELETE /v1/me/devices", a.Require(s.handleRemove))
	mux.Handle("GET /v1/notifications", a.Require(s.handleInbox))
	mux.Handle("GET /v1/notifications/unread", a.Require(s.handleUnread))
	mux.Handle("POST /v1/notifications/read", a.Require(s.handleMarkRead))
}

func (s *Service) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Token    string `json:"token"`
		Platform string `json:"platform"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.RegisterDevice(r.Context(), auth.UserID(r.Context()), req.Token, req.Platform); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleRemove(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Token string `json:"token"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.RemoveDevice(r.Context(), auth.UserID(r.Context()), req.Token); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleInbox(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Inbox(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

// Unread counts notifications the person has not seen yet.
func (s *Service) Unread(ctx context.Context, userID string) (int64, error) {
	n, err := s.messages.CountDocuments(ctx, bson.M{"user_id": userID, "read_at": bson.M{"$exists": false}})
	if err != nil {
		return 0, fmt.Errorf("count unread: %w", err)
	}
	return n, nil
}

// MarkRead marks everything in the inbox as seen.
func (s *Service) MarkRead(ctx context.Context, userID string, at time.Time) error {
	_, err := s.messages.UpdateMany(ctx,
		bson.M{"user_id": userID, "read_at": bson.M{"$exists": false}},
		bson.M{"$set": bson.M{"read_at": at}})
	if err != nil {
		return fmt.Errorf("mark read: %w", err)
	}
	return nil
}

func (s *Service) handleUnread(w http.ResponseWriter, r *http.Request) {
	n, err := s.Unread(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]int64{"count": n})
}

func (s *Service) handleMarkRead(w http.ResponseWriter, r *http.Request) {
	if err := s.MarkRead(r.Context(), auth.UserID(r.Context()), time.Now().UTC()); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
