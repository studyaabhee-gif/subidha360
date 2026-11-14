package httpx

import (
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"net/http"
	"runtime/debug"
	"time"
)

// statusWriter remembers the status code for the access log.
type statusWriter struct {
	http.ResponseWriter
	status int
	bytes  int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func (w *statusWriter) Write(b []byte) (int, error) {
	if w.status == 0 {
		w.status = http.StatusOK
	}
	n, err := w.ResponseWriter.Write(b)
	w.bytes += n
	return n, err
}

func newRequestID() string {
	b := make([]byte, 8)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// Observe gives every request an ID, recovers from panics so one bad request
// cannot take the server down, and logs each request. The ID is returned in
// X-Request-ID so a person reporting a problem can quote it, and support can
// find the matching log line.
func Observe(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		id := newRequestID()
		w.Header().Set("X-Request-ID", id)
		w.Header().Set("X-Content-Type-Options", "nosniff")
		sw := &statusWriter{ResponseWriter: w}
		defer func() {
			if p := recover(); p != nil {
				slog.Error("panic", "request_id", id, "method", r.Method, "path", r.URL.Path, "panic", p, "stack", string(debug.Stack()))
				if sw.status == 0 {
					JSON(sw, http.StatusInternalServerError, map[string]any{"error": map[string]string{
						"code": "internal_error", "message": "something went wrong",
					}})
				}
			}
			level := slog.LevelInfo
			if sw.status >= 500 {
				level = slog.LevelError
			}
			// Only the path is logged: query strings can hold search text.
			slog.Log(r.Context(), level, "request", "request_id", id, "method", r.Method, "path", r.URL.Path,
				"status", sw.status, "bytes", sw.bytes, "ms", time.Since(start).Milliseconds())
		}()
		next.ServeHTTP(sw, r)
	})
}
