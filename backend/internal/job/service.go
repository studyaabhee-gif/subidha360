// Package job implements service requests and their lifecycle.
package job

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strings"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/catalog"
	"subidha360/backend/internal/geo"
	"subidha360/backend/internal/notify"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/user"
	"subidha360/backend/internal/wallet"
)

const listLimit = 100

// defaultProviderPercent is the provider's share of escrow when a seeker
// cancels mid-work and no admin decides in time.
const defaultProviderPercent = 50

// resolvedBySystem marks escrow splits applied by the timeout worker.
const resolvedBySystem = "system"

// autoReleaseReminderLead is how long before auto-release a silent seeker gets
// a second warning.
const autoReleaseReminderLead = 24 * time.Hour

// Cancellation review tags. Admin tooling will move PENDING to VALID or INVALID.
const ReviewPending = "PENDING"

var (
	errNotFound = apperr.NotFound("job_not_found", "job not found")
	errConflict = apperr.Conflict("invalid_job_state", "job is not in a state that allows this action")
)

type Job struct {
	ID                  string     `bson:"_id" json:"id"`
	SeekerID            string     `bson:"seeker_id" json:"seeker_id"`
	CategoryID          int        `bson:"category_id" json:"category_id"`
	Status              Status     `bson:"status" json:"status"`
	Description         string     `bson:"description" json:"description"`
	Address             string     `bson:"address" json:"address"`
	JobLocation         geo.Point  `bson:"job_location" json:"job_location"`
	AIMetadata          bson.M     `bson:"ai_metadata,omitempty" json:"ai_metadata,omitempty"`
	EligibleProviderIDs []string   `bson:"eligible_provider_ids" json:"-"`
	BidCount            int        `bson:"bid_count" json:"bid_count"`
	WindowEndsAt        time.Time  `bson:"window_ends_at" json:"window_ends_at"`
	AcceptedBidID       string     `bson:"accepted_bid_id,omitempty" json:"accepted_bid_id,omitempty"`
	ProviderID          string     `bson:"provider_id,omitempty" json:"provider_id,omitempty"`
	EscrowAmount        int64      `bson:"escrow_amount" json:"escrow_amount_paisa"`
	SeekerConfirmedAt   *time.Time `bson:"seeker_confirmed_at,omitempty" json:"seeker_confirmed_at,omitempty"`
	ProviderConfirmedAt *time.Time `bson:"provider_confirmed_at,omitempty" json:"provider_confirmed_at,omitempty"`
	// SelectionDeadline is when an open job with bids expires.
	SelectionDeadline *time.Time `bson:"selection_deadline,omitempty" json:"selection_deadline,omitempty"`
	// AutoReleaseAt is when escrow is released if only one party has confirmed.
	AutoReleaseAt *time.Time `bson:"auto_release_at,omitempty" json:"auto_release_at,omitempty"`
	// ServiceID links to the catalogue entry, when the job came from one.
	ServiceID string `bson:"service_id,omitempty" json:"service_id,omitempty"`
	// PreferredDate (YYYY-MM-DD) and PreferredSlot are when the seeker wants the
	// work done. Both empty means as soon as possible.
	PreferredDate string     `bson:"preferred_date,omitempty" json:"preferred_date,omitempty"`
	PreferredSlot string     `bson:"preferred_slot,omitempty" json:"preferred_slot,omitempty"`
	CompletedAt   *time.Time `bson:"completed_at,omitempty" json:"completed_at,omitempty"`
	// CancelledAt is when the job closed as cancelled, for reports.
	CancelledAt *time.Time `bson:"cancelled_at,omitempty" json:"cancelled_at,omitempty"`
	// WarrantyEndsAt is the last moment the service guarantee can be claimed.
	WarrantyEndsAt *time.Time     `bson:"warranty_ends_at,omitempty" json:"warranty_ends_at,omitempty"`
	WarrantyClaim  *WarrantyClaim `bson:"warranty_claim,omitempty" json:"warranty_claim,omitempty"`
	Reviewed       bool           `bson:"reviewed" json:"reviewed"`
	// ReleaseReminderSentAt stops the auto-release reminder being sent twice.
	ReleaseReminderSentAt *time.Time `bson:"release_reminder_sent_at,omitempty" json:"-"`
	// EscrowReviewRequired marks a job the seeker cancelled mid-work: its escrow
	// is held until an admin decides, or EscrowReviewDueAt passes.
	EscrowReviewRequired bool              `bson:"escrow_review_required" json:"escrow_review_required"`
	EscrowReviewDueAt    *time.Time        `bson:"escrow_review_due_at,omitempty" json:"escrow_review_due_at,omitempty"`
	EscrowResolution     *EscrowResolution `bson:"escrow_resolution,omitempty" json:"escrow_resolution,omitempty"`
	Dispute              *Dispute          `bson:"dispute,omitempty" json:"dispute,omitempty"`
	Cancellation         *Cancellation     `bson:"cancellation,omitempty" json:"cancellation,omitempty"`
	// PhotoIDs are pictures of the problem, served by their own route.
	PhotoIDs []string `bson:"photo_ids,omitempty" json:"photo_ids,omitempty"`
	// RescheduleCount counts how often the seeker has moved the time.
	RescheduleCount int `bson:"reschedule_count,omitempty" json:"reschedule_count"`
	// ProviderLocation has its own route, so it never appears in job lists.
	ProviderLocation *Tracking `bson:"provider_location,omitempty" json:"-"`
	CreatedAt        time.Time `bson:"created_at" json:"created_at"`
	UpdatedAt        time.Time `bson:"updated_at" json:"updated_at"`
}

// Warranty claim statuses.
const (
	ClaimOpen   = "OPEN"
	ClaimClosed = "CLOSED"
)

// WarrantyClaim is a request for a free re-visit after a job was completed.
type WarrantyClaim struct {
	Reason     string     `bson:"reason" json:"reason"`
	Status     string     `bson:"status" json:"status"`
	At         time.Time  `bson:"at" json:"at"`
	ClosedAt   *time.Time `bson:"closed_at,omitempty" json:"closed_at,omitempty"`
	ClosedNote string     `bson:"closed_note,omitempty" json:"closed_note,omitempty"`
}

// Slots are the two-hour arrival windows a seeker can choose from.
var Slots = []string{"08-10", "10-12", "12-14", "14-16", "16-18"}

// maxDaysAhead is how far ahead a job can be scheduled.
const maxDaysAhead = 14

type Dispute struct {
	RaisedBy string    `bson:"raised_by" json:"raised_by"`
	Reason   string    `bson:"reason" json:"reason"`
	At       time.Time `bson:"at" json:"at"`
}

// EscrowResolution records how held escrow was divided, and by whom.
type EscrowResolution struct {
	ProviderPercent int64     `bson:"provider_percent" json:"provider_percent"`
	ResolvedBy      string    `bson:"resolved_by" json:"resolved_by"`
	At              time.Time `bson:"at" json:"at"`
}

type Cancellation struct {
	CancelledBy string    `bson:"cancelled_by" json:"cancelled_by"`
	Reason      string    `bson:"reason" json:"reason"`
	Review      string    `bson:"review" json:"review"`
	At          time.Time `bson:"at" json:"at"`
}

// BidCloser rejects a job's outstanding bids. It is implemented by the bid
// package, which depends on this one.
type BidCloser interface {
	RejectPending(ctx context.Context, jobID string) error
}

type Options struct {
	BidWindow          time.Duration
	SelectionWindow    time.Duration
	AutoReleaseAfter   time.Duration
	EscrowReviewWindow time.Duration
	WarrantyDays       int
	EscalationMeters   float64
	CommissionBPS      int64
}

type Service struct {
	client *mongo.Client
	jobs   *mongo.Collection
	photos *mongo.Collection
	users  *user.Repo
	ledger *wallet.Ledger
	notify *notify.Service
	bids   BidCloser
	opts   Options
}

func NewService(client *mongo.Client, db *mongo.Database, users *user.Repo, ledger *wallet.Ledger, n *notify.Service, o Options) *Service {
	return &Service{client: client, jobs: db.Collection(mongodb.Jobs), photos: db.Collection(mongodb.JobPhotos), users: users, ledger: ledger, notify: n, opts: o}
}

// SetBidCloser completes wiring once the bid service exists.
func (s *Service) SetBidCloser(b BidCloser) { s.bids = b }

type CreateInput struct {
	CategoryID    int
	ServiceID     string
	Description   string
	Address       string
	Lat           float64
	Lng           float64
	PreferredDate string
	PreferredSlot string
	// PreferredProviderID asks a known provider directly, such as a favourite.
	PreferredProviderID string
}

// validateSchedule accepts an empty schedule, meaning as soon as possible. The
// date check allows yesterday because "today" in Nepal runs ahead of UTC.
func validateSchedule(date, slot string, now time.Time) error {
	if date == "" && slot == "" {
		return nil
	}
	day, err := time.Parse(time.DateOnly, date)
	if err != nil || !slices.Contains(Slots, slot) {
		return apperr.BadRequest("invalid_schedule", "choose a valid date and time window")
	}
	today := now.UTC().Truncate(24 * time.Hour)
	if day.Before(today.AddDate(0, 0, -1)) || day.After(today.AddDate(0, 0, maxDaysAhead+1)) {
		return apperr.BadRequest("invalid_schedule", "choose a date within the next two weeks")
	}
	return nil
}

// Create opens a job and broadcasts it to providers covering its location. A
// job with no eligible providers still opens, and escalates when its window ends.
func (s *Service) Create(ctx context.Context, seekerID string, in CreateInput) (*Job, error) {
	if !catalog.ValidCategory(in.CategoryID) {
		return nil, apperr.BadRequest("invalid_category", "choose a valid service category")
	}
	if in.ServiceID != "" && !catalog.ValidService(in.CategoryID, in.ServiceID) {
		return nil, apperr.BadRequest("invalid_service", "that service is not in this category")
	}
	if err := validateSchedule(in.PreferredDate, in.PreferredSlot, time.Now()); err != nil {
		return nil, err
	}
	if strings.TrimSpace(in.Description) == "" {
		return nil, apperr.BadRequest("invalid_description", "description is required")
	}
	point, err := geo.NewPoint(in.Lat, in.Lng)
	if err != nil {
		return nil, err
	}
	providers, err := s.users.ProvidersCovering(ctx, point, in.CategoryID, seekerID, user.AvailableAt(in.PreferredDate, in.PreferredSlot))
	if err != nil {
		return nil, err
	}
	if in.PreferredProviderID != "" {
		if err := s.checkPreferred(ctx, seekerID, in.PreferredProviderID, in.CategoryID); err != nil {
			return nil, err
		}
		if !slices.Contains(providers, in.PreferredProviderID) {
			providers = append(providers, in.PreferredProviderID)
		}
	}

	now := time.Now().UTC()
	j := &Job{
		ID:                  uuid.NewString(),
		SeekerID:            seekerID,
		CategoryID:          in.CategoryID,
		ServiceID:           in.ServiceID,
		PreferredDate:       in.PreferredDate,
		PreferredSlot:       in.PreferredSlot,
		Status:              StatusBroadcasting,
		Description:         in.Description,
		Address:             in.Address,
		JobLocation:         point,
		EligibleProviderIDs: providers,
		WindowEndsAt:        now.Add(s.opts.BidWindow),
		CreatedAt:           now,
		UpdatedAt:           now,
	}
	err = mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		if _, err := s.jobs.InsertOne(ctx, j); err != nil {
			return fmt.Errorf("insert job: %w", err)
		}
		return s.noteBroadcast(ctx, j, providers)
	})
	if err != nil {
		return nil, err
	}
	return j, nil
}

func (s *Service) load(ctx context.Context, id string) (*Job, error) {
	var j Job
	err := s.jobs.FindOne(ctx, bson.M{"_id": id}).Decode(&j)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, errNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("load job: %w", err)
	}
	return &j, nil
}

// Load returns any job, for admin tools. Never expose it to ordinary users.
func (s *Service) Load(ctx context.Context, id string) (*Job, error) { return s.load(ctx, id) }

// Get returns a job the viewer may see: the seeker's own, one assigned to the
// viewer, or one broadcast to the viewer. Others look like they do not exist.
func (s *Service) Get(ctx context.Context, viewerID, id string) (*Job, error) {
	j, err := s.load(ctx, id)
	if err != nil {
		return nil, err
	}
	if j.SeekerID != viewerID && j.ProviderID != viewerID && !slices.Contains(j.EligibleProviderIDs, viewerID) {
		return nil, errNotFound
	}
	return j, nil
}

func (s *Service) list(ctx context.Context, filter bson.M) ([]Job, error) {
	cur, err := s.jobs.Find(ctx, filter, options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(listLimit))
	if err != nil {
		return nil, fmt.Errorf("find jobs: %w", err)
	}
	rows := []Job{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read jobs: %w", err)
	}
	return rows, nil
}

// ListBySeeker returns a seeker's jobs, newest first.
func (s *Service) ListBySeeker(ctx context.Context, seekerID string) ([]Job, error) {
	return s.list(ctx, bson.M{"seeker_id": seekerID})
}

// ListAssigned returns jobs a provider won, newest first.
func (s *Service) ListAssigned(ctx context.Context, providerID string) ([]Job, error) {
	return s.list(ctx, bson.M{"provider_id": providerID})
}

// Party returns a job if userID is its seeker or assigned provider.
func (s *Service) Party(ctx context.Context, userID, id string) (*Job, error) {
	j, err := s.load(ctx, id)
	if err != nil {
		return nil, err
	}
	if j.SeekerID != userID && j.ProviderID != userID {
		return nil, errNotFound
	}
	return j, nil
}

// MarkReviewed flags a completed job as reviewed and returns it. The conditional
// update allows exactly one review per job, even with concurrent requests.
func (s *Service) MarkReviewed(ctx context.Context, seekerID, id string) (*Job, error) {
	var j Job
	err := s.jobs.FindOneAndUpdate(ctx,
		bson.M{"_id": id, "seeker_id": seekerID, "status": StatusCompleted, "reviewed": bson.M{"$ne": true}},
		bson.M{"$set": bson.M{"reviewed": true}},
	).Decode(&j)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, apperr.Conflict("cannot_review", "only a completed job can be reviewed, and only once")
	}
	if err != nil {
		return nil, fmt.Errorf("mark reviewed: %w", err)
	}
	return &j, nil
}

// ClaimWarranty opens a service guarantee claim on a completed job.
func (s *Service) ClaimWarranty(ctx context.Context, seekerID, id, reason string) (*Job, error) {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return nil, apperr.BadRequest("reason_required", "describe what went wrong")
	}
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		now := time.Now().UTC()
		var j Job
		err := s.jobs.FindOneAndUpdate(ctx,
			bson.M{
				"_id":              id,
				"seeker_id":        seekerID,
				"status":           StatusCompleted,
				"warranty_ends_at": bson.M{"$gte": now},
				"warranty_claim":   bson.M{"$exists": false},
			},
			bson.M{"$set": bson.M{
				"warranty_claim": WarrantyClaim{Reason: reason, Status: ClaimOpen, At: now},
				"updated_at":     now,
			}},
		).Decode(&j)
		if errors.Is(err, mongo.ErrNoDocuments) {
			return apperr.Conflict("cannot_claim", "this job has no guarantee available to claim")
		}
		if err != nil {
			return fmt.Errorf("claim warranty: %w", err)
		}
		return s.notify.Enqueue(ctx, criticalNote(j.ProviderID, &j, noteWarrantyClaim, "Guarantee claim",
			"A customer reported a problem with a finished job. Our team will be in touch."))
	})
	if err != nil {
		return nil, err
	}
	return s.load(ctx, id)
}

// ListWarrantyClaims returns open claims for admins, newest first.
func (s *Service) ListWarrantyClaims(ctx context.Context) ([]Job, error) {
	return s.list(ctx, bson.M{"warranty_claim.status": ClaimOpen})
}

// CloseWarrantyClaim records how an admin resolved a claim.
func (s *Service) CloseWarrantyClaim(ctx context.Context, id, note string) (*Job, error) {
	note = strings.TrimSpace(note)
	if note == "" {
		return nil, apperr.BadRequest("note_required", "record how the claim was resolved")
	}
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		now := time.Now().UTC()
		var j Job
		err := s.jobs.FindOneAndUpdate(ctx,
			bson.M{"_id": id, "warranty_claim.status": ClaimOpen},
			bson.M{"$set": bson.M{
				"warranty_claim.status":      ClaimClosed,
				"warranty_claim.closed_at":   now,
				"warranty_claim.closed_note": note,
			}},
		).Decode(&j)
		if errors.Is(err, mongo.ErrNoDocuments) {
			return apperr.Conflict("no_open_claim", "this job has no open claim")
		}
		if err != nil {
			return fmt.Errorf("close claim: %w", err)
		}
		return s.notify.Enqueue(ctx, criticalNote(j.SeekerID, &j, noteWarrantyClaim, "Guarantee claim closed", note))
	})
	if err != nil {
		return nil, err
	}
	return s.load(ctx, id)
}

// Feed returns open jobs broadcast to a provider, newest first.
func (s *Service) Feed(ctx context.Context, providerID string) ([]Job, error) {
	return s.list(ctx, bson.M{"eligible_provider_ids": providerID, "status": bson.M{"$in": OpenStatuses}})
}

// transition moves a job from one of the given states, failing with a conflict
// if another request changed the job first.
func (s *Service) transition(ctx context.Context, filter bson.M, from []Status, to Status, set bson.M) error {
	for _, f := range from {
		if !CanTransition(f, to) {
			return fmt.Errorf("illegal transition %s -> %s", f, to)
		}
	}
	now := time.Now().UTC()
	update := bson.M{"status": to, "updated_at": now}
	if to == StatusCompleted {
		update["completed_at"] = now
		update["warranty_ends_at"] = now.AddDate(0, 0, s.opts.WarrantyDays)
	}
	if to == StatusCancelled {
		update["cancelled_at"] = now
	}
	for k, v := range set {
		update[k] = v
	}
	filter["status"] = bson.M{"$in": from}
	ops := bson.M{"$set": update}
	// A provider's position is only kept while they are on the job.
	if to != StatusAccepted && to != StatusInProgress {
		ops["$unset"] = bson.M{"provider_location": ""}
	}
	res, err := s.jobs.UpdateOne(ctx, filter, ops)
	if err != nil {
		return fmt.Errorf("update job: %w", err)
	}
	if res.MatchedCount == 0 {
		return errConflict
	}
	return nil
}

// RecordBid counts a new bid. Updating the job document inside the bid's
// transaction makes bid placement conflict with acceptance and cancellation, so
// a bid can never land on a job that just closed.
func (s *Service) RecordBid(ctx context.Context, jobID, providerID string) error {
	now := time.Now().UTC()
	var j Job
	err := s.jobs.FindOneAndUpdate(ctx,
		bson.M{"_id": jobID, "eligible_provider_ids": providerID, "status": bson.M{"$in": OpenStatuses}},
		bson.M{
			"$inc": bson.M{"bid_count": 1},
			"$set": bson.M{"updated_at": now},
			// $min keeps the deadline set by the first bid.
			"$min": bson.M{"selection_deadline": now.Add(s.opts.SelectionWindow)},
		},
	).Decode(&j)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return apperr.Conflict("job_not_biddable", "this job is not open to your bids")
	}
	if err != nil {
		return fmt.Errorf("record bid: %w", err)
	}
	return s.notify.Enqueue(ctx, note(j.SeekerID, &j, noteBidReceived, "New bid", "A provider sent a bid on your job."))
}

// Accept assigns a job to the winning bid. It must run inside the caller's transaction.
func (s *Service) Accept(ctx context.Context, jobID, seekerID, bidID, providerID string, amount int64) error {
	err := s.transition(ctx, bson.M{"_id": jobID, "seeker_id": seekerID}, OpenStatuses, StatusAccepted, bson.M{
		"accepted_bid_id": bidID,
		"provider_id":     providerID,
		"escrow_amount":   amount,
	})
	if err != nil {
		return err
	}
	j := &Job{ID: jobID}
	return s.notify.Enqueue(ctx, criticalNote(providerID, j, noteBidAccepted, "You won the job", "Your bid was accepted and the payment is secured. Open the app for details."))
}

// Start marks work as begun. Only the assigned provider can do this.
func (s *Service) Start(ctx context.Context, providerID, id string) error {
	return mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		err := s.transition(ctx, bson.M{"_id": id, "provider_id": providerID},
			[]Status{StatusAccepted}, StatusInProgress, nil)
		if err != nil {
			return err
		}
		j, err := s.load(ctx, id)
		if err != nil {
			return err
		}
		return s.notify.Enqueue(ctx, note(j.SeekerID, j, noteJobStarted, "Work started", "Your provider has started the job."))
	})
}

// ConfirmCompletion records one party's confirmation. The first one starts the
// auto-release timer. The second completes the job and settles escrow in the
// same transaction.
func (s *Service) ConfirmCompletion(ctx context.Context, userID, id string) (*Job, error) {
	var result *Job
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		j, err := s.Get(ctx, userID, id)
		if err != nil {
			return err
		}
		var field string
		switch userID {
		case j.SeekerID:
			field = "seeker_confirmed_at"
		case j.ProviderID:
			field = "provider_confirmed_at"
		default:
			return apperr.Forbidden("not_a_party", "only the seeker or assigned provider can confirm")
		}

		now := time.Now().UTC()
		var updated Job
		err = s.jobs.FindOneAndUpdate(ctx,
			bson.M{"_id": id, "status": StatusInProgress},
			bson.M{
				"$set": bson.M{field: now, "updated_at": now},
				"$min": bson.M{"auto_release_at": now.Add(s.opts.AutoReleaseAfter)},
			},
			options.FindOneAndUpdate().SetReturnDocument(options.After),
		).Decode(&updated)
		if errors.Is(err, mongo.ErrNoDocuments) {
			return errConflict
		}
		if err != nil {
			return fmt.Errorf("confirm job: %w", err)
		}

		if updated.SeekerConfirmedAt != nil && updated.ProviderConfirmedAt != nil {
			err := s.transition(ctx, bson.M{"_id": id}, []Status{StatusInProgress}, StatusCompleted, nil)
			if err != nil {
				return err
			}
			err = s.ledger.Settle(ctx, updated.SeekerID, updated.ProviderID, id, updated.EscrowAmount, s.opts.CommissionBPS)
			if err != nil {
				return err
			}
			updated.Status = StatusCompleted
			if err := s.recordCompletion(ctx, &updated); err != nil {
				return err
			}
		} else if err := s.noteConfirmation(ctx, &updated, userID); err != nil {
			return err
		}
		result = &updated
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// Cancel aborts a job. Escrow returns to the seeker if work has not started, or
// if the provider walks away mid-work. If the seeker cancels mid-work the
// provider may be owed something, so escrow is held for review. Once either
// party has confirmed completion, cancelling is refused: the remaining route is
// a dispute, so nobody can use a cancellation to dodge auto-release.
func (s *Service) Cancel(ctx context.Context, userID, id, reason string) (*Job, error) {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return nil, apperr.BadRequest("reason_required", "a cancellation reason is required")
	}

	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		j, err := s.Get(ctx, userID, id)
		if err != nil {
			return err
		}
		if userID != j.SeekerID && userID != j.ProviderID {
			return apperr.Forbidden("not_a_party", "only the seeker or assigned provider can cancel")
		}
		// A disputed job can only be closed by an admin.
		if j.Status == StatusDisputed || !CanTransition(j.Status, StatusCancelled) {
			return errConflict
		}
		if j.SeekerConfirmedAt != nil || j.ProviderConfirmedAt != nil {
			return apperr.Conflict("completion_confirmed", "completion was already confirmed; raise a dispute instead")
		}

		now := time.Now().UTC()
		midWork := j.Status == StatusInProgress
		hold := midWork && userID == j.SeekerID
		set := bson.M{
			"cancellation":           Cancellation{CancelledBy: userID, Reason: reason, Review: ReviewPending, At: now},
			"escrow_review_required": hold,
		}
		if hold {
			set["escrow_review_due_at"] = now.Add(s.opts.EscrowReviewWindow)
		}
		if err := s.transition(ctx, bson.M{"_id": id}, []Status{j.Status}, StatusCancelled, set); err != nil {
			return err
		}
		if j.Status == StatusAccepted || (midWork && !hold) {
			if err := s.ledger.RefundEscrow(ctx, j.SeekerID, id, j.EscrowAmount); err != nil {
				return err
			}
		}
		if err := s.noteCancelled(ctx, j, userID, hold); err != nil {
			return err
		}
		return s.bids.RejectPending(ctx, id)
	})
	if err != nil {
		return nil, err
	}
	return s.load(ctx, id)
}

// RaiseDispute stops auto-release and hands the job to an admin. Either party
// can do this until both have confirmed, at which point escrow is already settled.
func (s *Service) RaiseDispute(ctx context.Context, userID, id, reason string) (*Job, error) {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return nil, apperr.BadRequest("reason_required", "a dispute reason is required")
	}
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		j, err := s.Get(ctx, userID, id)
		if err != nil {
			return err
		}
		if userID != j.SeekerID && userID != j.ProviderID {
			return apperr.Forbidden("not_a_party", "only the seeker or assigned provider can raise a dispute")
		}
		err = s.transition(ctx, bson.M{"_id": id}, []Status{StatusInProgress}, StatusDisputed, bson.M{
			"dispute": Dispute{RaisedBy: userID, Reason: reason, At: time.Now().UTC()},
		})
		if err != nil {
			return err
		}
		return s.notify.Enqueue(ctx, criticalNote(otherParty(j, userID), j, noteDisputeRaised, "Dispute raised",
			"The other party raised a dispute. The payment is on hold until our team decides."))
	})
	if err != nil {
		return nil, err
	}
	return s.load(ctx, id)
}

// ListEscrowReviews returns jobs waiting on an admin decision, newest first.
func (s *Service) ListEscrowReviews(ctx context.Context) ([]Job, error) {
	return s.list(ctx, bson.M{"$or": bson.A{
		bson.M{"status": StatusDisputed},
		bson.M{"status": StatusCancelled, "escrow_review_required": true},
	}})
}

// ResolveEscrow applies an admin's decision to a disputed job, or to a job the
// seeker cancelled mid-work. A dispute decided wholly for the seeker closes as
// CANCELLED; any payment to the provider closes it as COMPLETED.
func (s *Service) ResolveEscrow(ctx context.Context, adminID, id string, providerPercent int64) (*Job, error) {
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		j, err := s.load(ctx, id)
		if err != nil {
			return err
		}
		switch {
		case j.Status == StatusDisputed:
			to := StatusCompleted
			if providerPercent == 0 {
				to = StatusCancelled
			}
			err := s.transition(ctx, bson.M{"_id": id}, []Status{StatusDisputed}, to, bson.M{
				"escrow_resolution": EscrowResolution{ProviderPercent: providerPercent, ResolvedBy: adminID, At: time.Now().UTC()},
			})
			if err != nil {
				return err
			}
			err = s.ledger.Split(ctx, j.SeekerID, j.ProviderID, id, j.EscrowAmount, providerPercent, s.opts.CommissionBPS)
			if err != nil {
				return err
			}
			if to == StatusCompleted {
				if err := s.users.AddCompletedJob(ctx, j.ProviderID); err != nil {
					return err
				}
			}
			return s.noteResolved(ctx, j, providerPercent)
		case j.Status == StatusCancelled && j.EscrowReviewRequired:
			return s.closeReview(ctx, j, providerPercent, adminID)
		default:
			return apperr.Conflict("no_escrow_review", "this job has no escrow waiting for a decision")
		}
	})
	if err != nil {
		return nil, err
	}
	return s.load(ctx, id)
}

// closeReview splits the escrow of a cancelled job and clears its review flag.
// It must run inside a transaction.
func (s *Service) closeReview(ctx context.Context, j *Job, providerPercent int64, by string) error {
	now := time.Now().UTC()
	res, err := s.jobs.UpdateOne(ctx,
		bson.M{"_id": j.ID, "status": StatusCancelled, "escrow_review_required": true},
		bson.M{"$set": bson.M{
			"escrow_review_required": false,
			"escrow_resolution":      EscrowResolution{ProviderPercent: providerPercent, ResolvedBy: by, At: now},
			"updated_at":             now,
		}},
	)
	if err != nil {
		return fmt.Errorf("close escrow review: %w", err)
	}
	if res.MatchedCount == 0 {
		return errConflict
	}
	err = s.ledger.Split(ctx, j.SeekerID, j.ProviderID, j.ID, j.EscrowAmount, providerPercent, s.opts.CommissionBPS)
	if err != nil {
		return err
	}
	return s.noteResolved(ctx, j, providerPercent)
}

// AdvanceExpired applies every time-based rule: bid-window escalation, unpicked
// bids, escrow auto-release, its reminder and overdue escrow reviews. Conditional
// updates make it safe to run on several instances.
func (s *Service) AdvanceExpired(ctx context.Context, now time.Time) error {
	return errors.Join(
		s.advanceBidWindows(ctx, now),
		s.expireUnpicked(ctx, now),
		s.autoRelease(ctx, now),
		s.remindAutoRelease(ctx, now),
		s.closeOverdueReviews(ctx, now),
	)
}

// eachJob runs fn for every job matching filter. A failure on one job does not
// stop the others, and losing a race to another instance is not a failure.
func (s *Service) eachJob(ctx context.Context, filter bson.M, fn func(ctx context.Context, j *Job) error) error {
	rows, err := s.list(ctx, filter)
	if err != nil {
		return err
	}
	var errs []error
	for i := range rows {
		err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error { return fn(ctx, &rows[i]) })
		if err != nil && !errors.Is(err, errConflict) {
			errs = append(errs, fmt.Errorf("job %s: %w", rows[i].ID, err))
		}
	}
	return errors.Join(errs...)
}

// expireUnpicked closes open jobs whose seeker never chose a bid.
func (s *Service) expireUnpicked(ctx context.Context, now time.Time) error {
	due := bson.M{"$lte": now}
	filter := bson.M{"status": bson.M{"$in": OpenStatuses}, "selection_deadline": due}
	return s.eachJob(ctx, filter, func(ctx context.Context, j *Job) error {
		err := s.transition(ctx, bson.M{"_id": j.ID, "selection_deadline": due}, OpenStatuses, StatusExpired, nil)
		if err != nil {
			return err
		}
		err = s.notify.Enqueue(ctx, note(j.SeekerID, j, noteJobExpired, "Job expired",
			"You didn't choose a bid in time, so your job has closed. No money was taken. You can post it again."))
		if err != nil {
			return err
		}
		return s.bids.RejectPending(ctx, j.ID)
	})
}

// autoRelease pays out jobs where one party confirmed and the other stayed
// silent. A dispute moves the job out of IN_PROGRESS, so it is never matched.
func (s *Service) autoRelease(ctx context.Context, now time.Time) error {
	filter := bson.M{"status": StatusInProgress, "auto_release_at": bson.M{"$lte": now}}
	return s.eachJob(ctx, filter, func(ctx context.Context, j *Job) error {
		err := s.transition(ctx, bson.M{"_id": j.ID}, []Status{StatusInProgress}, StatusCompleted, nil)
		if err != nil {
			return err
		}
		err = s.ledger.Settle(ctx, j.SeekerID, j.ProviderID, j.ID, j.EscrowAmount, s.opts.CommissionBPS)
		if err != nil {
			return err
		}
		return s.recordCompletion(ctx, j)
	})
}

// recordCompletion updates the provider's record and tells both parties. It must
// run inside the transaction that completes the job.
func (s *Service) recordCompletion(ctx context.Context, j *Job) error {
	if err := s.users.AddCompletedJob(ctx, j.ProviderID); err != nil {
		return err
	}
	return s.noteCompleted(ctx, j)
}

// remindAutoRelease warns a seeker who has not responded that the payment is
// about to go. Providers get no reminder, since release only benefits them.
func (s *Service) remindAutoRelease(ctx context.Context, now time.Time) error {
	filter := bson.M{
		"status":                   StatusInProgress,
		"seeker_confirmed_at":      bson.M{"$exists": false},
		"auto_release_at":          bson.M{"$lte": now.Add(autoReleaseReminderLead)},
		"release_reminder_sent_at": bson.M{"$exists": false},
	}
	return s.eachJob(ctx, filter, func(ctx context.Context, j *Job) error {
		res, err := s.jobs.UpdateOne(ctx,
			bson.M{"_id": j.ID, "status": StatusInProgress, "release_reminder_sent_at": bson.M{"$exists": false}},
			bson.M{"$set": bson.M{"release_reminder_sent_at": now}},
		)
		if err != nil {
			return fmt.Errorf("mark reminder: %w", err)
		}
		if res.MatchedCount == 0 {
			return errConflict
		}
		return s.notify.Enqueue(ctx, criticalNote(j.SeekerID, j, noteAutoReleaseWarned, "Payment releasing soon",
			"Your payment will be released to the provider within 24 hours. Raise a dispute now if the job isn't finished."))
	})
}

// closeOverdueReviews applies the default split where no admin decided in time.
func (s *Service) closeOverdueReviews(ctx context.Context, now time.Time) error {
	filter := bson.M{
		"status":                 StatusCancelled,
		"escrow_review_required": true,
		"escrow_review_due_at":   bson.M{"$lte": now},
	}
	return s.eachJob(ctx, filter, func(ctx context.Context, j *Job) error {
		return s.closeReview(ctx, j, defaultProviderPercent, resolvedBySystem)
	})
}

// advanceBidWindows moves jobs whose bid window ended with zero bids to the next stage.
func (s *Service) advanceBidWindows(ctx context.Context, now time.Time) error {
	expired := func(st Status) bson.M {
		return bson.M{"status": st, "bid_count": 0, "window_ends_at": bson.M{"$lte": now}}
	}

	// Escalation pushes each job's window forward, so a job cannot pass through
	// both stages in one run.
	return errors.Join(
		s.eachJob(ctx, expired(StatusBroadcasting), func(ctx context.Context, j *Job) error {
			return s.escalate(ctx, j, now)
		}),
		s.eachJob(ctx, expired(StatusEscalating), func(ctx context.Context, j *Job) error {
			err := s.transition(ctx, bson.M{"_id": j.ID, "bid_count": 0}, []Status{StatusEscalating}, StatusManualFallback, nil)
			if err != nil {
				return err
			}
			return s.notify.Enqueue(ctx, note(j.SeekerID, j, noteJobFallback, "No bids yet",
				"No providers have bid on your job. Browse the directory to find one yourself."))
		}),
	)
}

func (s *Service) escalate(ctx context.Context, j *Job, now time.Time) error {
	providers, err := s.users.ProvidersNear(ctx, j.JobLocation, s.opts.EscalationMeters, j.CategoryID, j.SeekerID, user.AvailableAt(j.PreferredDate, j.PreferredSlot))
	if err != nil {
		return err
	}
	added := []string{}
	for _, id := range providers {
		if !slices.Contains(j.EligibleProviderIDs, id) {
			added = append(added, id)
		}
	}
	window := now.Add(s.opts.BidWindow)
	err = s.transition(ctx, bson.M{"_id": j.ID, "bid_count": 0}, []Status{StatusBroadcasting}, StatusEscalating, bson.M{
		"eligible_provider_ids": append(j.EligibleProviderIDs, added...),
		"window_ends_at":        window,
	})
	if err != nil {
		return err
	}
	return s.noteBroadcast(ctx, j, added)
}

// RunTimeouts calls AdvanceExpired on an interval until ctx is cancelled.
func (s *Service) RunTimeouts(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			if err := s.AdvanceExpired(ctx, now.UTC()); err != nil {
				slog.Error("advance expired jobs", "err", err)
			}
		}
	}
}
