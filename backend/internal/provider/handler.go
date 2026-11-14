package provider

import (
	"io"
	"net/http"
	"strconv"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/user"
)

// Routes registers a provider's own documents, gallery and schedule, and the
// public gallery others see.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("GET /v1/me/documents", a.Require(s.handleDocuments))
	mux.Handle("POST /v1/me/documents", a.Require(s.handleAddDocument))
	mux.Handle("GET /v1/me/documents/{id}", a.Require(s.handleOwnDocument))
	mux.Handle("DELETE /v1/me/documents/{id}", a.Require(s.handleDeleteDocument))
	mux.Handle("POST /v1/me/verification", a.Require(s.handleSubmit))
	mux.Handle("POST /v1/me/gallery", a.Require(s.handleAddPhoto))
	mux.Handle("DELETE /v1/me/gallery/{id}", a.Require(s.handleDeletePhoto))
	mux.Handle("PUT /v1/me/availability", a.Require(s.handleAvailability))
	mux.Handle("DELETE /v1/me/availability", a.Require(s.handleClearAvailability))
	mux.Handle("GET /v1/providers/{id}/gallery", a.Require(s.handleGallery))
	mux.Handle("GET /v1/providers/{id}/gallery/{photoID}", a.Require(s.handlePhoto))
}

// readFile reads a raw upload body, refusing anything over the size limit
// before reading it all into memory.
func readFile(w http.ResponseWriter, r *http.Request) ([]byte, error) {
	data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxFileBytes+1))
	if err != nil || len(data) > maxFileBytes {
		return nil, apperr.BadRequest("file_too_large", "files must be 5 MB or smaller")
	}
	return data, nil
}

// serveFile sends stored bytes. Files are private and never cached by
// shared caches.
func serveFile(w http.ResponseWriter, kind string, data []byte) {
	w.Header().Set("Content-Type", kind)
	w.Header().Set("Content-Length", strconv.Itoa(len(data)))
	w.Header().Set("Cache-Control", "private, max-age=3600")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Write(data)
}

func (s *Service) handleDocuments(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Documents(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleAddDocument(w http.ResponseWriter, r *http.Request) {
	data, err := readFile(w, r)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	q := r.URL.Query()
	d, err := s.AddDocument(r.Context(), auth.UserID(r.Context()), q.Get("kind"), q.Get("label"), data)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, d)
}

func (s *Service) handleOwnDocument(w http.ResponseWriter, r *http.Request) {
	d, err := s.Document(r.Context(), auth.UserID(r.Context()), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	serveFile(w, d.Type, d.Data)
}

// ServeAnyDocument lets admin routes show any provider's document.
func (s *Service) ServeAnyDocument(w http.ResponseWriter, r *http.Request) {
	d, err := s.Document(r.Context(), "", r.PathValue("docID"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	serveFile(w, d.Type, d.Data)
}

func (s *Service) handleDeleteDocument(w http.ResponseWriter, r *http.Request) {
	if err := s.DeleteDocument(r.Context(), auth.UserID(r.Context()), r.PathValue("id")); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleSubmit(w http.ResponseWriter, r *http.Request) {
	id := auth.UserID(r.Context())
	if err := s.SubmitCheck(r.Context(), id); err != nil {
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

func (s *Service) handleAddPhoto(w http.ResponseWriter, r *http.Request) {
	data, err := readFile(w, r)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	p, err := s.AddPhoto(r.Context(), auth.UserID(r.Context()), r.URL.Query().Get("caption"), data)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, p)
}

func (s *Service) handleDeletePhoto(w http.ResponseWriter, r *http.Request) {
	if err := s.DeletePhoto(r.Context(), auth.UserID(r.Context()), r.PathValue("id")); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleGallery(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Gallery(r.Context(), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handlePhoto(w http.ResponseWriter, r *http.Request) {
	p, err := s.Photo(r.Context(), r.PathValue("id"), r.PathValue("photoID"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	serveFile(w, p.Type, p.Data)
}

func (s *Service) handleAvailability(w http.ResponseWriter, r *http.Request) {
	var req user.Availability
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	a, err := s.SetAvailability(r.Context(), auth.UserID(r.Context()), &req)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, a)
}

func (s *Service) handleClearAvailability(w http.ResponseWriter, r *http.Request) {
	if _, err := s.SetAvailability(r.Context(), auth.UserID(r.Context()), nil); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
