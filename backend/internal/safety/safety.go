// Package safety collects warning signs about accounts: reports people make
// about each other, and flags raised automatically when a chat message shares
// a phone number or asks to pay outside the app. Admins review them.
package safety

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"regexp"
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
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
)

// Reasons people can give, and the ones the system raises itself.
const (
	ReasonNoShow        = "no_show"
	ReasonRude          = "rude"
	ReasonAskedCash     = "asked_cash"
	ReasonFakeProfile   = "fake_profile"
	ReasonUnsafe        = "unsafe"
	ReasonOther         = "other"
	ReasonContactShared = "contact_shared"
	ReasonOffPlatform   = "off_platform"
)

// PersonReasons are the reasons a person can choose.
var PersonReasons = []string{ReasonNoShow, ReasonRude, ReasonAskedCash, ReasonFakeProfile, ReasonUnsafe, ReasonOther}

// Flag statuses.
const (
	StatusOpen     = "OPEN"
	StatusReviewed = "REVIEWED"
)

// ReporterSystem marks flags raised automatically.
const ReporterSystem = "system"

const maxDetails = 500

// Flag is one warning sign about an account.
type Flag struct {
	ID         string `bson:"_id" json:"id"`
	ReporterID string `bson:"reporter_id" json:"reporter_id"`
	ReportedID string `bson:"reported_id" json:"reported_id"`
	JobID      string `bson:"job_id" json:"job_id"`
	Reason     string `bson:"reason" json:"reason"`
	Details    string `bson:"details,omitempty" json:"details,omitempty"`
	// DedupeKey stops repeats: one report per person per job, and one
	// automatic flag per sign, sender and job.
	DedupeKey  string     `bson:"dedupe_key" json:"-"`
	Status     string     `bson:"status" json:"status"`
	Outcome    string     `bson:"outcome,omitempty" json:"outcome,omitempty"`
	ReviewedBy string     `bson:"reviewed_by,omitempty" json:"-"`
	CreatedAt  time.Time  `bson:"created_at" json:"created_at"`
	ReviewedAt *time.Time `bson:"reviewed_at,omitempty" json:"reviewed_at,omitempty"`
}

type Service struct {
	flags *mongo.Collection
	jobs  *job.Service
	now   func() time.Time
}

func NewService(db *mongo.Database, jobs *job.Service) *Service {
	return &Service{flags: db.Collection(mongodb.Flags), jobs: jobs, now: func() time.Time { return time.Now().UTC() }}
}

// Report lets one party of a job report the other. Each person can report a
// job once, so one bad day cannot become a pile of reports.
func (s *Service) Report(ctx context.Context, reporterID, jobID, reason, details string) (*Flag, error) {
	if !slices.Contains(PersonReasons, reason) {
		return nil, apperr.BadRequest("invalid_reason", "choose what happened")
	}
	details = strings.TrimSpace(details)
	if utf8.RuneCountInString(details) > maxDetails {
		return nil, apperr.BadRequest("invalid_details", "keep the details under 500 characters")
	}
	if reason == ReasonOther && details == "" {
		return nil, apperr.BadRequest("details_required", "tell us what happened")
	}
	j, err := s.jobs.Party(ctx, reporterID, jobID)
	if err != nil {
		return nil, err
	}
	reported := j.ProviderID
	if reporterID == j.ProviderID {
		reported = j.SeekerID
	}
	if reported == "" {
		return nil, apperr.Conflict("nobody_to_report", "no provider has been chosen for this job yet")
	}
	f := &Flag{
		ID: uuid.NewString(), ReporterID: reporterID, ReportedID: reported, JobID: jobID,
		Reason: reason, Details: details, Status: StatusOpen, CreatedAt: s.now(),
		DedupeKey: "person:" + reporterID + ":" + jobID,
	}
	_, err = s.flags.InsertOne(ctx, f)
	if mongo.IsDuplicateKeyError(err) {
		return nil, apperr.Conflict("already_reported", "you have already reported this job. Our team is looking at it")
	}
	if err != nil {
		return nil, fmt.Errorf("insert report: %w", err)
	}
	return f, nil
}

var (
	// A Nepali mobile number, with or without +977 and separators.
	mobilePattern = regexp.MustCompile(`(?:\+?977[\s-]*)?9[678](?:[\s.-]*\d){8}`)
	// Asking to pay or talk outside the app. Matched on whole words, in
	// English, Romanised Nepali and Devanagari.
	offPlatformPattern = regexp.MustCompile(`(?i)\b(?:cash|nagad|direct(?:ly)? pay|pay (?:me )?direct(?:ly)?|outside the app|whatsapp|viber|imo|esewa (?:me|ma|garnu)|khalti (?:me|ma|garnu))\b|नगद|सिधै`)
)

// Scan returns the warning signs in a chat message.
func Scan(body string) []string {
	var reasons []string
	if mobilePattern.MatchString(body) {
		reasons = append(reasons, ReasonContactShared)
	}
	if offPlatformPattern.MatchString(body) {
		reasons = append(reasons, ReasonOffPlatform)
	}
	return reasons
}

// CheckMessage raises a flag when a chat message shows warning signs. The
// message is still delivered: the flag is for an admin to judge. Each sign is
// flagged once per sender and job.
func (s *Service) CheckMessage(ctx context.Context, senderID, jobID, body string) error {
	for _, reason := range Scan(body) {
		excerpt := body
		if utf8.RuneCountInString(excerpt) > maxDetails {
			excerpt = string([]rune(excerpt)[:maxDetails])
		}
		_, err := s.flags.InsertOne(ctx, Flag{
			ID: uuid.NewString(), ReporterID: ReporterSystem, ReportedID: senderID, JobID: jobID,
			Reason: reason, Details: excerpt, Status: StatusOpen, CreatedAt: s.now(),
			DedupeKey: "auto:" + senderID + ":" + jobID + ":" + reason,
		})
		if err != nil && !mongo.IsDuplicateKeyError(err) {
			return fmt.Errorf("insert flag: %w", err)
		}
	}
	return nil
}

// List returns flags, newest first. reportedID limits them to one person.
func (s *Service) List(ctx context.Context, status, reportedID string, skip, limit int64) ([]Flag, error) {
	filter := bson.M{}
	switch status {
	case "":
	case StatusOpen, StatusReviewed:
		filter["status"] = status
	default:
		return nil, apperr.BadRequest("invalid_status", "unknown status")
	}
	if reportedID != "" {
		filter["reported_id"] = reportedID
	}
	cur, err := s.flags.Find(ctx, filter, options.Find().
		SetSort(bson.D{{Key: "created_at", Value: -1}}).SetSkip(skip).SetLimit(limit))
	if err != nil {
		return nil, fmt.Errorf("find flags: %w", err)
	}
	rows := []Flag{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read flags: %w", err)
	}
	return rows, nil
}

// Review closes a flag with what was found or done.
func (s *Service) Review(ctx context.Context, adminID, id, outcome string) (*Flag, error) {
	outcome = strings.TrimSpace(outcome)
	if outcome == "" || utf8.RuneCountInString(outcome) > maxDetails {
		return nil, apperr.BadRequest("outcome_required", "record what you found or did, in under 500 characters")
	}
	now := s.now()
	var f Flag
	err := s.flags.FindOneAndUpdate(ctx, bson.M{"_id": id, "status": StatusOpen}, bson.M{"$set": bson.M{
		"status": StatusReviewed, "outcome": outcome, "reviewed_by": adminID, "reviewed_at": now,
	}}, options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&f)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, apperr.Conflict("not_open", "this flag was already reviewed")
	}
	if err != nil {
		return nil, fmt.Errorf("review flag: %w", err)
	}
	return &f, nil
}

// Counts returns how many open and total flags a person has.
func (s *Service) Counts(ctx context.Context, reportedID string) (open, total int64, err error) {
	if total, err = s.flags.CountDocuments(ctx, bson.M{"reported_id": reportedID}); err != nil {
		return 0, 0, fmt.Errorf("count flags: %w", err)
	}
	if open, err = s.flags.CountDocuments(ctx, bson.M{"reported_id": reportedID, "status": StatusOpen}); err != nil {
		return 0, 0, fmt.Errorf("count flags: %w", err)
	}
	return open, total, nil
}

// Routes registers reporting. Review routes live in the admin package.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("POST /v1/jobs/{id}/report", a.Require(s.handleReport))
}

func (s *Service) handleReport(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Reason  string `json:"reason"`
		Details string `json:"details"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	f, err := s.Report(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Reason, req.Details)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, f)
}
