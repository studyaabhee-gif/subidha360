// Package httpx holds small JSON helpers shared by HTTP handlers.
package httpx

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"subidha360/backend/internal/apperr"
)

const maxBodyBytes = 1 << 20

func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("encode response", "err", err)
	}
}

// Error writes err to the client. Anything that is not an *apperr.Error is
// logged and reported as a generic 500 so internals never leak.
func Error(w http.ResponseWriter, err error) {
	var e *apperr.Error
	if !errors.As(err, &e) {
		slog.Error("request failed", "err", err)
		e = apperr.New(http.StatusInternalServerError, "internal_error", "something went wrong")
	}
	JSON(w, e.Status, map[string]any{"error": map[string]string{"code": e.Code, "message": e.Message}})
}

// Decode parses a JSON request body, rejecting unknown fields and oversized bodies.
func Decode(w http.ResponseWriter, r *http.Request, dst any) error {
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		return apperr.BadRequest("invalid_body", "request body is not valid JSON for this endpoint")
	}
	return nil
}
