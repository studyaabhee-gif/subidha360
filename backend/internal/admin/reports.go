package admin

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/catalog"
	"subidha360/backend/internal/job"
	"subidha360/backend/internal/payout"
	"subidha360/backend/internal/user"
	"subidha360/backend/internal/wallet"
)

// Reports count days in Nepal time, which has no daylight saving.
var nepal = time.FixedZone("NPT", 5*3600+45*60)

const (
	nepalOffset   = "+0545"
	dayLayout     = "2006-01-02"
	maxReportDays = 366
	topProviders  = 10
)

// Day is one day of activity. Money comes from the ledger, so it matches the
// books to the paisa.
type Day struct {
	Date      string `json:"date"`
	Posted    int64  `json:"jobs_posted"`
	Completed int64  `json:"jobs_completed"`
	Cancelled int64  `json:"jobs_cancelled"`
	NewUsers  int64  `json:"new_users"`
	// GMV is what customers paid for finished work: provider payouts plus
	// commission.
	GMV        int64 `json:"gmv_paisa"`
	Commission int64 `json:"commission_paisa"`
	Payouts    int64 `json:"payouts_paisa"`
	Refunds    int64 `json:"refunds_paisa"`
	TopUps     int64 `json:"top_ups_paisa"`
	// Withdrawals is money sent out to providers' banks and eWallets.
	Withdrawals int64 `json:"withdrawals_paisa"`
}

func (d *Day) add(o Day) {
	d.Posted += o.Posted
	d.Completed += o.Completed
	d.Cancelled += o.Cancelled
	d.NewUsers += o.NewUsers
	d.GMV += o.GMV
	d.Commission += o.Commission
	d.Payouts += o.Payouts
	d.Refunds += o.Refunds
	d.TopUps += o.TopUps
	d.Withdrawals += o.Withdrawals
}

type CategoryRow struct {
	CategoryID int    `json:"category_id"`
	Name       string `json:"name"`
	Posted     int64  `json:"jobs_posted"`
	Completed  int64  `json:"jobs_completed"`
	Cancelled  int64  `json:"jobs_cancelled"`
	// Value is the agreed price of jobs completed in the period.
	Value int64 `json:"completed_value_paisa"`
}

type ProviderRow struct {
	Person
	Completed int64   `json:"jobs_completed"`
	Value     int64   `json:"completed_value_paisa"`
	Rating    float64 `json:"rating"`
	Verified  bool    `json:"verified"`
}

type Report struct {
	From         string        `json:"from"`
	To           string        `json:"to"`
	Totals       Day           `json:"totals"`
	Days         []Day         `json:"days"`
	Categories   []CategoryRow `json:"categories"`
	TopProviders []ProviderRow `json:"top_providers"`
}

// ParseRange reads an inclusive date range in Nepal time. Empty values mean
// the last 30 days.
func ParseRange(from, to string, now time.Time) (time.Time, time.Time, error) {
	today := now.In(nepal)
	end := time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, nepal)
	start := end.AddDate(0, 0, -29)
	var err error
	if to != "" {
		if end, err = time.ParseInLocation(dayLayout, to, nepal); err != nil {
			return start, end, apperr.BadRequest("invalid_date", "dates must look like 2026-11-13")
		}
	}
	if from != "" {
		if start, err = time.ParseInLocation(dayLayout, from, nepal); err != nil {
			return start, end, apperr.BadRequest("invalid_date", "dates must look like 2026-11-13")
		}
	} else if to != "" {
		start = end.AddDate(0, 0, -29)
	}
	if end.Before(start) {
		return start, end, apperr.BadRequest("invalid_range", "the start date is after the end date")
	}
	if end.Sub(start) > maxReportDays*24*time.Hour {
		return start, end, apperr.BadRequest("range_too_long", "pick a range of a year or less")
	}
	return start, end, nil
}

func dayKey(field string) bson.M {
	return bson.M{"$dateToString": bson.M{"format": "%Y-%m-%d", "date": "$" + field, "timezone": nepalOffset}}
}

type keyCount struct {
	Key   string `bson:"_id"`
	Count int64  `bson:"n"`
	Sum   int64  `bson:"sum"`
}

// countByDay groups documents whose field falls in [start, end) by Nepal day.
func countByDay(ctx context.Context, c *mongo.Collection, field string, start, end time.Time, extra bson.M) (map[string]keyCount, error) {
	match := bson.M{field: bson.M{"$gte": start, "$lt": end}}
	for k, v := range extra {
		match[k] = v
	}
	cur, err := c.Aggregate(ctx, bson.A{
		bson.M{"$match": match},
		bson.M{"$group": bson.M{"_id": dayKey(field), "n": bson.M{"$sum": 1}}},
	})
	if err != nil {
		return nil, fmt.Errorf("group %s by day: %w", c.Name(), err)
	}
	var rows []keyCount
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read %s by day: %w", c.Name(), err)
	}
	out := make(map[string]keyCount, len(rows))
	for _, r := range rows {
		out[r.Key] = r
	}
	return out, nil
}

// Report builds activity for an inclusive range of Nepal days.
func (s *Service) Report(ctx context.Context, start, end time.Time) (*Report, error) {
	stop := end.AddDate(0, 0, 1)
	posted, err := countByDay(ctx, s.jobs, "created_at", start, stop, nil)
	if err != nil {
		return nil, err
	}
	completed, err := countByDay(ctx, s.jobs, "completed_at", start, stop, nil)
	if err != nil {
		return nil, err
	}
	cancelled, err := countByDay(ctx, s.jobs, "cancelled_at", start, stop, nil)
	if err != nil {
		return nil, err
	}
	joined, err := countByDay(ctx, s.users, "created_at", start, stop, nil)
	if err != nil {
		return nil, err
	}

	// Credits only: each posting also has a debit leg, which would cancel out.
	cur, err := s.entries.Aggregate(ctx, bson.A{
		bson.M{"$match": bson.M{"created_at": bson.M{"$gte": start, "$lt": stop}, "amount": bson.M{"$gt": 0}}},
		bson.M{"$group": bson.M{
			"_id": bson.M{"day": dayKey("created_at"), "type": "$transaction_type"},
			"sum": bson.M{"$sum": "$amount"},
		}},
	})
	if err != nil {
		return nil, fmt.Errorf("group ledger by day: %w", err)
	}
	var money []struct {
		Key struct {
			Day  string `bson:"day"`
			Type string `bson:"type"`
		} `bson:"_id"`
		Sum int64 `bson:"sum"`
	}
	if err := cur.All(ctx, &money); err != nil {
		return nil, fmt.Errorf("read ledger by day: %w", err)
	}

	byDay := map[string]*Day{}
	r := &Report{From: start.Format(dayLayout), To: end.Format(dayLayout), Days: []Day{}}
	for d := start; !d.After(end); d = d.AddDate(0, 0, 1) {
		key := d.Format(dayLayout)
		r.Days = append(r.Days, Day{
			Date:      key,
			Posted:    posted[key].Count,
			Completed: completed[key].Count,
			Cancelled: cancelled[key].Count,
			NewUsers:  joined[key].Count,
		})
	}
	for i := range r.Days {
		byDay[r.Days[i].Date] = &r.Days[i]
	}
	for _, m := range money {
		d := byDay[m.Key.Day]
		if d == nil {
			continue
		}
		switch m.Key.Type {
		case wallet.TypePayout:
			d.Payouts += m.Sum
		case wallet.TypeCommission:
			d.Commission += m.Sum
		case wallet.TypeEscrowRefund:
			d.Refunds += m.Sum
		case wallet.TypeTopUp:
			d.TopUps += m.Sum
		case wallet.TypeWithdrawalPaid:
			d.Withdrawals += m.Sum
		}
	}
	for i := range r.Days {
		r.Days[i].GMV = r.Days[i].Payouts + r.Days[i].Commission
		r.Totals.add(r.Days[i])
	}

	if r.Categories, err = s.categoryReport(ctx, start, stop); err != nil {
		return nil, err
	}
	if r.TopProviders, err = s.providerReport(ctx, start, stop); err != nil {
		return nil, err
	}
	return r, nil
}

func (s *Service) groupJobs(ctx context.Context, field string, start, stop time.Time, by string) (map[any]keyCount, error) {
	cur, err := s.jobs.Aggregate(ctx, bson.A{
		bson.M{"$match": bson.M{field: bson.M{"$gte": start, "$lt": stop}}},
		bson.M{"$group": bson.M{"_id": "$" + by, "n": bson.M{"$sum": 1}, "sum": bson.M{"$sum": "$escrow_amount"}}},
	})
	if err != nil {
		return nil, fmt.Errorf("group jobs by %s: %w", by, err)
	}
	var rows []struct {
		Key   any   `bson:"_id"`
		Count int64 `bson:"n"`
		Sum   int64 `bson:"sum"`
	}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read jobs by %s: %w", by, err)
	}
	out := make(map[any]keyCount, len(rows))
	for _, r := range rows {
		key := r.Key
		// Category IDs come back as int32 or int64 depending on how they were
		// written, so normalise them.
		switch v := key.(type) {
		case int32:
			key = int(v)
		case int64:
			key = int(v)
		}
		out[key] = keyCount{Count: r.Count, Sum: r.Sum}
	}
	return out, nil
}

func (s *Service) categoryReport(ctx context.Context, start, stop time.Time) ([]CategoryRow, error) {
	posted, err := s.groupJobs(ctx, "created_at", start, stop, "category_id")
	if err != nil {
		return nil, err
	}
	completed, err := s.groupJobs(ctx, "completed_at", start, stop, "category_id")
	if err != nil {
		return nil, err
	}
	cancelled, err := s.groupJobs(ctx, "cancelled_at", start, stop, "category_id")
	if err != nil {
		return nil, err
	}
	rows := []CategoryRow{}
	for _, c := range catalog.All() {
		rows = append(rows, CategoryRow{
			CategoryID: c.ID,
			Name:       c.Name,
			Posted:     posted[c.ID].Count,
			Completed:  completed[c.ID].Count,
			Cancelled:  cancelled[c.ID].Count,
			Value:      completed[c.ID].Sum,
		})
	}
	sort.SliceStable(rows, func(i, j int) bool { return rows[i].Posted > rows[j].Posted })
	return rows, nil
}

func (s *Service) providerReport(ctx context.Context, start, stop time.Time) ([]ProviderRow, error) {
	done, err := s.groupJobs(ctx, "completed_at", start, stop, "provider_id")
	if err != nil {
		return nil, err
	}
	ids := make([]string, 0, len(done))
	for k := range done {
		if id, ok := k.(string); ok && id != "" {
			ids = append(ids, id)
		}
	}
	sort.Slice(ids, func(i, j int) bool {
		a, b := done[ids[i]], done[ids[j]]
		if a.Count != b.Count {
			return a.Count > b.Count
		}
		return a.Sum > b.Sum
	})
	if len(ids) > topProviders {
		ids = ids[:topProviders]
	}
	profiles, err := s.userRepo.PublicProfiles(ctx, ids)
	if err != nil {
		return nil, err
	}
	people, err := s.names(ctx, ids)
	if err != nil {
		return nil, err
	}
	rows := make([]ProviderRow, 0, len(ids))
	for _, id := range ids {
		p := people[id]
		p.ID = id
		rows = append(rows, ProviderRow{
			Person:    p,
			Completed: done[id].Count,
			Value:     done[id].Sum,
			Rating:    profiles[id].Rating,
			Verified:  profiles[id].Verified,
		})
	}
	return rows, nil
}

// Money is where every paisa sits right now, plus a check that the books add up.
type Money struct {
	CommissionPaisa int64 `json:"commission_paisa"`
	EscrowHeldPaisa int64 `json:"escrow_held_paisa"`
	WalletsPaisa    int64 `json:"wallets_paisa"`
	// WithdrawalsWaitingPaisa has left wallets but not yet been sent.
	WithdrawalsWaitingPaisa int64 `json:"withdrawals_waiting_paisa"`
	// ToppedUpPaisa is all money ever added through the payment gateway, less
	// anything paid back out through it.
	ToppedUpPaisa int64 `json:"topped_up_paisa"`
	// BooksBalance must be zero: every posting sums to zero.
	BooksBalance int64 `json:"books_balance_paisa"`
	// Mismatched lists accounts whose balance differs from their ledger, and
	// postings that do not sum to zero. Both must be empty.
	Mismatched       []string `json:"mismatched_accounts"`
	UnbalancedGroups []string `json:"unbalanced_postings"`
	Healthy          bool     `json:"healthy"`
}

const maxProblems = 20

func (s *Service) Money(ctx context.Context) (*Money, error) {
	cur, err := s.accounts.Aggregate(ctx, bson.A{
		bson.M{"$group": bson.M{
			"_id": bson.M{"$arrayElemAt": bson.A{bson.M{"$split": bson.A{"$_id", ":"}}, 0}},
			"sum": bson.M{"$sum": "$balance"},
		}},
	})
	if err != nil {
		return nil, fmt.Errorf("sum accounts: %w", err)
	}
	var kinds []keyCount
	if err := cur.All(ctx, &kinds); err != nil {
		return nil, fmt.Errorf("read account sums: %w", err)
	}
	m := &Money{Mismatched: []string{}, UnbalancedGroups: []string{}}
	for _, k := range kinds {
		m.BooksBalance += k.Sum
		switch k.Key {
		case "system":
			m.CommissionPaisa += k.Sum
		case "escrow":
			m.EscrowHeldPaisa += k.Sum
		case "user":
			m.WalletsPaisa += k.Sum
		case "payout":
			m.WithdrawalsWaitingPaisa += k.Sum
		case "external":
			m.ToppedUpPaisa -= k.Sum
		}
	}

	cur, err = s.entries.Aggregate(ctx, bson.A{
		bson.M{"$group": bson.M{"_id": "$account_id", "sum": bson.M{"$sum": "$amount"}}},
		bson.M{"$lookup": bson.M{"from": s.accounts.Name(), "localField": "_id", "foreignField": "_id", "as": "a"}},
		bson.M{"$project": bson.M{"sum": 1, "n": bson.M{"$ifNull": bson.A{bson.M{"$arrayElemAt": bson.A{"$a.balance", 0}}, 0}}}},
		bson.M{"$match": bson.M{"$expr": bson.M{"$ne": bson.A{"$sum", "$n"}}}},
		bson.M{"$limit": maxProblems},
	})
	if err != nil {
		return nil, fmt.Errorf("check accounts: %w", err)
	}
	var bad []keyCount
	if err := cur.All(ctx, &bad); err != nil {
		return nil, fmt.Errorf("read account check: %w", err)
	}
	for _, b := range bad {
		m.Mismatched = append(m.Mismatched, b.Key)
	}

	cur, err = s.entries.Aggregate(ctx, bson.A{
		bson.M{"$group": bson.M{"_id": "$group_key", "sum": bson.M{"$sum": "$amount"}}},
		bson.M{"$match": bson.M{"sum": bson.M{"$ne": 0}}},
		bson.M{"$limit": maxProblems},
	})
	if err != nil {
		return nil, fmt.Errorf("check postings: %w", err)
	}
	var groups []keyCount
	if err := cur.All(ctx, &groups); err != nil {
		return nil, fmt.Errorf("read posting check: %w", err)
	}
	for _, g := range groups {
		m.UnbalancedGroups = append(m.UnbalancedGroups, g.Key)
	}
	m.Healthy = m.BooksBalance == 0 && len(m.Mismatched) == 0 && len(m.UnbalancedGroups) == 0
	return m, nil
}

type Overview struct {
	Users struct {
		Total             int64 `json:"total"`
		Providers         int64 `json:"providers"`
		VerifiedProviders int64 `json:"verified_providers"`
		Suspended         int64 `json:"suspended"`
		NewThisWeek       int64 `json:"new_this_week"`
	} `json:"users"`
	JobsByStatus map[string]int64 `json:"jobs_by_status"`
	Attention    struct {
		Disputes            int64 `json:"disputes"`
		CancellationReviews int64 `json:"cancellation_reviews"`
		GuaranteeClaims     int64 `json:"guarantee_claims"`
		Unmatched           int64 `json:"unmatched_jobs"`
		UnverifiedProviders int64 `json:"unverified_providers"`
		IdentityChecks      int64 `json:"identity_checks"`
		Withdrawals         int64 `json:"withdrawals"`
		Support             int64 `json:"support"`
		Flags               int64 `json:"flags"`
	} `json:"attention"`
	Money  *Money `json:"money"`
	Last30 Day    `json:"last_30_days"`
	// Days is the last 14 days, oldest first.
	Days []Day `json:"days"`
}

func (s *Service) Overview(ctx context.Context) (*Overview, error) {
	o := &Overview{JobsByStatus: map[string]int64{}}
	counts := []struct {
		c      *mongo.Collection
		filter bson.M
		dst    *int64
	}{
		{s.users, bson.M{}, &o.Users.Total},
		{s.users, bson.M{"has_provider_profile": true}, &o.Users.Providers},
		{s.users, bson.M{"has_provider_profile": true, "is_verified": true}, &o.Users.VerifiedProviders},
		{s.users, bson.M{"suspension": bson.M{"$exists": true}}, &o.Users.Suspended},
		{s.users, bson.M{"created_at": bson.M{"$gte": s.now().AddDate(0, 0, -7)}}, &o.Users.NewThisWeek},
		{s.jobs, bson.M{"status": job.StatusDisputed}, &o.Attention.Disputes},
		{s.jobs, bson.M{"status": job.StatusCancelled, "escrow_review_required": true}, &o.Attention.CancellationReviews},
		{s.jobs, bson.M{"warranty_claim.status": job.ClaimOpen}, &o.Attention.GuaranteeClaims},
		{s.jobs, bson.M{"status": job.StatusManualFallback}, &o.Attention.Unmatched},
		{s.users, bson.M{"verification.status": user.CheckPending}, &o.Attention.IdentityChecks},
		{s.withdrawals, bson.M{"status": payout.StatusPending}, &o.Attention.Withdrawals},
		{s.threads, bson.M{"status": "OPEN", "unread_by_staff": true}, &o.Attention.Support},
		{s.flags, bson.M{"status": "OPEN"}, &o.Attention.Flags},
		{s.users, bson.M{"has_provider_profile": true, "is_verified": bson.M{"$ne": true}, "suspension": bson.M{"$exists": false}}, &o.Attention.UnverifiedProviders},
	}
	for _, c := range counts {
		n, err := c.c.CountDocuments(ctx, c.filter)
		if err != nil {
			return nil, fmt.Errorf("count %s: %w", c.c.Name(), err)
		}
		*c.dst = n
	}

	cur, err := s.jobs.Aggregate(ctx, bson.A{bson.M{"$group": bson.M{"_id": "$status", "n": bson.M{"$sum": 1}}}})
	if err != nil {
		return nil, fmt.Errorf("count jobs by status: %w", err)
	}
	var statuses []keyCount
	if err := cur.All(ctx, &statuses); err != nil {
		return nil, fmt.Errorf("read job counts: %w", err)
	}
	for _, st := range statuses {
		o.JobsByStatus[strings.ToUpper(st.Key)] = st.Count
	}

	if o.Money, err = s.Money(ctx); err != nil {
		return nil, err
	}
	start, end, err := ParseRange("", "", s.now())
	if err != nil {
		return nil, err
	}
	r, err := s.Report(ctx, start, end)
	if err != nil {
		return nil, err
	}
	o.Last30 = r.Totals
	o.Days = r.Days[len(r.Days)-14:]
	return o, nil
}
