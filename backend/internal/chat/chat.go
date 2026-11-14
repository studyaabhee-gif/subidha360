// Package chat lets a seeker and their assigned provider message about a job.
// Clients poll for now; WebSockets can replace that without changing storage.
package chat

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
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

const (
	maxBody     = 1000
	historySize = 200
	noteMessage = "chat.message"
)

type Message struct {
	ID        string    `bson:"_id" json:"id"`
	JobID     string    `bson:"job_id" json:"job_id"`
	SenderID  string    `bson:"sender_id" json:"sender_id"`
	Body      string    `bson:"body" json:"body"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
}

type Service struct {
	messages *mongo.Collection
	jobs     *job.Service
	notify   *notify.Service
	checker  Checker
}

// Checker looks for warning signs in a message, such as a shared phone
// number. It never blocks delivery.
type Checker interface {
	CheckMessage(ctx context.Context, senderID, jobID, body string) error
}

func NewService(db *mongo.Database, jobs *job.Service, n *notify.Service, checker Checker) *Service {
	return &Service{messages: db.Collection(mongodb.Messages), jobs: jobs, notify: n, checker: checker}
}

// isOpen reports whether a job's chat accepts new messages. History stays
// readable afterwards.
func isOpen(status job.Status) bool {
	return status == job.StatusAccepted || status == job.StatusInProgress || status == job.StatusDisputed
}

// Send adds a message from one party to the other.
func (s *Service) Send(ctx context.Context, senderID, jobID, body string) (*Message, error) {
	body = strings.TrimSpace(body)
	if body == "" || utf8.RuneCountInString(body) > maxBody {
		return nil, apperr.BadRequest("invalid_message", "messages must be 1 to 1000 characters")
	}
	j, err := s.jobs.Party(ctx, senderID, jobID)
	if err != nil {
		return nil, err
	}
	if !isOpen(j.Status) {
		return nil, apperr.Conflict("chat_closed", "chat is only open while a job is active")
	}
	m := &Message{
		ID:        uuid.NewString(),
		JobID:     jobID,
		SenderID:  senderID,
		Body:      body,
		CreatedAt: time.Now().UTC(),
	}
	if _, err := s.messages.InsertOne(ctx, m); err != nil {
		return nil, fmt.Errorf("insert message: %w", err)
	}
	if err := s.checker.CheckMessage(ctx, senderID, jobID, body); err != nil {
		// A failed check must not lose the message; it is only a warning sign.
		slog.Error("check message", "job", jobID, "err", err)
	}
	recipient := j.SeekerID
	if senderID == j.SeekerID {
		recipient = j.ProviderID
	}
	err = s.notify.Enqueue(ctx, notify.Message{
		UserID: recipient,
		JobID:  jobID,
		Type:   noteMessage,
		Title:  "New message",
		Body:   "You have a new message about your job.",
	})
	if err != nil {
		return nil, err
	}
	return m, nil
}

// List returns a job's messages, oldest first.
func (s *Service) List(ctx context.Context, userID, jobID string) ([]Message, error) {
	if _, err := s.jobs.Party(ctx, userID, jobID); err != nil {
		return nil, err
	}
	cur, err := s.messages.Find(ctx, bson.M{"job_id": jobID},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}}).SetLimit(historySize))
	if err != nil {
		return nil, fmt.Errorf("find messages: %w", err)
	}
	rows := []Message{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read messages: %w", err)
	}
	return rows, nil
}

// Routes registers chat endpoints.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("GET /v1/jobs/{id}/messages", a.Require(s.handleList))
	mux.Handle("POST /v1/jobs/{id}/messages", a.Require(s.handleSend))
}

func (s *Service) handleList(w http.ResponseWriter, r *http.Request) {
	rows, err := s.List(r.Context(), auth.UserID(r.Context()), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleSend(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Body string `json:"body"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	m, err := s.Send(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Body)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, m)
}
