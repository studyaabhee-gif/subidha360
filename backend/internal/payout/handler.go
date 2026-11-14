package payout

import (
	"net/http"

	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/platform/httpx"
)

// Routes registers a provider's earnings and withdrawal requests. Admin
// decisions are routed through the admin package, which audits them.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("GET /v1/me/earnings", a.Require(s.handleEarnings))
	mux.Handle("POST /v1/me/withdrawals", a.Require(s.handleRequest))
}

func (s *Service) handleEarnings(w http.ResponseWriter, r *http.Request) {
	e, err := s.Earnings(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, e)
}

func (s *Service) handleRequest(w http.ResponseWriter, r *http.Request) {
	var req struct {
		AmountPaisa int64       `json:"amount_paisa"`
		Destination Destination `json:"destination"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	wd, err := s.Request(r.Context(), auth.UserID(r.Context()), req.AmountPaisa, req.Destination)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, wd)
}
