package job

import (
	"net/http"

	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/platform/httpx"
)

// Routes registers job endpoints.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("POST /v1/jobs", a.Require(s.handleCreate))
	mux.Handle("GET /v1/jobs", a.Require(s.handleList))
	mux.Handle("GET /v1/jobs/feed", a.Require(s.handleFeed))
	mux.Handle("GET /v1/jobs/assigned", a.Require(s.handleAssigned))
	mux.Handle("POST /v1/jobs/{id}/warranty-claim", a.Require(s.handleClaim))
	mux.Handle("GET /v1/admin/warranty-claims", a.RequireAdmin(s.handleClaims))
	mux.Handle("GET /v1/jobs/{id}", a.Require(s.handleGet))
	mux.Handle("POST /v1/jobs/{id}/photos", a.Require(s.handleAddPhoto))
	mux.Handle("GET /v1/jobs/{id}/photos/{photoID}", a.Require(s.handlePhoto))
	mux.Handle("DELETE /v1/jobs/{id}/photos/{photoID}", a.Require(s.handleDeletePhoto))
	mux.Handle("POST /v1/jobs/{id}/reschedule", a.Require(s.handleReschedule))
	mux.Handle("PUT /v1/jobs/{id}/tracking", a.Require(s.handleShareLocation))
	mux.Handle("DELETE /v1/jobs/{id}/tracking", a.Require(s.handleStopSharing))
	mux.Handle("GET /v1/jobs/{id}/tracking", a.Require(s.handleTracking))
	mux.Handle("POST /v1/jobs/{id}/start", a.Require(s.handleStart))
	mux.Handle("POST /v1/jobs/{id}/confirm", a.Require(s.handleConfirm))
	mux.Handle("POST /v1/jobs/{id}/cancel", a.Require(s.handleCancel))
	mux.Handle("POST /v1/jobs/{id}/dispute", a.Require(s.handleDispute))
	mux.Handle("GET /v1/admin/escrow-reviews", a.RequireAdmin(s.handleEscrowReviews))
}

func (s *Service) handleAssigned(w http.ResponseWriter, r *http.Request) {
	rows, err := s.ListAssigned(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleClaim(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Reason string `json:"reason"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	j, err := s.ClaimWarranty(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Reason)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, j)
}

func (s *Service) handleClaims(w http.ResponseWriter, r *http.Request) {
	rows, err := s.ListWarrantyClaims(r.Context())
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleDispute(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Reason string `json:"reason"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	j, err := s.RaiseDispute(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Reason)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, j)
}

func (s *Service) handleEscrowReviews(w http.ResponseWriter, r *http.Request) {
	rows, err := s.ListEscrowReviews(r.Context())
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleCreate(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CategoryID          int     `json:"category_id"`
		ServiceID           string  `json:"service_id"`
		Description         string  `json:"description"`
		Address             string  `json:"address"`
		Lat                 float64 `json:"lat"`
		Lng                 float64 `json:"lng"`
		PreferredDate       string  `json:"preferred_date"`
		PreferredSlot       string  `json:"preferred_slot"`
		PreferredProviderID string  `json:"preferred_provider_id"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	j, err := s.Create(r.Context(), auth.UserID(r.Context()), CreateInput(req))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, j)
}

func (s *Service) handleList(w http.ResponseWriter, r *http.Request) {
	rows, err := s.ListBySeeker(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleFeed(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Feed(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	for i := range rows {
		rows[i].blurLocation(auth.UserID(r.Context()))
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleGet(w http.ResponseWriter, r *http.Request) {
	j, err := s.Get(r.Context(), auth.UserID(r.Context()), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	j.blurLocation(auth.UserID(r.Context()))
	httpx.JSON(w, http.StatusOK, j)
}

func (s *Service) handleStart(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	userID := auth.UserID(r.Context())
	if err := s.Start(r.Context(), userID, id); err != nil {
		httpx.Error(w, err)
		return
	}
	j, err := s.Get(r.Context(), userID, id)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, j)
}

func (s *Service) handleConfirm(w http.ResponseWriter, r *http.Request) {
	j, err := s.ConfirmCompletion(r.Context(), auth.UserID(r.Context()), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, j)
}

func (s *Service) handleCancel(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Reason string `json:"reason"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	j, err := s.Cancel(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Reason)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, j)
}
