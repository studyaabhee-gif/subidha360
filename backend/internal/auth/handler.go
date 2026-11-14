package auth

import (
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/catalog"
	"subidha360/backend/internal/geo"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/user"
)

// Routes registers authentication and profile endpoints.
func (s *Service) Routes(mux *http.ServeMux) {
	mux.HandleFunc("POST /v1/auth/otp/request", s.handleRequestOTP)
	mux.HandleFunc("POST /v1/auth/otp/verify", s.handleVerifyOTP)
	mux.HandleFunc("POST /v1/auth/refresh", s.handleRefresh)
	mux.Handle("POST /v1/auth/logout", s.Require(s.handleLogout))
	mux.Handle("GET /v1/me", s.Require(s.handleMe))
	mux.Handle("PUT /v1/me", s.Require(s.handleUpdateMe))
	mux.Handle("PUT /v1/me/provider-profile", s.Require(s.handleProviderProfile))
	mux.Handle("PUT /v1/me/online", s.Require(s.handleOnline))
	mux.Handle("GET /v1/me/favorites", s.Require(s.handleFavorites))
	mux.Handle("PUT /v1/me/favorites/{id}", s.Require(s.handleAddFavorite))
	mux.Handle("DELETE /v1/me/favorites/{id}", s.Require(s.handleRemoveFavorite))
}

func (s *Service) handleRequestOTP(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Phone string `json:"phone"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.otps.request(r.Context(), req.Phone); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleVerifyOTP(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Phone string `json:"phone"`
		Code  string `json:"code"`
		// TermsVersion is the version of the terms shown on the login screen,
		// which the person agrees to by continuing.
		TermsVersion string `json:"terms_version"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if len(req.TermsVersion) > 20 {
		httpx.Error(w, apperr.BadRequest("invalid_terms_version", "unknown terms version"))
		return
	}
	u, pair, err := s.VerifyOTP(r.Context(), req.Phone, req.Code)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	if req.TermsVersion != "" {
		// MongoDB keeps milliseconds, so round now and the reply matches later reads.
		now := time.Now().UTC().Truncate(time.Millisecond)
		if err := s.users.AcceptTerms(r.Context(), u.ID, req.TermsVersion, now); err != nil {
			httpx.Error(w, err)
			return
		}
		if u.TermsVersion != req.TermsVersion {
			u.TermsVersion, u.TermsAcceptedAt = req.TermsVersion, &now
		}
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"user": u, "tokens": pair})
}

func (s *Service) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	pair, err := s.Refresh(r.Context(), req.RefreshToken)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, pair)
}

func (s *Service) handleLogout(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	access, _ := r.Context().Value(ctxKey{}).(*claims)
	if err := s.Logout(r.Context(), access, req.RefreshToken); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleMe(w http.ResponseWriter, r *http.Request) {
	u, err := s.users.Get(r.Context(), UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, u)
}

func (s *Service) handleUpdateMe(w http.ResponseWriter, r *http.Request) {
	var req struct {
		DisplayName string `json:"display_name"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	name := strings.TrimSpace(req.DisplayName)
	if n := utf8.RuneCountInString(name); n < 2 || n > 60 {
		httpx.Error(w, apperr.BadRequest("invalid_name", "name must be 2 to 60 characters"))
		return
	}
	id := UserID(r.Context())
	if err := s.users.SetDisplayName(r.Context(), id, name); err != nil {
		httpx.Error(w, err)
		return
	}
	s.handleMe(w, r)
}

func (s *Service) handleProviderProfile(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CategoryIDs     []int  `json:"category_ids"`
		Bio             string `json:"bio"`
		YearsExperience int    `json:"years_experience"`
		// Exactly one of Radius or Polygon must be set.
		Radius *struct {
			Lat    float64 `json:"lat"`
			Lng    float64 `json:"lng"`
			Meters float64 `json:"meters"`
		} `json:"radius"`
		Polygon [][2]float64 `json:"polygon"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if len(req.CategoryIDs) == 0 {
		httpx.Error(w, apperr.BadRequest("invalid_categories", "at least one category is required"))
		return
	}
	for _, id := range req.CategoryIDs {
		if !catalog.ValidCategory(id) {
			httpx.Error(w, apperr.BadRequest("invalid_categories", "unknown service category"))
			return
		}
	}
	bio := strings.TrimSpace(req.Bio)
	if utf8.RuneCountInString(bio) > 400 || req.YearsExperience < 0 || req.YearsExperience > 60 {
		httpx.Error(w, apperr.BadRequest("invalid_profile", "bio or experience is out of range"))
		return
	}

	var area geo.Polygon
	var err error
	switch {
	case req.Radius != nil && req.Polygon == nil:
		area, err = geo.Circle(req.Radius.Lat, req.Radius.Lng, req.Radius.Meters)
	case req.Radius == nil && req.Polygon != nil:
		area, err = geo.NewPolygon(req.Polygon)
	default:
		err = apperr.BadRequest("invalid_service_area", "provide exactly one of radius or polygon")
	}
	if err != nil {
		httpx.Error(w, err)
		return
	}

	id := UserID(r.Context())
	profile := user.ProviderProfile{
		ServiceArea:     area,
		CategoryIDs:     req.CategoryIDs,
		IsOnline:        true,
		Bio:             bio,
		YearsExperience: req.YearsExperience,
	}
	if err := s.users.SetProviderProfile(r.Context(), id, profile); err != nil {
		httpx.Error(w, err)
		return
	}
	u, err := s.users.Get(r.Context(), id)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, u)
}

func (s *Service) handleFavorites(w http.ResponseWriter, r *http.Request) {
	u, err := s.users.Get(r.Context(), UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	profiles, err := s.users.PublicProfiles(r.Context(), u.FavoriteProviderIDs)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	rows := make([]user.PublicProfile, 0, len(profiles))
	for _, id := range u.FavoriteProviderIDs {
		if p, ok := profiles[id]; ok {
			rows = append(rows, p)
		}
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleAddFavorite(w http.ResponseWriter, r *http.Request) {
	if err := s.users.AddFavorite(r.Context(), UserID(r.Context()), r.PathValue("id")); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleRemoveFavorite(w http.ResponseWriter, r *http.Request) {
	if err := s.users.RemoveFavorite(r.Context(), UserID(r.Context()), r.PathValue("id")); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleOnline(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Online bool `json:"online"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.users.SetOnline(r.Context(), UserID(r.Context()), req.Online); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
