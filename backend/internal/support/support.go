// Package support lets anyone write to the Subidha360 team from the app, and
// lets admins answer. Each conversation is a thread, optionally about a job.
package support

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/job"
	"subidha360/backend/internal/notify"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
)

// Thread statuses.
const (
	StatusOpen   = "OPEN"
	StatusClosed = "CLOSED"
)

// Topics help admins sort the inbox.
var Topics = []string{"job", "payment", "account", "safety", "other"}

const (
	maxOpenThreads = 3
	maxBody        = 2000
	maxMessages    = 300
	listLimit      = 50
	noteReply      = "support.reply"
)

type Thread struct {
	ID      string `bson:"_id" json:"id"`
	UserID  string `bson:"user_id" json:"user_id"`
	Subject string `bson:"subject" json:"subject"`
	Topic   string `bson:"topic" json:"topic"`
	JobID   string `bson:"job_id,omitempty" json:"job_id,omitempty"`
	Status  string `bson:"status" json:"status"`
	// UnreadByUser and UnreadByStaff drive the badges on each side.
	UnreadByUser  bool      `bson:"unread_by_user" json:"unread_by_user"`
	UnreadByStaff bool      `bson:"unread_by_staff" json:"unread_by_staff"`
	LastMessageAt time.Time `bson:"last_message_at" json:"last_message_at"`
	CreatedAt     time.Time `bson:"created_at" json:"created_at"`
}

type Message struct {
	ID        string    `bson:"_id" json:"id"`
	ThreadID  string    `bson:"thread_id" json:"-"`
	SenderID  string    `bson:"sender_id" json:"-"`
	FromStaff bool      `bson:"from_staff" json:"from_staff"`
	Body      string    `bson:"body" json:"body"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
}

// ThreadView is a thread with its messages.
type ThreadView struct {
	Thread   Thread    `json:"thread"`
	Messages []Message `json:"messages"`
}

type Service struct {
	client   *mongo.Client
	threads  *mongo.Collection
	messages *mongo.Collection
	jobs     *job.Service
	notify   *notify.Service
	now      func() time.Time
}

func NewService(client *mongo.Client, db *mongo.Database, jobs *job.Service, n *notify.Service) *Service {
	return &Service{
		client:   client,
		threads:  db.Collection(mongodb.SupportThreads),
		messages: db.Collection(mongodb.SupportMessages),
		jobs:     jobs,
		notify:   n,
		now:      func() time.Time { return time.Now().UTC() },
	}
}

func cleanBody(body string) (string, error) {
	body = strings.TrimSpace(body)
	if body == "" || utf8.RuneCountInString(body) > maxBody {
		return "", apperr.BadRequest("invalid_message", "messages must be 1 to 2000 characters")
	}
	return body, nil
}

// OpenInput is what someone writes to start a conversation.
type OpenInput struct {
	Subject string `json:"subject"`
	Topic   string `json:"topic"`
	JobID   string `json:"job_id"`
	Body    string `json:"body"`
}

// Open starts a conversation with the team.
func (s *Service) Open(ctx context.Context, userID string, in OpenInput) (*ThreadView, error) {
	subject := strings.TrimSpace(in.Subject)
	if n := utf8.RuneCountInString(subject); n < 3 || n > 80 {
		return nil, apperr.BadRequest("invalid_subject", "the subject must be 3 to 80 characters")
	}
	if !slices.Contains(Topics, in.Topic) {
		return nil, apperr.BadRequest("invalid_topic", "choose what this is about")
	}
	body, err := cleanBody(in.Body)
	if err != nil {
		return nil, err
	}
	if in.JobID != "" {
		// Only someone on the job can ask about it.
		if _, err := s.jobs.Party(ctx, userID, in.JobID); err != nil {
			return nil, err
		}
	}
	now := s.now()
	t := Thread{
		ID: uuid.NewString(), UserID: userID, Subject: subject, Topic: in.Topic, JobID: in.JobID,
		Status: StatusOpen, UnreadByStaff: true, LastMessageAt: now, CreatedAt: now,
	}
	m := Message{ID: uuid.NewString(), ThreadID: t.ID, SenderID: userID, Body: body, CreatedAt: now}
	err = mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		n, err := s.threads.CountDocuments(ctx, bson.M{"user_id": userID, "status": StatusOpen})
		if err != nil {
			return fmt.Errorf("count threads: %w", err)
		}
		if n >= maxOpenThreads {
			return apperr.Conflict("too_many_open", "you have 3 open conversations. Reply in one of those instead")
		}
		if _, err := s.threads.InsertOne(ctx, t); err != nil {
			return fmt.Errorf("insert thread: %w", err)
		}
		if _, err := s.messages.InsertOne(ctx, m); err != nil {
			return fmt.Errorf("insert message: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return &ThreadView{Thread: t, Messages: []Message{m}}, nil
}

// Mine lists someone's conversations, most recent first.
func (s *Service) Mine(ctx context.Context, userID string) ([]Thread, error) {
	return s.list(ctx, bson.M{"user_id": userID}, 0, listLimit)
}

func (s *Service) list(ctx context.Context, filter bson.M, skip, limit int64) ([]Thread, error) {
	cur, err := s.threads.Find(ctx, filter, options.Find().
		SetSort(bson.D{{Key: "last_message_at", Value: -1}}).SetSkip(skip).SetLimit(limit))
	if err != nil {
		return nil, fmt.Errorf("find threads: %w", err)
	}
	rows := []Thread{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read threads: %w", err)
	}
	return rows, nil
}

// Inbox lists conversations for admins, most recent first. Status "" means
// all of them.
func (s *Service) Inbox(ctx context.Context, status string, skip, limit int64) ([]Thread, error) {
	filter := bson.M{}
	switch status {
	case "":
	case StatusOpen, StatusClosed:
		filter["status"] = status
	default:
		return nil, apperr.BadRequest("invalid_status", "unknown status")
	}
	return s.list(ctx, filter, skip, limit)
}

// View returns a conversation and marks it read for whoever is looking.
// ownerID limits it to that person's threads; staff pass "".
func (s *Service) View(ctx context.Context, ownerID, id string) (*ThreadView, error) {
	filter := bson.M{"_id": id}
	readField := "unread_by_staff"
	if ownerID != "" {
		filter["user_id"] = ownerID
		readField = "unread_by_user"
	}
	var t Thread
	err := s.threads.FindOneAndUpdate(ctx, filter, bson.M{"$set": bson.M{readField: false}},
		options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&t)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, apperr.NotFound("thread_not_found", "conversation not found")
	}
	if err != nil {
		return nil, fmt.Errorf("load thread: %w", err)
	}
	cur, err := s.messages.Find(ctx, bson.M{"thread_id": id},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}}).SetLimit(maxMessages))
	if err != nil {
		return nil, fmt.Errorf("find messages: %w", err)
	}
	v := &ThreadView{Thread: t, Messages: []Message{}}
	if err := cur.All(ctx, &v.Messages); err != nil {
		return nil, fmt.Errorf("read messages: %w", err)
	}
	return v, nil
}

// Reply adds a message. A reply from the person reopens a closed thread; a
// reply from staff tells them by notification.
func (s *Service) Reply(ctx context.Context, senderID, id, body string, fromStaff bool) (*ThreadView, error) {
	body, err := cleanBody(body)
	if err != nil {
		return nil, err
	}
	now := s.now()
	err = mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		filter := bson.M{"_id": id}
		set := bson.M{"last_message_at": now}
		if fromStaff {
			set["unread_by_user"] = true
		} else {
			filter["user_id"] = senderID
			set["unread_by_staff"] = true
			set["status"] = StatusOpen
		}
		var t Thread
		err := s.threads.FindOneAndUpdate(ctx, filter, bson.M{"$set": set}).Decode(&t)
		if errors.Is(err, mongo.ErrNoDocuments) {
			return apperr.NotFound("thread_not_found", "conversation not found")
		}
		if err != nil {
			return fmt.Errorf("update thread: %w", err)
		}
		m := Message{ID: uuid.NewString(), ThreadID: id, SenderID: senderID, FromStaff: fromStaff, Body: body, CreatedAt: now}
		if _, err := s.messages.InsertOne(ctx, m); err != nil {
			return fmt.Errorf("insert message: %w", err)
		}
		if !fromStaff {
			return nil
		}
		return s.notify.Enqueue(ctx, notify.Message{
			UserID: t.UserID, JobID: t.JobID, Type: noteReply,
			Title: "Reply from Subidha360", Body: "Our team replied to: " + t.Subject,
		})
	})
	if err != nil {
		return nil, err
	}
	owner := senderID
	if fromStaff {
		owner = ""
	}
	return s.View(ctx, owner, id)
}

// Close marks a conversation as dealt with. The person can still reply.
func (s *Service) Close(ctx context.Context, id string) (*Thread, error) {
	var t Thread
	err := s.threads.FindOneAndUpdate(ctx, bson.M{"_id": id, "status": StatusOpen},
		bson.M{"$set": bson.M{"status": StatusClosed, "unread_by_staff": false}},
		options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&t)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, apperr.Conflict("not_open", "this conversation is not open")
	}
	if err != nil {
		return nil, fmt.Errorf("close thread: %w", err)
	}
	return &t, nil
}

// Routes registers the person's side. Staff routes live in the admin
// package, which audits them.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("GET /v1/support/threads", a.Require(s.handleMine))
	mux.Handle("POST /v1/support/threads", a.Require(s.handleOpen))
	mux.Handle("GET /v1/support/threads/{id}", a.Require(s.handleView))
	mux.Handle("POST /v1/support/threads/{id}/messages", a.Require(s.handleReply))
}

func (s *Service) handleMine(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Mine(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleOpen(w http.ResponseWriter, r *http.Request) {
	var req OpenInput
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	v, err := s.Open(r.Context(), auth.UserID(r.Context()), req)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, v)
}

func (s *Service) handleView(w http.ResponseWriter, r *http.Request) {
	v, err := s.View(r.Context(), auth.UserID(r.Context()), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, v)
}

func (s *Service) handleReply(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Body string `json:"body"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	v, err := s.Reply(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Body, false)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, v)
}
