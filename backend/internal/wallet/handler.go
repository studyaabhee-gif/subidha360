package wallet

import (
	"context"
	"net/http"

	"github.com/google/uuid"

	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/platform/httpx"
)

const historyLimit = 100

// EnsureUserAccount implements auth.AccountCreator.
func (l *Ledger) EnsureUserAccount(ctx context.Context, userID string) error {
	return l.EnsureAccounts(ctx, UserAccount(userID))
}

// Routes registers wallet endpoints. devTopUp exposes a top-up that creates
// money from nothing, so it must stay off until a real gateway replaces it.
func (l *Ledger) Routes(mux *http.ServeMux, a *auth.Service, devTopUp bool) {
	mux.Handle("GET /v1/wallet", a.Require(l.handleWallet))
	if devTopUp {
		mux.Handle("POST /v1/dev/wallet/top-up", a.Require(l.handleDevTopUp))
	}
}

func (l *Ledger) handleWallet(w http.ResponseWriter, r *http.Request) {
	id := auth.UserID(r.Context())
	balance, err := l.AccountBalance(r.Context(), UserAccount(id))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	history, err := l.History(r.Context(), id, historyLimit)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"balance_paisa": balance, "transactions": history})
}

func (l *Ledger) handleDevTopUp(w http.ResponseWriter, r *http.Request) {
	var req struct {
		AmountPaisa int64 `json:"amount_paisa"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := l.TopUp(r.Context(), auth.UserID(r.Context()), req.AmountPaisa, "dev-"+uuid.NewString()); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
