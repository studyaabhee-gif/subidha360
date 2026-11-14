// Package payout covers what providers earn and how they take it out.
//
// eSewa and Khalti merchant payouts are not connected yet, so a withdrawal is
// a request: the money leaves the wallet at once, an admin sends it by bank
// transfer or eWallet, then records the transfer reference. A refused request
// returns the money to the wallet.
package payout

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/job"
	"subidha360/backend/internal/notify"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/user"
	"subidha360/backend/internal/wallet"
)

// Withdrawal statuses.
const (
	StatusPending  = "PENDING"
	StatusPaid     = "PAID"
	StatusRejected = "REJECTED"
)

// Destination kinds.
const (
	MethodBank   = "bank"
	MethodESewa  = "esewa"
	MethodKhalti = "khalti"
)

// MinWithdrawal keeps transfer fees and admin effort worth it.
const MinWithdrawal = 100 * 100

const (
	historyRows = 20
	monthsShown = 6
	noteType    = "wallet.withdrawal"
)

var (
	nepal         = time.FixedZone("NPT", 5*3600+45*60)
	walletPattern = regexp.MustCompile(`^9[78]\d{8}$`)
	digitsPattern = regexp.MustCompile(`^\d{6,20}$`)
)

// Destination is where the money is sent.
type Destination struct {
	Method        string `bson:"method" json:"method"`
	BankName      string `bson:"bank_name,omitempty" json:"bank_name,omitempty"`
	AccountName   string `bson:"account_name,omitempty" json:"account_name,omitempty"`
	AccountNumber string `bson:"account_number,omitempty" json:"account_number,omitempty"`
	// WalletID is the eSewa or Khalti ID, which is a mobile number.
	WalletID string `bson:"wallet_id,omitempty" json:"wallet_id,omitempty"`
}

func textOK(s string) bool {
	n := utf8.RuneCountInString(s)
	return n >= 2 && n <= 60
}

func (d *Destination) clean() error {
	d.BankName = strings.TrimSpace(d.BankName)
	d.AccountName = strings.TrimSpace(d.AccountName)
	d.AccountNumber = strings.ReplaceAll(strings.TrimSpace(d.AccountNumber), " ", "")
	d.WalletID = strings.TrimPrefix(strings.ReplaceAll(strings.TrimSpace(d.WalletID), " ", ""), "+977")
	switch d.Method {
	case MethodBank:
		if !textOK(d.BankName) || !textOK(d.AccountName) {
			return apperr.BadRequest("invalid_destination", "enter the bank name and the name on the account")
		}
		if !digitsPattern.MatchString(d.AccountNumber) {
			return apperr.BadRequest("invalid_destination", "account numbers are 6 to 20 digits")
		}
		d.WalletID = ""
	case MethodESewa, MethodKhalti:
		if !walletPattern.MatchString(d.WalletID) {
			return apperr.BadRequest("invalid_destination", "enter the 10-digit mobile number of the eWallet")
		}
		if !textOK(d.AccountName) {
			return apperr.BadRequest("invalid_destination", "enter the name on the eWallet")
		}
		d.BankName, d.AccountNumber = "", ""
	default:
		return apperr.BadRequest("invalid_destination", "choose a bank account, eSewa or Khalti")
	}
	return nil
}

type Withdrawal struct {
	ID          string      `bson:"_id" json:"id"`
	UserID      string      `bson:"user_id" json:"user_id"`
	Amount      int64       `bson:"amount" json:"amount_paisa"`
	Destination Destination `bson:"destination" json:"destination"`
	Status      string      `bson:"status" json:"status"`
	// Reference is the bank or eWallet transaction ID, shown to the provider.
	Reference string     `bson:"reference,omitempty" json:"reference,omitempty"`
	Reason    string     `bson:"reason,omitempty" json:"reason,omitempty"`
	DecidedBy string     `bson:"decided_by,omitempty" json:"-"`
	DecidedAt *time.Time `bson:"decided_at,omitempty" json:"decided_at,omitempty"`
	CreatedAt time.Time  `bson:"created_at" json:"created_at"`
}

type Service struct {
	client  *mongo.Client
	rows    *mongo.Collection
	jobs    *mongo.Collection
	entries *mongo.Collection
	ledger  *wallet.Ledger
	users   *user.Repo
	notify  *notify.Service
	now     func() time.Time
}

func NewService(client *mongo.Client, db *mongo.Database, ledger *wallet.Ledger, users *user.Repo, n *notify.Service) *Service {
	return &Service{
		client:  client,
		rows:    db.Collection(mongodb.Withdrawals),
		jobs:    db.Collection(mongodb.Jobs),
		entries: db.Collection(mongodb.WalletLedger),
		ledger:  ledger,
		users:   users,
		notify:  n,
		now:     func() time.Time { return time.Now().UTC() },
	}
}

// Request takes money out of the wallet and queues it for an admin to send.
// Only providers with a verified identity can withdraw, so money always
// leaves to a person someone has checked.
func (s *Service) Request(ctx context.Context, userID string, amount int64, dest Destination) (*Withdrawal, error) {
	if amount < MinWithdrawal {
		return nil, apperr.BadRequest("amount_too_small", "the smallest withdrawal is Rs 100")
	}
	if err := dest.clean(); err != nil {
		return nil, err
	}
	w := &Withdrawal{ID: uuid.NewString(), UserID: userID, Amount: amount, Destination: dest, Status: StatusPending, CreatedAt: s.now()}
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		u, err := s.users.Get(ctx, userID)
		if err != nil {
			return err
		}
		if !u.IsVerified {
			return apperr.Forbidden("verification_required", "get your identity verified before withdrawing")
		}
		_, err = s.rows.InsertOne(ctx, w)
		if mongo.IsDuplicateKeyError(err) {
			return apperr.Conflict("withdrawal_waiting", "wait for your current withdrawal to be paid first")
		}
		if err != nil {
			return fmt.Errorf("insert withdrawal: %w", err)
		}
		return s.ledger.HoldWithdrawal(ctx, userID, w.ID, amount)
	})
	if err != nil {
		return nil, err
	}
	return w, nil
}

// Decide pays or refuses a waiting withdrawal. Paying needs the transfer
// reference; refusing needs a reason, which the provider sees.
func (s *Service) Decide(ctx context.Context, adminID, id string, paid bool, note string) (*Withdrawal, error) {
	note = strings.TrimSpace(note)
	if note == "" || utf8.RuneCountInString(note) > 200 {
		if paid {
			return nil, apperr.BadRequest("reference_required", "enter the bank or eWallet transaction reference")
		}
		return nil, apperr.BadRequest("reason_required", "tell the provider why, in under 200 characters")
	}
	var w Withdrawal
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		set := bson.M{"decided_by": adminID, "decided_at": s.now()}
		if paid {
			set["status"], set["reference"] = StatusPaid, note
		} else {
			set["status"], set["reason"] = StatusRejected, note
		}
		err := s.rows.FindOneAndUpdate(ctx, bson.M{"_id": id, "status": StatusPending}, bson.M{"$set": set},
			options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&w)
		if errors.Is(err, mongo.ErrNoDocuments) {
			return apperr.Conflict("not_waiting", "this withdrawal was already decided")
		}
		if err != nil {
			return fmt.Errorf("decide withdrawal: %w", err)
		}
		msg := notify.Message{UserID: w.UserID, Type: noteType, Critical: true}
		if paid {
			if err := s.ledger.PayWithdrawal(ctx, w.UserID, w.ID, w.Amount); err != nil {
				return err
			}
			msg.Title = "Withdrawal sent"
			msg.Body = fmt.Sprintf("Rs %s was sent to your %s. Reference: %s", rupees(w.Amount), methodName(w.Destination.Method), note)
		} else {
			if err := s.ledger.ReturnWithdrawal(ctx, w.UserID, w.ID, w.Amount); err != nil {
				return err
			}
			msg.Title = "Withdrawal not sent"
			msg.Body = fmt.Sprintf("Rs %s is back in your wallet. %s", rupees(w.Amount), note)
		}
		return s.notify.Enqueue(ctx, msg)
	})
	if err != nil {
		return nil, err
	}
	return &w, nil
}

func methodName(m string) string {
	switch m {
	case MethodESewa:
		return "eSewa"
	case MethodKhalti:
		return "Khalti"
	}
	return "bank account"
}

func rupees(paisa int64) string {
	whole := fmt.Sprintf("%d", paisa/100)
	for i := len(whole) - 3; i > 0; i -= 3 {
		whole = whole[:i] + "," + whole[i:]
	}
	if paisa%100 == 0 {
		return whole
	}
	return fmt.Sprintf("%s.%02d", whole, paisa%100)
}

// List returns withdrawals, newest first. userID "" means everyone's.
func (s *Service) List(ctx context.Context, userID, status string, limit int64) ([]Withdrawal, error) {
	filter := bson.M{}
	if userID != "" {
		filter["user_id"] = userID
	}
	if status != "" {
		filter["status"] = status
	}
	cur, err := s.rows.Find(ctx, filter, options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(limit))
	if err != nil {
		return nil, fmt.Errorf("find withdrawals: %w", err)
	}
	rows := []Withdrawal{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read withdrawals: %w", err)
	}
	return rows, nil
}

// Month is one month of earnings.
type Month struct {
	Month  string `json:"month"`
	Earned int64  `json:"earned_paisa"`
	Jobs   int64  `json:"jobs"`
}

// Payment is one job's payout.
type Payment struct {
	JobID      string    `json:"job_id"`
	CategoryID int       `json:"category_id"`
	Price      int64     `json:"price_paisa"`
	Earned     int64     `json:"earned_paisa"`
	Commission int64     `json:"commission_paisa"`
	At         time.Time `json:"at"`
}

// Earnings is a provider's money at a glance.
type Earnings struct {
	AvailablePaisa   int64        `json:"available_paisa"`
	OnHoldPaisa      int64        `json:"on_hold_paisa"`
	WithdrawingPaisa int64        `json:"withdrawing_paisa"`
	TotalEarned      int64        `json:"total_earned_paisa"`
	ThisMonth        int64        `json:"this_month_paisa"`
	CommissionPaid   int64        `json:"commission_paid_paisa"`
	JobsPaid         int64        `json:"jobs_paid"`
	Verified         bool         `json:"verified"`
	MinWithdrawal    int64        `json:"min_withdrawal_paisa"`
	Months           []Month      `json:"months"`
	Payments         []Payment    `json:"payments"`
	Withdrawals      []Withdrawal `json:"withdrawals"`
}

var activeStatuses = []job.Status{job.StatusAccepted, job.StatusInProgress, job.StatusDisputed}

func (s *Service) Earnings(ctx context.Context, userID string) (*Earnings, error) {
	u, err := s.users.Get(ctx, userID)
	if err != nil {
		return nil, err
	}
	e := &Earnings{Verified: u.IsVerified, MinWithdrawal: MinWithdrawal, Months: []Month{}, Payments: []Payment{}}
	if e.AvailablePaisa, err = s.ledger.AccountBalance(ctx, wallet.UserAccount(userID)); err != nil {
		return nil, err
	}

	// Money held for jobs this provider is on now. It is the agreed price;
	// commission comes off when it is released.
	cur, err := s.jobs.Aggregate(ctx, bson.A{
		bson.M{"$match": bson.M{"provider_id": userID, "status": bson.M{"$in": activeStatuses}}},
		bson.M{"$group": bson.M{"_id": nil, "sum": bson.M{"$sum": "$escrow_amount"}}},
	})
	if err != nil {
		return nil, fmt.Errorf("sum held: %w", err)
	}
	var held []struct {
		Sum int64 `bson:"sum"`
	}
	if err := cur.All(ctx, &held); err != nil {
		return nil, fmt.Errorf("read held: %w", err)
	}
	if len(held) > 0 {
		e.OnHoldPaisa = held[0].Sum
	}

	if e.Withdrawals, err = s.List(ctx, userID, "", historyRows); err != nil {
		return nil, err
	}
	for _, w := range e.Withdrawals {
		if w.Status == StatusPending {
			e.WithdrawingPaisa += w.Amount
		}
	}

	// Every payout to this wallet, joined to its job and that job's commission.
	cur, err = s.entries.Aggregate(ctx, bson.A{
		bson.M{"$match": bson.M{"account_id": wallet.UserAccount(userID), "transaction_type": wallet.TypePayout, "amount": bson.M{"$gt": 0}}},
		bson.M{"$sort": bson.M{"created_at": -1}},
		bson.M{"$lookup": bson.M{
			"from":         s.entries.Name(),
			"localField":   "reference_job_id",
			"foreignField": "reference_job_id",
			"pipeline":     bson.A{bson.M{"$match": bson.M{"transaction_type": wallet.TypeCommission}}},
			"as":           "commission",
		}},
		bson.M{"$lookup": bson.M{"from": s.jobs.Name(), "localField": "reference_job_id", "foreignField": "_id", "as": "job"}},
	})
	if err != nil {
		return nil, fmt.Errorf("find payouts: %w", err)
	}
	var rows []struct {
		JobID      string    `bson:"reference_job_id"`
		Amount     int64     `bson:"amount"`
		CreatedAt  time.Time `bson:"created_at"`
		Commission []struct {
			Amount int64 `bson:"amount"`
		} `bson:"commission"`
		Job []struct {
			CategoryID   int   `bson:"category_id"`
			EscrowAmount int64 `bson:"escrow_amount"`
		} `bson:"job"`
	}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read payouts: %w", err)
	}

	now := s.now().In(nepal)
	thisMonth := now.Format("2006-01")
	months := map[string]*Month{}
	for i := monthsShown - 1; i >= 0; i-- {
		key := time.Date(now.Year(), now.Month()-time.Month(i), 1, 0, 0, 0, 0, nepal).Format("2006-01")
		e.Months = append(e.Months, Month{Month: key})
	}
	for i := range e.Months {
		months[e.Months[i].Month] = &e.Months[i]
	}
	for _, r := range rows {
		var commission int64
		for _, c := range r.Commission {
			commission += c.Amount
		}
		e.TotalEarned += r.Amount
		e.CommissionPaid += commission
		e.JobsPaid++
		key := r.CreatedAt.In(nepal).Format("2006-01")
		if key == thisMonth {
			e.ThisMonth += r.Amount
		}
		if m := months[key]; m != nil {
			m.Earned += r.Amount
			m.Jobs++
		}
		if len(e.Payments) < historyRows {
			p := Payment{JobID: r.JobID, Earned: r.Amount, Commission: commission, At: r.CreatedAt}
			if len(r.Job) > 0 {
				p.CategoryID = r.Job[0].CategoryID
				p.Price = r.Job[0].EscrowAmount
			}
			e.Payments = append(e.Payments, p)
		}
	}
	return e, nil
}
