// Package review lets seekers rate providers after a completed job.
package review

import (
	"context"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"
	"unicode/utf8"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/job"
	"subidha360/backend/internal/notify"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/user"
)

const (
	maxCommentLength = 500
	profileReviews   = 20
	noteReviewed     = "review.received"
)

// allowedTags are the quick compliments a seeker can tap.
var allowedTags = []string{"On time", "Fair price", "Quality work", "Polite", "Clean finish"}

// Review uses the job ID as its _id, so a job can only ever have one.
type Review struct {
	JobID      string    `bson:"_id" json:"job_id"`
	ProviderID string    `bson:"provider_id" json:"provider_id"`
	SeekerID   string    `bson:"seeker_id" json:"-"`
	Rating     int       `bson:"rating" json:"rating"`
	Tags       []string  `bson:"tags" json:"tags"`
	Comment    string    `bson:"comment,omitempty" json:"comment,omitempty"`
	CreatedAt  time.Time `bson:"created_at" json:"created_at"`
}

type Service struct {
	client  *mongo.Client
	reviews *mongo.Collection
	jobs    *job.Service
	users   *user.Repo
	notify  *notify.Service
}

func NewService(client *mongo.Client, db *mongo.Database, jobs *job.Service, users *user.Repo, n *notify.Service) *Service {
	return &Service{client: client, reviews: db.Collection(mongodb.Reviews), jobs: jobs, users: users, notify: n}
}

type Input struct {
	Rating  int
	Tags    []string
	Comment string
}

// Create records a review and updates the provider's rating in one transaction.
func (s *Service) Create(ctx context.Context, seekerID, jobID string, in Input) (*Review, error) {
	if in.Rating < 1 || in.Rating > 5 {
		return nil, apperr.BadRequest("invalid_rating", "rating must be from 1 to 5")
	}
	for _, tag := range in.Tags {
		if !slices.Contains(allowedTags, tag) {
			return nil, apperr.BadRequest("invalid_tag", "unknown review tag")
		}
	}
	comment := strings.TrimSpace(in.Comment)
	if utf8.RuneCountInString(comment) > maxCommentLength {
		return nil, apperr.BadRequest("invalid_comment", "keep your comment under 500 characters")
	}
	tags := in.Tags
	if tags == nil {
		tags = []string{}
	}

	var result *Review
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		j, err := s.jobs.MarkReviewed(ctx, seekerID, jobID)
		if err != nil {
			return err
		}
		r := &Review{
			JobID:      jobID,
			ProviderID: j.ProviderID,
			SeekerID:   seekerID,
			Rating:     in.Rating,
			Tags:       tags,
			Comment:    comment,
			CreatedAt:  time.Now().UTC(),
		}
		if _, err := s.reviews.InsertOne(ctx, r); err != nil {
			return fmt.Errorf("insert review: %w", err)
		}
		if err := s.users.AddRating(ctx, j.ProviderID, in.Rating); err != nil {
			return err
		}
		result = r
		return s.notify.Enqueue(ctx, notify.Message{
			UserID: j.ProviderID,
			JobID:  jobID,
			Type:   noteReviewed,
			Title:  "New review",
			Body:   fmt.Sprintf("A customer gave you %d out of 5.", in.Rating),
		})
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// Profile returns a provider's public profile and latest reviews.
func (s *Service) Profile(ctx context.Context, providerID string) (map[string]any, error) {
	u, err := s.users.Get(ctx, providerID)
	if err != nil {
		return nil, err
	}
	if !u.HasProviderProfile {
		return nil, apperr.NotFound("provider_not_found", "provider not found")
	}
	cur, err := s.reviews.Find(ctx, bson.M{"provider_id": providerID},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(profileReviews))
	if err != nil {
		return nil, fmt.Errorf("find reviews: %w", err)
	}
	rows := []Review{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read reviews: %w", err)
	}
	return map[string]any{"profile": u.Public(), "reviews": rows}, nil
}

// Routes registers review endpoints.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("POST /v1/jobs/{id}/review", a.Require(s.handleCreate))
	mux.Handle("GET /v1/providers/{id}", a.Require(s.handleProfile))
}

func (s *Service) handleCreate(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Rating  int      `json:"rating"`
		Tags    []string `json:"tags"`
		Comment string   `json:"comment"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	review, err := s.Create(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), Input(req))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, review)
}

func (s *Service) handleProfile(w http.ResponseWriter, r *http.Request) {
	profile, err := s.Profile(r.Context(), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, profile)
}
