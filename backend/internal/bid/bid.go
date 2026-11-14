// Package bid implements provider bids and the seeker's selection of a winner.
package bid

import (
	"context"
	"errors"
	"fmt"
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
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/user"
	"subidha360/backend/internal/wallet"
)

// Bid statuses.
const (
	StatusPending  = "PENDING"
	StatusAccepted = "ACCEPTED"
	StatusRejected = "REJECTED"
)

type Bid struct {
	ID          string `bson:"_id" json:"id"`
	JobID       string `bson:"job_id" json:"job_id"`
	ProviderID  string `bson:"provider_id" json:"provider_id"`
	AmountPaisa int64  `bson:"bid_amount" json:"amount_paisa"`
	Status      string `bson:"status" json:"status"`
	// PartsIncluded says the price is all-in, so seekers can compare like with like.
	PartsIncluded bool      `bson:"parts_included" json:"parts_included"`
	Note          string    `bson:"note,omitempty" json:"note,omitempty"`
	CreatedAt     time.Time `bson:"created_at" json:"created_at"`
	// Provider is filled in when listing bids, and never stored.
	Provider *user.PublicProfile `bson:"-" json:"provider,omitempty"`
}

const maxNoteLength = 300

type Service struct {
	client *mongo.Client
	bids   *mongo.Collection
	jobs   *job.Service
	ledger *wallet.Ledger
	users  *user.Repo
}

func NewService(client *mongo.Client, db *mongo.Database, jobs *job.Service, ledger *wallet.Ledger, users *user.Repo) *Service {
	return &Service{client: client, bids: db.Collection(mongodb.Bids), jobs: jobs, ledger: ledger, users: users}
}

type PlaceInput struct {
	AmountPaisa   int64
	PartsIncluded bool
	Note          string
}

// Place submits a provider's single bid on a job.
func (s *Service) Place(ctx context.Context, providerID, jobID string, in PlaceInput) (*Bid, error) {
	if in.AmountPaisa <= 0 {
		return nil, apperr.BadRequest("invalid_amount", "amount must be positive")
	}
	note := strings.TrimSpace(in.Note)
	if utf8.RuneCountInString(note) > maxNoteLength {
		return nil, apperr.BadRequest("invalid_note", "keep your note under 300 characters")
	}
	b := &Bid{
		ID:            uuid.NewString(),
		JobID:         jobID,
		ProviderID:    providerID,
		AmountPaisa:   in.AmountPaisa,
		Status:        StatusPending,
		PartsIncluded: in.PartsIncluded,
		Note:          note,
		CreatedAt:     time.Now().UTC(),
	}
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		if err := s.jobs.RecordBid(ctx, jobID, providerID); err != nil {
			return err
		}
		_, err := s.bids.InsertOne(ctx, b)
		if mongo.IsDuplicateKeyError(err) {
			return apperr.Conflict("bid_exists", "you have already bid on this job")
		}
		if err != nil {
			return fmt.Errorf("insert bid: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return b, nil
}

// List returns all bids to the job's seeker, and only their own to a provider.
func (s *Service) List(ctx context.Context, viewerID, jobID string) ([]Bid, error) {
	j, err := s.jobs.Get(ctx, viewerID, jobID)
	if err != nil {
		return nil, err
	}
	filter := bson.M{"job_id": jobID}
	if j.SeekerID != viewerID {
		filter["provider_id"] = viewerID
	}
	cur, err := s.bids.Find(ctx, filter, options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}}))
	if err != nil {
		return nil, fmt.Errorf("find bids: %w", err)
	}
	rows := []Bid{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read bids: %w", err)
	}
	ids := make([]string, len(rows))
	for i := range rows {
		ids[i] = rows[i].ProviderID
	}
	profiles, err := s.users.PublicProfiles(ctx, ids)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		if p, ok := profiles[rows[i].ProviderID]; ok {
			rows[i].Provider = &p
		}
	}
	return rows, nil
}

// Accept selects the winning bid. The job update, bid updates and escrow hold
// commit together, so a seeker with too little balance changes nothing.
func (s *Service) Accept(ctx context.Context, seekerID, jobID, bidID string) (*Bid, error) {
	var accepted Bid
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		err := s.bids.FindOneAndUpdate(ctx,
			bson.M{"_id": bidID, "job_id": jobID, "status": StatusPending},
			bson.M{"$set": bson.M{"status": StatusAccepted}},
			options.FindOneAndUpdate().SetReturnDocument(options.After),
		).Decode(&accepted)
		if errors.Is(err, mongo.ErrNoDocuments) {
			return apperr.NotFound("bid_not_found", "no pending bid with that id on this job")
		}
		if err != nil {
			return fmt.Errorf("accept bid: %w", err)
		}
		if err := s.jobs.Accept(ctx, jobID, seekerID, bidID, accepted.ProviderID, accepted.AmountPaisa); err != nil {
			return err
		}
		if err := s.ledger.HoldEscrow(ctx, seekerID, jobID, accepted.AmountPaisa); err != nil {
			return err
		}
		return s.RejectPending(ctx, jobID)
	})
	if err != nil {
		return nil, err
	}
	return &accepted, nil
}

// RejectPending implements job.BidCloser.
func (s *Service) RejectPending(ctx context.Context, jobID string) error {
	_, err := s.bids.UpdateMany(ctx,
		bson.M{"job_id": jobID, "status": StatusPending},
		bson.M{"$set": bson.M{"status": StatusRejected}},
	)
	if err != nil {
		return fmt.Errorf("reject bids: %w", err)
	}
	return nil
}

// Routes registers bid endpoints.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("POST /v1/jobs/{id}/bids", a.Require(s.handlePlace))
	mux.Handle("GET /v1/jobs/{id}/bids", a.Require(s.handleList))
	mux.Handle("POST /v1/jobs/{id}/bids/{bidID}/accept", a.Require(s.handleAccept))
}

func (s *Service) handlePlace(w http.ResponseWriter, r *http.Request) {
	var req struct {
		AmountPaisa   int64  `json:"amount_paisa"`
		PartsIncluded bool   `json:"parts_included"`
		Note          string `json:"note"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	b, err := s.Place(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), PlaceInput(req))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, b)
}

func (s *Service) handleList(w http.ResponseWriter, r *http.Request) {
	rows, err := s.List(r.Context(), auth.UserID(r.Context()), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleAccept(w http.ResponseWriter, r *http.Request) {
	b, err := s.Accept(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), r.PathValue("bidID"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, b)
}
