// Package wallet implements the double-entry ledger behind the in-app wallet.
//
// All amounts are integer paisa (1 NPR = 100 paisa), so no rounding can occur.
// Every posting is a group of legs that sum to zero, written in one transaction
// together with the balance changes. Ledger entries are never updated.
package wallet

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/platform/mongodb"
)

// Transaction types.
const (
	TypeTopUp        = "TOP_UP"
	TypeEscrowHold   = "ESCROW_HOLD"
	TypeEscrowRefund = "ESCROW_REFUND"
	TypePayout       = "PAYOUT"
	TypeCommission   = "COMMISSION"
	// TypeWithdrawal moves money from a wallet into a waiting withdrawal.
	TypeWithdrawal = "WITHDRAWAL"
	// TypeWithdrawalPaid records money sent out to a bank or eWallet.
	TypeWithdrawalPaid = "WITHDRAWAL_PAID"
	// TypeWithdrawalReturned puts a refused withdrawal back in the wallet.
	TypeWithdrawalReturned = "WITHDRAWAL_RETURNED"
)

const (
	// AccountCommission accumulates platform revenue.
	AccountCommission = "system:commission"
	// AccountGateway mirrors money held at eSewa/Khalti. It is the only account
	// allowed to go negative, because top-ups debit it.
	AccountGateway = "external:gateway"
)

// ErrInsufficientFunds is returned when a debit would overdraw an account.
var ErrInsufficientFunds = apperr.Conflict("insufficient_funds", "wallet balance is too low")

// UserAccount returns the account ID for a user's wallet.
func UserAccount(userID string) string { return "user:" + userID }

// WithdrawalAccount holds money between a withdrawal request and its payment.
func WithdrawalAccount(id string) string { return "payout:" + id }

// EscrowAccount returns the account holding funds for one job. One account per
// job keeps concurrent jobs from contending on a shared document.
func EscrowAccount(jobID string) string { return "escrow:" + jobID }

// Leg is one side of a posting. Positive amounts credit, negative amounts debit.
type Leg struct {
	Account string
	UserID  string
	Amount  int64
	Type    string
}

// Entry is an immutable row in wallet_ledger.
type Entry struct {
	TransactionID   string    `bson:"_id" json:"transaction_id"`
	GroupKey        string    `bson:"group_key" json:"-"`
	Leg             int       `bson:"leg" json:"-"`
	AccountID       string    `bson:"account_id" json:"-"`
	UserID          string    `bson:"user_id,omitempty" json:"user_id,omitempty"`
	Amount          int64     `bson:"amount" json:"amount_paisa"`
	TransactionType string    `bson:"transaction_type" json:"transaction_type"`
	ReferenceJobID  string    `bson:"reference_job_id,omitempty" json:"reference_job_id,omitempty"`
	CreatedAt       time.Time `bson:"created_at" json:"created_at"`
}

type Ledger struct {
	client   *mongo.Client
	accounts *mongo.Collection
	entries  *mongo.Collection
}

func NewLedger(client *mongo.Client, db *mongo.Database) *Ledger {
	return &Ledger{
		client:   client,
		accounts: db.Collection(mongodb.WalletAccounts),
		entries:  db.Collection(mongodb.WalletLedger),
	}
}

// EnsureAccounts creates accounts outside any transaction. Creating a shared
// account inside concurrent transactions would fail with a duplicate key that
// the driver does not retry.
func (l *Ledger) EnsureAccounts(ctx context.Context, ids ...string) error {
	for _, id := range ids {
		_, err := l.accounts.UpdateOne(ctx,
			bson.M{"_id": id},
			bson.M{"$setOnInsert": bson.M{"balance": int64(0)}},
			options.UpdateOne().SetUpsert(true),
		)
		if err != nil && !mongo.IsDuplicateKeyError(err) {
			return fmt.Errorf("ensure account %s: %w", id, err)
		}
	}
	return nil
}

// Post writes a balanced group of legs atomically. groupKey makes the posting
// idempotent: a second post with the same key fails with a conflict.
func (l *Ledger) Post(ctx context.Context, groupKey, jobID string, legs []Leg) error {
	var sum int64
	for _, leg := range legs {
		if leg.Amount == 0 {
			return fmt.Errorf("post %s: zero-amount leg on %s", groupKey, leg.Account)
		}
		sum += leg.Amount
	}
	if sum != 0 || len(legs) < 2 {
		return fmt.Errorf("post %s: unbalanced legs (sum %d, count %d)", groupKey, sum, len(legs))
	}

	return mongodb.Tx(ctx, l.client, func(ctx context.Context) error {
		now := time.Now().UTC()
		rows := make([]Entry, len(legs))
		for i, leg := range legs {
			if err := l.apply(ctx, leg); err != nil {
				return err
			}
			rows[i] = Entry{
				TransactionID:   uuid.NewString(),
				GroupKey:        groupKey,
				Leg:             i,
				AccountID:       leg.Account,
				UserID:          leg.UserID,
				Amount:          leg.Amount,
				TransactionType: leg.Type,
				ReferenceJobID:  jobID,
				CreatedAt:       now,
			}
		}
		_, err := l.entries.InsertMany(ctx, rows)
		if mongo.IsDuplicateKeyError(err) {
			return apperr.Conflict("duplicate_posting", "this transaction was already recorded")
		}
		if err != nil {
			return fmt.Errorf("insert ledger entries: %w", err)
		}
		return nil
	})
}

func (l *Ledger) apply(ctx context.Context, leg Leg) error {
	filter := bson.M{"_id": leg.Account}
	external := strings.HasPrefix(leg.Account, "external:")
	if leg.Amount < 0 && !external {
		filter["balance"] = bson.M{"$gte": -leg.Amount}
	}
	res, err := l.accounts.UpdateOne(ctx, filter,
		bson.M{"$inc": bson.M{"balance": leg.Amount}},
		options.UpdateOne().SetUpsert(leg.Amount > 0 || external),
	)
	if err != nil {
		return fmt.Errorf("apply leg on %s: %w", leg.Account, err)
	}
	if res.MatchedCount == 0 && res.UpsertedCount == 0 {
		return ErrInsufficientFunds
	}
	return nil
}

// TopUp credits a wallet. reference must uniquely identify the gateway payment,
// so a replayed gateway callback cannot credit twice.
func (l *Ledger) TopUp(ctx context.Context, userID string, amount int64, reference string) error {
	if amount <= 0 {
		return apperr.BadRequest("invalid_amount", "amount must be positive")
	}
	return l.Post(ctx, "topup:"+reference, "", []Leg{
		{Account: AccountGateway, Amount: -amount, Type: TypeTopUp},
		{Account: UserAccount(userID), UserID: userID, Amount: amount, Type: TypeTopUp},
	})
}

// HoldEscrow moves the full bid amount from the seeker's wallet into job escrow.
func (l *Ledger) HoldEscrow(ctx context.Context, seekerID, jobID string, amount int64) error {
	return l.Post(ctx, "escrow-hold:"+jobID, jobID, []Leg{
		{Account: UserAccount(seekerID), UserID: seekerID, Amount: -amount, Type: TypeEscrowHold},
		{Account: EscrowAccount(jobID), Amount: amount, Type: TypeEscrowHold},
	})
}

// RefundEscrow returns job escrow to the seeker.
func (l *Ledger) RefundEscrow(ctx context.Context, seekerID, jobID string, amount int64) error {
	return l.Post(ctx, "escrow-refund:"+jobID, jobID, []Leg{
		{Account: EscrowAccount(jobID), Amount: -amount, Type: TypeEscrowRefund},
		{Account: UserAccount(seekerID), UserID: seekerID, Amount: amount, Type: TypeEscrowRefund},
	})
}

// HoldWithdrawal moves money out of a wallet while a withdrawal waits.
func (l *Ledger) HoldWithdrawal(ctx context.Context, userID, id string, amount int64) error {
	return l.Post(ctx, "withdrawal-hold:"+id, "", []Leg{
		{Account: UserAccount(userID), UserID: userID, Amount: -amount, Type: TypeWithdrawal},
		{Account: WithdrawalAccount(id), Amount: amount, Type: TypeWithdrawal},
	})
}

// PayWithdrawal records that the money was sent out of the platform.
func (l *Ledger) PayWithdrawal(ctx context.Context, userID, id string, amount int64) error {
	return l.Post(ctx, "withdrawal-paid:"+id, "", []Leg{
		{Account: WithdrawalAccount(id), Amount: -amount, Type: TypeWithdrawalPaid},
		{Account: AccountGateway, UserID: userID, Amount: amount, Type: TypeWithdrawalPaid},
	})
}

// ReturnWithdrawal puts a refused withdrawal back in the wallet.
func (l *Ledger) ReturnWithdrawal(ctx context.Context, userID, id string, amount int64) error {
	return l.Post(ctx, "withdrawal-returned:"+id, "", []Leg{
		{Account: WithdrawalAccount(id), Amount: -amount, Type: TypeWithdrawalReturned},
		{Account: UserAccount(userID), UserID: userID, Amount: amount, Type: TypeWithdrawalReturned},
	})
}

// Commission returns the platform's share, rounded down to a whole paisa.
func Commission(amount, bps int64) int64 { return amount * bps / 10000 }

// Settle releases all job escrow to the provider, less commission.
func (l *Ledger) Settle(ctx context.Context, seekerID, providerID, jobID string, amount, bps int64) error {
	return l.Split(ctx, seekerID, providerID, jobID, amount, 100, bps)
}

// Split divides job escrow: providerPercent goes to the provider, less
// commission on that share, and the remainder returns to the seeker.
func (l *Ledger) Split(ctx context.Context, seekerID, providerID, jobID string, amount, providerPercent, bps int64) error {
	if providerPercent < 0 || providerPercent > 100 {
		return apperr.BadRequest("invalid_percent", "provider share must be between 0 and 100")
	}
	providerShare := amount * providerPercent / 100
	commission := Commission(providerShare, bps)
	payout := providerShare - commission
	refund := amount - providerShare

	legs := []Leg{{Account: EscrowAccount(jobID), Amount: -amount, Type: TypePayout}}
	if payout > 0 {
		legs = append(legs, Leg{Account: UserAccount(providerID), UserID: providerID, Amount: payout, Type: TypePayout})
	}
	if commission > 0 {
		legs = append(legs, Leg{Account: AccountCommission, Amount: commission, Type: TypeCommission})
	}
	if refund > 0 {
		legs = append(legs, Leg{Account: UserAccount(seekerID), UserID: seekerID, Amount: refund, Type: TypeEscrowRefund})
	}
	return l.Post(ctx, "settle:"+jobID, jobID, legs)
}

// AccountBalance returns an account's balance, or zero if it does not exist yet.
func (l *Ledger) AccountBalance(ctx context.Context, account string) (int64, error) {
	var row struct {
		Balance int64 `bson:"balance"`
	}
	err := l.accounts.FindOne(ctx, bson.M{"_id": account}).Decode(&row)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("read balance: %w", err)
	}
	return row.Balance, nil
}

// History returns a user's most recent ledger entries, newest first.
func (l *Ledger) History(ctx context.Context, userID string, limit int64) ([]Entry, error) {
	cur, err := l.entries.Find(ctx,
		bson.M{"account_id": UserAccount(userID)},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(limit),
	)
	if err != nil {
		return nil, fmt.Errorf("find history: %w", err)
	}
	rows := []Entry{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read history: %w", err)
	}
	return rows, nil
}
