// Package account lets people delete their own account.
//
// Deleting removes what identifies a person: their phone number, name,
// provider profile, identity documents, past-work photos, devices, favourites
// and support conversations. Jobs, reviews and payments stay, because the
// other person on each job and the tax records still need them, but they no
// longer point to anyone identifiable. Logging in again with the same number
// starts a new, empty account.
package account

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/user"
	"subidha360/backend/internal/wallet"
)

// unfinished are job states with work or money still in play.
var unfinished = bson.A{"BROADCASTING", "ESCALATING", "MANUAL_FALLBACK", "ACCEPTED", "IN_PROGRESS", "DISPUTED"}

type Service struct {
	client *mongo.Client
	db     *mongo.Database
	users  *user.Repo
	ledger *wallet.Ledger
	auth   *auth.Service
}

func NewService(client *mongo.Client, db *mongo.Database, users *user.Repo, ledger *wallet.Ledger, a *auth.Service) *Service {
	return &Service{client: client, db: db, users: users, ledger: ledger, auth: a}
}

// Blocker is a reason an account cannot be deleted yet, with what to do.
type Blocker struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// Check lists what stops the account being deleted right now. Empty means it
// can be deleted.
func (s *Service) Check(ctx context.Context, id string) ([]Blocker, error) {
	u, err := s.users.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	blockers := []Blocker{}
	if u.IsAdmin {
		blockers = append(blockers, Blocker{"admin", "Admin accounts must have admin access removed first."})
	}
	jobs, err := s.db.Collection(mongodb.Jobs).CountDocuments(ctx, bson.M{
		"$or": bson.A{bson.M{"seeker_id": id}, bson.M{"provider_id": id}},
		"$and": bson.A{bson.M{"$or": bson.A{
			bson.M{"status": bson.M{"$in": unfinished}},
			bson.M{"status": "CANCELLED", "escrow_review_required": true},
		}}},
	})
	if err != nil {
		return nil, fmt.Errorf("count jobs: %w", err)
	}
	if jobs > 0 {
		blockers = append(blockers, Blocker{"active_jobs", fmt.Sprintf("You have %d job(s) still open or in progress. Finish or cancel them first.", jobs)})
	}
	balance, err := s.ledger.AccountBalance(ctx, wallet.UserAccount(id))
	if err != nil {
		return nil, err
	}
	if balance > 0 {
		blockers = append(blockers, Blocker{"wallet_balance", fmt.Sprintf("Your wallet still holds Rs %d.%02d. Withdraw it, or write to us through Help and we will return it.", balance/100, balance%100)})
	}
	waiting, err := s.db.Collection(mongodb.Withdrawals).CountDocuments(ctx, bson.M{"user_id": id, "status": "PENDING"})
	if err != nil {
		return nil, fmt.Errorf("count withdrawals: %w", err)
	}
	if waiting > 0 {
		blockers = append(blockers, Blocker{"withdrawal_waiting", "Wait until your withdrawal has been sent."})
	}
	return blockers, nil
}

// Delete removes everything that identifies the person, if nothing blocks it.
func (s *Service) Delete(ctx context.Context, id string) error {
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		blockers, err := s.Check(ctx, id)
		if err != nil {
			return err
		}
		if len(blockers) > 0 {
			return apperr.Conflict("cannot_delete_yet", blockers[0].Message)
		}
		now := time.Now().UTC()
		_, err = s.db.Collection(mongodb.Users).UpdateOne(ctx, bson.M{"_id": id}, bson.M{
			"$set": bson.M{
				// The number is freed, so a later login starts a new account.
				"phone_number":         "deleted:" + id,
				"display_name":         "",
				"has_provider_profile": false,
				"is_verified":          false,
				"deleted_at":           now,
			},
			"$unset": bson.M{
				"provider_profile": "", "availability": "", "verification": "",
				"favorite_provider_ids": "", "terms_version": "", "terms_accepted_at": "",
			},
		})
		if err != nil {
			return fmt.Errorf("clear user: %w", err)
		}
		// Others stop seeing this provider among their favourites.
		if _, err := s.db.Collection(mongodb.Users).UpdateMany(ctx,
			bson.M{"favorite_provider_ids": id}, bson.M{"$pull": bson.M{"favorite_provider_ids": id}}); err != nil {
			return fmt.Errorf("remove from favourites: %w", err)
		}
		for _, c := range []string{mongodb.ProviderDocuments, mongodb.ProviderPhotos, mongodb.Devices} {
			if _, err := s.db.Collection(c).DeleteMany(ctx, bson.M{"user_id": id}); err != nil {
				return fmt.Errorf("delete %s: %w", c, err)
			}
		}
		threads := s.db.Collection(mongodb.SupportThreads)
		cur, err := threads.Find(ctx, bson.M{"user_id": id})
		if err != nil {
			return fmt.Errorf("find threads: %w", err)
		}
		var rows []struct {
			ID string `bson:"_id"`
		}
		if err := cur.All(ctx, &rows); err != nil {
			return fmt.Errorf("read threads: %w", err)
		}
		ids := bson.A{}
		for _, r := range rows {
			ids = append(ids, r.ID)
		}
		if len(ids) > 0 {
			if _, err := s.db.Collection(mongodb.SupportMessages).DeleteMany(ctx, bson.M{"thread_id": bson.M{"$in": ids}}); err != nil {
				return fmt.Errorf("delete support messages: %w", err)
			}
		}
		if _, err := threads.DeleteMany(ctx, bson.M{"user_id": id}); err != nil {
			return fmt.Errorf("delete threads: %w", err)
		}
		return nil
	})
	if err != nil {
		return err
	}
	// Ends every session on every device at once.
	return s.auth.MarkSuspended(ctx, id, true)
}

// Routes registers the account endpoints.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("GET /v1/me/deletion", a.Require(s.handleCheck))
	mux.Handle("DELETE /v1/me", a.Require(s.handleDelete))
}

func (s *Service) handleCheck(w http.ResponseWriter, r *http.Request) {
	blockers, err := s.Check(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"can_delete": len(blockers) == 0, "blockers": blockers})
}

func (s *Service) handleDelete(w http.ResponseWriter, r *http.Request) {
	var req struct {
		// The person types DELETE, so a stray tap can never remove an account.
		Confirm string `json:"confirm"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if req.Confirm != "DELETE" {
		httpx.Error(w, apperr.BadRequest("confirm_required", `type DELETE to confirm`))
		return
	}
	if err := s.Delete(r.Context(), auth.UserID(r.Context())); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
