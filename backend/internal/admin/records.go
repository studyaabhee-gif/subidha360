package admin

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/catalog"
	"subidha360/backend/internal/job"
	"subidha360/backend/internal/payout"
	"subidha360/backend/internal/provider"
	"subidha360/backend/internal/user"
	"subidha360/backend/internal/wallet"
)

// UserRow is one line of the people list.
type UserRow struct {
	ID         string           `json:"id"`
	Phone      string           `json:"phone"`
	Name       string           `json:"name"`
	IsProvider bool             `json:"is_provider"`
	IsVerified bool             `json:"is_verified"`
	IsAdmin    bool             `json:"is_admin"`
	Suspension *user.Suspension `json:"suspension,omitempty"`
	// Check is the identity check status: "", PENDING, APPROVED or REJECTED.
	Check         string    `json:"check"`
	Online        bool      `json:"online"`
	Rating        float64   `json:"rating"`
	ReviewCount   int       `json:"review_count"`
	JobsCompleted int       `json:"jobs_completed"`
	CreatedAt     time.Time `json:"created_at"`
}

func userRow(u *user.User) UserRow {
	r := UserRow{
		ID:            u.ID,
		Phone:         u.PhoneNumber,
		Name:          u.DisplayName,
		IsProvider:    u.HasProviderProfile,
		IsVerified:    u.IsVerified,
		IsAdmin:       u.IsAdmin,
		Suspension:    u.Suspension,
		ReviewCount:   u.RatingCount,
		JobsCompleted: u.JobsCompleted,
		CreatedAt:     u.CreatedAt,
	}
	if u.RatingCount > 0 {
		r.Rating = float64(u.RatingSum) / float64(u.RatingCount)
	}
	if u.Verification != nil {
		r.Check = u.Verification.Status
	}
	if u.ProviderProfile != nil {
		r.Online = u.ProviderProfile.IsOnline
	}
	return r
}

// User list filters.
const (
	FilterAll        = ""
	FilterSeekers    = "seekers"
	FilterProviders  = "providers"
	FilterUnverified = "unverified"
	FilterSuspended  = "suspended"
	FilterAdmins     = "admins"
	// FilterChecks are providers waiting for an identity check.
	FilterChecks = "checks"
)

// search builds a case-insensitive match on any of the fields. User text is
// quoted, so it can never act as a pattern.
func search(q string, fields ...string) bson.M {
	pattern := bson.Regex{Pattern: regexp.QuoteMeta(q), Options: "i"}
	or := bson.A{}
	for _, f := range fields {
		or = append(or, bson.M{f: pattern})
	}
	return bson.M{"$or": or}
}

// Users lists people, newest first.
func (s *Service) Users(ctx context.Context, q, filter string, page int) ([]UserRow, bool, error) {
	conds := bson.A{}
	switch filter {
	case FilterAll:
	case FilterSeekers:
		conds = append(conds, bson.M{"has_provider_profile": false})
	case FilterProviders:
		conds = append(conds, bson.M{"has_provider_profile": true})
	case FilterUnverified:
		conds = append(conds, bson.M{"has_provider_profile": true, "is_verified": bson.M{"$ne": true}})
	case FilterSuspended:
		conds = append(conds, bson.M{"suspension": bson.M{"$exists": true}})
	case FilterAdmins:
		conds = append(conds, bson.M{"is_admin": true})
	case FilterChecks:
		conds = append(conds, bson.M{"verification.status": user.CheckPending})
	default:
		return nil, false, apperr.BadRequest("invalid_filter", "unknown filter")
	}
	if q = strings.TrimSpace(q); q != "" {
		m := search(q, "display_name", "phone_number")
		m["$or"] = append(m["$or"].(bson.A), bson.M{"_id": q})
		conds = append(conds, m)
	}
	where := bson.M{}
	if len(conds) > 0 {
		where["$and"] = conds
	}
	var users []user.User
	more, err := findPage(ctx, s.users, where, bson.D{{Key: "created_at", Value: -1}}, page, &users)
	if err != nil {
		return nil, false, err
	}
	rows := make([]UserRow, len(users))
	for i := range users {
		rows[i] = userRow(&users[i])
	}
	return rows, more, nil
}

// UserDetail is everything an admin needs to judge an account.
type UserDetail struct {
	User            UserRow               `json:"user"`
	Profile         *user.ProviderProfile `json:"provider_profile,omitempty"`
	BalancePaisa    int64                 `json:"balance_paisa"`
	ActiveJobs      int64                 `json:"active_jobs"`
	Jobs            []JobRow              `json:"jobs"`
	Transactions    []EntryRow            `json:"transactions"`
	ReviewsReceived []ReviewRow           `json:"reviews_received"`
	Verification    *user.Verification    `json:"verification,omitempty"`
	Documents       []provider.Document   `json:"documents"`
	Withdrawals     []payout.Withdrawal   `json:"withdrawals"`
	Availability    *user.Availability    `json:"availability,omitempty"`
	Risk            *Risk                 `json:"risk"`
	Flags           []FlagRow             `json:"flags"`
	Actions         []Action              `json:"actions"`
}

// ReviewRow is a review with its job, for moderation.
type ReviewRow struct {
	JobID     string    `bson:"_id" json:"job_id"`
	SeekerID  string    `bson:"seeker_id" json:"seeker_id"`
	Rating    int       `bson:"rating" json:"rating"`
	Tags      []string  `bson:"tags" json:"tags"`
	Comment   string    `bson:"comment,omitempty" json:"comment,omitempty"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
}

var activeStatuses = []job.Status{job.StatusAccepted, job.StatusInProgress, job.StatusDisputed}

// detailRows is how many recent records the detail pages show.
const detailRows = 20

func (s *Service) User(ctx context.Context, id string) (*UserDetail, error) {
	u, err := s.userRepo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	d := &UserDetail{User: userRow(u), Profile: u.ProviderProfile, Verification: u.Verification, Availability: u.Availability}
	if d.Documents, err = s.provider.Documents(ctx, id); err != nil {
		return nil, err
	}
	if d.Withdrawals, err = s.payouts.List(ctx, id, "", detailRows); err != nil {
		return nil, err
	}
	if d.Risk, err = s.risk(ctx, id); err != nil {
		return nil, err
	}
	flags, err := s.safety.List(ctx, "", id, 0, detailRows)
	if err != nil {
		return nil, err
	}
	if d.Flags, err = s.flagRows(ctx, flags); err != nil {
		return nil, err
	}

	var account struct {
		Balance int64 `bson:"balance"`
	}
	if err := s.accounts.FindOne(ctx, bson.M{"_id": wallet.UserAccount(id)}).Decode(&account); err == nil {
		d.BalancePaisa = account.Balance
	}

	involved := bson.M{"$or": bson.A{bson.M{"seeker_id": id}, bson.M{"provider_id": id}}}
	d.ActiveJobs, err = s.jobs.CountDocuments(ctx, bson.M{"$and": bson.A{involved, bson.M{"status": bson.M{"$in": activeStatuses}}}})
	if err != nil {
		return nil, fmt.Errorf("count active jobs: %w", err)
	}
	if d.Jobs, _, err = s.jobRows(ctx, involved, 1, detailRows); err != nil {
		return nil, err
	}
	if d.Transactions, _, err = s.entryRows(ctx, bson.M{"account_id": wallet.UserAccount(id)}, 1, detailRows); err != nil {
		return nil, err
	}

	cur, err := s.reviews.Find(ctx, bson.M{"provider_id": id},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(detailRows))
	if err != nil {
		return nil, fmt.Errorf("find reviews: %w", err)
	}
	d.ReviewsReceived = []ReviewRow{}
	if err := cur.All(ctx, &d.ReviewsReceived); err != nil {
		return nil, fmt.Errorf("read reviews: %w", err)
	}

	if d.Actions, _, err = s.Actions(ctx, id, 1); err != nil {
		return nil, err
	}
	return d, nil
}

// JobRow is one line of the jobs list.
type JobRow struct {
	ID          string     `json:"id"`
	Status      job.Status `json:"status"`
	CategoryID  int        `json:"category_id"`
	Category    string     `json:"category"`
	ServiceID   string     `json:"service_id,omitempty"`
	Description string     `json:"description"`
	Address     string     `json:"address"`
	Seeker      Person     `json:"seeker"`
	Provider    *Person    `json:"provider,omitempty"`
	EscrowPaisa int64      `json:"escrow_amount_paisa"`
	BidCount    int        `json:"bid_count"`
	Disputed    bool       `json:"disputed"`
	NeedsReview bool       `json:"needs_review"`
	ClaimOpen   bool       `json:"claim_open"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	CancelledAt *time.Time `json:"cancelled_at,omitempty"`
}

// Job list filters beyond the plain statuses.
const (
	// JobsNeedingAction are the jobs waiting on an admin.
	JobsNeedingAction = "attention"
	// JobsActive are jobs with a provider assigned and money held.
	JobsActive = "active"
	// JobsOpen are still collecting bids.
	JobsOpen = "open"
)

func needsActionFilter() bson.M {
	return bson.M{"$or": bson.A{
		bson.M{"status": job.StatusDisputed},
		bson.M{"status": job.StatusCancelled, "escrow_review_required": true},
		bson.M{"warranty_claim.status": job.ClaimOpen},
		bson.M{"status": job.StatusManualFallback},
	}}
}

func (s *Service) Jobs(ctx context.Context, q, status string, page int) ([]JobRow, bool, error) {
	conds := bson.A{}
	switch status {
	case "":
	case JobsNeedingAction:
		conds = append(conds, needsActionFilter())
	case JobsActive:
		conds = append(conds, bson.M{"status": bson.M{"$in": activeStatuses}})
	case JobsOpen:
		conds = append(conds, bson.M{"status": bson.M{"$in": job.OpenStatuses}})
	default:
		conds = append(conds, bson.M{"status": status})
	}
	if q = strings.TrimSpace(q); q != "" {
		m := search(q, "description", "address")
		m["$or"] = append(m["$or"].(bson.A), bson.M{"_id": q}, bson.M{"seeker_id": q}, bson.M{"provider_id": q})
		conds = append(conds, m)
	}
	where := bson.M{}
	if len(conds) > 0 {
		where["$and"] = conds
	}
	return s.jobRows(ctx, where, page, pageSize)
}

func (s *Service) jobRows(ctx context.Context, where bson.M, page, limit int) ([]JobRow, bool, error) {
	var jobs []job.Job
	var more bool
	var err error
	if limit == pageSize {
		more, err = findPage(ctx, s.jobs, where, bson.D{{Key: "created_at", Value: -1}}, page, &jobs)
	} else {
		cur, ferr := s.jobs.Find(ctx, where, options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(int64(limit)))
		if ferr != nil {
			return nil, false, fmt.Errorf("find jobs: %w", ferr)
		}
		err = cur.All(ctx, &jobs)
	}
	if err != nil {
		return nil, false, err
	}
	ids := make([]string, 0, len(jobs)*2)
	for i := range jobs {
		ids = append(ids, jobs[i].SeekerID, jobs[i].ProviderID)
	}
	people, err := s.names(ctx, ids)
	if err != nil {
		return nil, false, err
	}
	rows := make([]JobRow, len(jobs))
	for i := range jobs {
		rows[i] = jobRow(&jobs[i], people)
	}
	return rows, more, nil
}

func jobRow(j *job.Job, people map[string]Person) JobRow {
	r := JobRow{
		ID:          j.ID,
		Status:      j.Status,
		CategoryID:  j.CategoryID,
		Category:    catalog.CategoryName(j.CategoryID),
		ServiceID:   j.ServiceID,
		Description: j.Description,
		Address:     j.Address,
		Seeker:      people[j.SeekerID],
		EscrowPaisa: j.EscrowAmount,
		BidCount:    j.BidCount,
		Disputed:    j.Status == job.StatusDisputed,
		NeedsReview: j.EscrowReviewRequired,
		ClaimOpen:   j.WarrantyClaim != nil && j.WarrantyClaim.Status == job.ClaimOpen,
		CreatedAt:   j.CreatedAt,
		UpdatedAt:   j.UpdatedAt,
		CompletedAt: j.CompletedAt,
		CancelledAt: j.CancelledAt,
	}
	if r.Seeker.ID == "" {
		r.Seeker = Person{ID: j.SeekerID}
	}
	if j.ProviderID != "" {
		p, ok := people[j.ProviderID]
		if !ok {
			p = Person{ID: j.ProviderID}
		}
		r.Provider = &p
	}
	return r
}

// JobDetail is the whole record of a job, for deciding disputes and claims.
type JobDetail struct {
	Job      *job.Job     `json:"job"`
	Row      JobRow       `json:"summary"`
	Bids     []BidRow     `json:"bids"`
	Messages []MessageRow `json:"messages"`
	Ledger   []EntryRow   `json:"ledger"`
	Review   *ReviewRow   `json:"review,omitempty"`
	Actions  []Action     `json:"actions"`
}

type BidRow struct {
	ID            string    `bson:"_id" json:"id"`
	ProviderID    string    `bson:"provider_id" json:"provider_id"`
	Provider      Person    `bson:"-" json:"provider"`
	AmountPaisa   int64     `bson:"bid_amount" json:"amount_paisa"`
	Status        string    `bson:"status" json:"status"`
	PartsIncluded bool      `bson:"parts_included" json:"parts_included"`
	Note          string    `bson:"note,omitempty" json:"note,omitempty"`
	CreatedAt     time.Time `bson:"created_at" json:"created_at"`
}

type MessageRow struct {
	ID        string    `bson:"_id" json:"id"`
	SenderID  string    `bson:"sender_id" json:"sender_id"`
	Body      string    `bson:"body" json:"body"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
}

// maxChatRows caps how much of a conversation one page loads.
const maxChatRows = 500

func (s *Service) Job(ctx context.Context, id string) (*JobDetail, error) {
	j, err := s.jobSvc.Load(ctx, id)
	if err != nil {
		return nil, err
	}
	d := &JobDetail{Job: j, Bids: []BidRow{}, Messages: []MessageRow{}}

	cur, err := s.bids.Find(ctx, bson.M{"job_id": id}, options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}}))
	if err != nil {
		return nil, fmt.Errorf("find bids: %w", err)
	}
	if err := cur.All(ctx, &d.Bids); err != nil {
		return nil, fmt.Errorf("read bids: %w", err)
	}
	cur, err = s.messages.Find(ctx, bson.M{"job_id": id},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}}).SetLimit(maxChatRows))
	if err != nil {
		return nil, fmt.Errorf("find messages: %w", err)
	}
	if err := cur.All(ctx, &d.Messages); err != nil {
		return nil, fmt.Errorf("read messages: %w", err)
	}

	ids := []string{j.SeekerID, j.ProviderID}
	for _, b := range d.Bids {
		ids = append(ids, b.ProviderID)
	}
	people, err := s.names(ctx, ids)
	if err != nil {
		return nil, err
	}
	for i := range d.Bids {
		d.Bids[i].Provider = people[d.Bids[i].ProviderID]
		d.Bids[i].Provider.ID = d.Bids[i].ProviderID
	}
	d.Row = jobRow(j, people)

	if d.Ledger, _, err = s.entryRows(ctx, bson.M{"reference_job_id": id}, 1, pageSize); err != nil {
		return nil, err
	}
	var rv ReviewRow
	if err := s.reviews.FindOne(ctx, bson.M{"_id": id}).Decode(&rv); err == nil {
		d.Review = &rv
	}
	if d.Actions, _, err = s.Actions(ctx, id, 1); err != nil {
		return nil, err
	}
	return d, nil
}

// EntryRow is one ledger leg, with the account spelled out.
type EntryRow struct {
	ID        string    `bson:"_id" json:"id"`
	GroupKey  string    `bson:"group_key" json:"group"`
	AccountID string    `bson:"account_id" json:"account"`
	UserID    string    `bson:"user_id,omitempty" json:"user_id,omitempty"`
	UserName  string    `bson:"-" json:"user_name,omitempty"`
	Amount    int64     `bson:"amount" json:"amount_paisa"`
	Type      string    `bson:"transaction_type" json:"type"`
	JobID     string    `bson:"reference_job_id,omitempty" json:"job_id,omitempty"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
}

var entryTypes = map[string]bool{
	wallet.TypeTopUp: true, wallet.TypeEscrowHold: true, wallet.TypeEscrowRefund: true,
	wallet.TypePayout: true, wallet.TypeCommission: true,
	wallet.TypeWithdrawal: true, wallet.TypeWithdrawalPaid: true, wallet.TypeWithdrawalReturned: true,
}

// Payments lists ledger legs, newest first.
func (s *Service) Payments(ctx context.Context, kind, q string, page int) ([]EntryRow, bool, error) {
	where := bson.M{}
	if kind != "" {
		if !entryTypes[kind] {
			return nil, false, apperr.BadRequest("invalid_type", "unknown transaction type")
		}
		where["transaction_type"] = kind
	}
	if q = strings.TrimSpace(q); q != "" {
		where["$or"] = bson.A{bson.M{"user_id": q}, bson.M{"reference_job_id": q}, bson.M{"account_id": q}}
	}
	return s.entryRows(ctx, where, page, pageSize)
}

func (s *Service) entryRows(ctx context.Context, where bson.M, page, limit int) ([]EntryRow, bool, error) {
	var rows []EntryRow
	var more bool
	var err error
	sort := bson.D{{Key: "created_at", Value: -1}, {Key: "group_key", Value: 1}, {Key: "leg", Value: 1}}
	if limit == pageSize {
		more, err = findPage(ctx, s.entries, where, sort, page, &rows)
	} else {
		cur, ferr := s.entries.Find(ctx, where, options.Find().SetSort(sort).SetLimit(int64(limit)))
		if ferr != nil {
			return nil, false, fmt.Errorf("find entries: %w", ferr)
		}
		err = cur.All(ctx, &rows)
	}
	if err != nil {
		return nil, false, err
	}
	if rows == nil {
		rows = []EntryRow{}
	}
	ids := make([]string, len(rows))
	for i := range rows {
		ids[i] = rows[i].UserID
	}
	people, err := s.names(ctx, ids)
	if err != nil {
		return nil, false, err
	}
	for i := range rows {
		rows[i].UserName = people[rows[i].UserID].Name
	}
	return rows, more, nil
}
