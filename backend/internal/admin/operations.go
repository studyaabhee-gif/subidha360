package admin

import (
	"context"
	"fmt"
	"net/http"
	"strconv"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/catalog"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/safety"
	"subidha360/backend/internal/support"
)

// Audit actions for support, safety and the catalogue.
const (
	ActionCloseThread  = "support.close"
	ActionReviewFlag   = "flag.review"
	ActionSaveService  = "catalog.service"
	ActionSaveCategory = "catalog.category"
	ActionSaveSettings = "settings.save"
	TargetThread       = "support"
	TargetCatalog      = "catalog"
)

func (s *Service) operationRoutes(mux *http.ServeMux, a *auth.Service) {
	mux.Handle("GET /v1/admin/support", a.RequireAdmin(s.handleInbox))
	mux.Handle("GET /v1/admin/support/{id}", a.RequireAdmin(s.handleThread))
	mux.Handle("POST /v1/admin/support/{id}/messages", a.RequireAdmin(s.handleThreadReply))
	mux.Handle("POST /v1/admin/support/{id}/close", a.RequireAdmin(s.handleThreadClose))
	mux.Handle("GET /v1/admin/flags", a.RequireAdmin(s.handleFlags))
	mux.Handle("POST /v1/admin/flags/{id}/review", a.RequireAdmin(s.handleReviewFlag))
	mux.Handle("GET /v1/admin/catalog", a.RequireAdmin(s.handleCatalog))
	mux.Handle("PUT /v1/admin/catalog/services/{id}", a.RequireAdmin(s.handleSaveService))
	mux.Handle("PUT /v1/admin/catalog/categories/{id}", a.RequireAdmin(s.handleSaveCategory))
	mux.Handle("PUT /v1/admin/settings", a.RequireAdmin(s.handleSaveSettings))
	mux.Handle("GET /v1/admin/traffic", a.RequireAdmin(s.handleTraffic))
}

func skip(r *http.Request) int64 { return int64((page(r) - 1) * pageSize) }

// ThreadRow is a support conversation with the person who wrote.
type ThreadRow struct {
	support.Thread
	Person Person `json:"person"`
}

func (s *Service) threadRows(ctx context.Context, rows []support.Thread) ([]ThreadRow, error) {
	ids := make([]string, len(rows))
	for i := range rows {
		ids[i] = rows[i].UserID
	}
	people, err := s.names(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make([]ThreadRow, len(rows))
	for i, t := range rows {
		p := people[t.UserID]
		p.ID = t.UserID
		out[i] = ThreadRow{Thread: t, Person: p}
	}
	return out, nil
}

func (s *Service) handleInbox(w http.ResponseWriter, r *http.Request) {
	rows, err := s.support.Inbox(r.Context(), r.URL.Query().Get("status"), skip(r), pageSize+1)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	more := len(rows) > pageSize
	if more {
		rows = rows[:pageSize]
	}
	out, err := s.threadRows(r.Context(), rows)
	writePage(w, r, out, more, err)
}

func (s *Service) writeThread(w http.ResponseWriter, r *http.Request, v *support.ThreadView) {
	rows, err := s.threadRows(r.Context(), []support.Thread{v.Thread})
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"thread": rows[0], "messages": v.Messages})
}

func (s *Service) handleThread(w http.ResponseWriter, r *http.Request) {
	v, err := s.support.View(r.Context(), "", r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	s.writeThread(w, r, v)
}

func (s *Service) handleThreadReply(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Body string `json:"body"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	v, err := s.support.Reply(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Body, true)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	s.writeThread(w, r, v)
}

func (s *Service) handleThreadClose(w http.ResponseWriter, r *http.Request) {
	t, err := s.support.Close(r.Context(), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.record(r.Context(), auth.UserID(r.Context()), ActionCloseThread, TargetUser, t.UserID, t.Subject); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, t)
}

// FlagRow is a flag with the people involved.
type FlagRow struct {
	safety.Flag
	Reporter Person `json:"reporter"`
	Reported Person `json:"reported"`
}

func (s *Service) flagRows(ctx context.Context, rows []safety.Flag) ([]FlagRow, error) {
	ids := make([]string, 0, len(rows)*2)
	for _, f := range rows {
		ids = append(ids, f.ReporterID, f.ReportedID)
	}
	people, err := s.names(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make([]FlagRow, len(rows))
	for i, f := range rows {
		reporter := people[f.ReporterID]
		reporter.ID = f.ReporterID
		if f.ReporterID == safety.ReporterSystem {
			reporter.Name = "Automatic check"
		}
		reported := people[f.ReportedID]
		reported.ID = f.ReportedID
		out[i] = FlagRow{Flag: f, Reporter: reporter, Reported: reported}
	}
	return out, nil
}

func (s *Service) handleFlags(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	rows, err := s.safety.List(r.Context(), q.Get("status"), q.Get("person"), skip(r), pageSize+1)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	more := len(rows) > pageSize
	if more {
		rows = rows[:pageSize]
	}
	out, err := s.flagRows(r.Context(), rows)
	writePage(w, r, out, more, err)
}

func (s *Service) handleReviewFlag(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Outcome string `json:"outcome"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	adminID := auth.UserID(r.Context())
	f, err := s.safety.Review(r.Context(), adminID, r.PathValue("id"), req.Outcome)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	detail := fmt.Sprintf("%s: %s", f.Reason, f.Outcome)
	if err := s.record(r.Context(), adminID, ActionReviewFlag, TargetUser, f.ReportedID, detail); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, f)
}

func (s *Service) handleCatalog(w http.ResponseWriter, r *http.Request) {
	httpx.JSON(w, http.StatusOK, map[string]any{"categories": catalog.All(), "settings": catalog.CurrentSettings()})
}

func (s *Service) handleSaveService(w http.ResponseWriter, r *http.Request) {
	var req catalog.Service
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	req.ID = r.PathValue("id")
	if err := s.catalog.SaveService(r.Context(), req); err != nil {
		httpx.Error(w, err)
		return
	}
	detail := fmt.Sprintf("%s, Rs %d to %d", req.Name, req.GuideFrom/100, req.GuideTo/100)
	if req.Hidden {
		detail += ", hidden"
	}
	if err := s.record(r.Context(), auth.UserID(r.Context()), ActionSaveService, TargetCatalog, req.ID, detail); err != nil {
		httpx.Error(w, err)
		return
	}
	s.handleCatalog(w, r)
}

func (s *Service) handleSaveCategory(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		httpx.Error(w, apperr.NotFound("category_not_found", "category not found"))
		return
	}
	var req struct {
		Name      string `json:"name"`
		Tagline   string `json:"tagline"`
		NameNe    string `json:"name_ne"`
		TaglineNe string `json:"tagline_ne"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.catalog.SaveCategory(r.Context(), id, req.Name, req.Tagline, req.NameNe, req.TaglineNe); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.record(r.Context(), auth.UserID(r.Context()), ActionSaveCategory, TargetCatalog, strconv.Itoa(id), req.Name); err != nil {
		httpx.Error(w, err)
		return
	}
	s.handleCatalog(w, r)
}

func (s *Service) handleSaveSettings(w http.ResponseWriter, r *http.Request) {
	var req catalog.Settings
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.catalog.SaveSettings(r.Context(), req); err != nil {
		httpx.Error(w, err)
		return
	}
	detail := fmt.Sprintf("Helpline %q, %q", req.HelplinePhone, req.HelplineHours)
	if err := s.record(r.Context(), auth.UserID(r.Context()), ActionSaveSettings, TargetCatalog, "settings", detail); err != nil {
		httpx.Error(w, err)
		return
	}
	s.handleCatalog(w, r)
}

// Risk is a quick read on whether an account needs a closer look.
type Risk struct {
	FlagsOpen  int64 `json:"flags_open"`
	FlagsTotal int64 `json:"flags_total"`
	// Disputes counts jobs this person was on that went to dispute.
	Disputes int64 `json:"disputes"`
	// Cancellations counts jobs this person cancelled after being matched.
	Cancellations int64 `json:"cancellations"`
}

func (s *Service) risk(ctx context.Context, id string) (*Risk, error) {
	r := &Risk{}
	var err error
	if r.FlagsOpen, r.FlagsTotal, err = s.safety.Counts(ctx, id); err != nil {
		return nil, err
	}
	involved := bson.A{bson.M{"seeker_id": id}, bson.M{"provider_id": id}}
	counts := []struct {
		filter bson.M
		dst    *int64
	}{
		{bson.M{"$or": involved, "dispute": bson.M{"$exists": true}}, &r.Disputes},
		{bson.M{"cancellation.cancelled_by": id, "provider_id": bson.M{"$exists": true}}, &r.Cancellations},
	}
	for _, c := range counts {
		n, err := s.jobs.CountDocuments(ctx, c.filter)
		if err != nil {
			return nil, fmt.Errorf("count risk: %w", err)
		}
		*c.dst = n
	}
	return r, nil
}

func (s *Service) handleTraffic(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	start, end, err := ParseRange(q.Get("from"), q.Get("to"), s.now())
	if err != nil {
		httpx.Error(w, err)
		return
	}
	t, err := s.analytics.Report(r.Context(), start.Format(dayLayout), end.Format(dayLayout))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, t)
}
