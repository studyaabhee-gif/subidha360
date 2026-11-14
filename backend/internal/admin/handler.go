package admin

import (
	"encoding/csv"
	"fmt"
	"net/http"
	"strconv"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/platform/httpx"
)

// Routes registers the back office. Every route checks the admin flag in the
// database on each request, so removing an admin takes effect at once.
func (s *Service) Routes(mux *http.ServeMux, a *auth.Service) {
	s.operationRoutes(mux, a)
	mux.Handle("GET /v1/admin/overview", a.RequireAdmin(s.handleOverview))
	mux.Handle("GET /v1/admin/users", a.RequireAdmin(s.handleUsers))
	mux.Handle("GET /v1/admin/users/{id}", a.RequireAdmin(s.handleUser))
	mux.Handle("POST /v1/admin/users/{id}/suspend", a.RequireAdmin(s.handleSuspend))
	mux.Handle("POST /v1/admin/users/{id}/unsuspend", a.RequireAdmin(s.handleUnsuspend))
	mux.Handle("PUT /v1/admin/providers/{id}/verified", a.RequireAdmin(s.handleVerify))
	mux.Handle("GET /v1/admin/jobs", a.RequireAdmin(s.handleJobs))
	mux.Handle("GET /v1/admin/jobs/{id}", a.RequireAdmin(s.handleJob))
	mux.Handle("POST /v1/admin/jobs/{id}/resolve-escrow", a.RequireAdmin(s.handleResolveEscrow))
	mux.Handle("POST /v1/admin/jobs/{id}/warranty-claim/close", a.RequireAdmin(s.handleCloseClaim))
	mux.Handle("GET /v1/admin/payments", a.RequireAdmin(s.handlePayments))
	mux.Handle("GET /v1/admin/money", a.RequireAdmin(s.handleMoney))
	mux.Handle("GET /v1/admin/reports", a.RequireAdmin(s.handleReport))
	mux.Handle("GET /v1/admin/reports.csv", a.RequireAdmin(s.handleReportCSV))
	mux.Handle("GET /v1/admin/actions", a.RequireAdmin(s.handleActions))
	mux.Handle("GET /v1/admin/users/{id}/documents", a.RequireAdmin(s.handleDocuments))
	mux.Handle("GET /v1/admin/documents/{docID}", a.RequireAdmin(s.provider.ServeAnyDocument))
	mux.Handle("POST /v1/admin/users/{id}/verification", a.RequireAdmin(s.handleDecideCheck))
	mux.Handle("GET /v1/admin/withdrawals", a.RequireAdmin(s.handleWithdrawals))
	mux.Handle("POST /v1/admin/withdrawals/{id}/pay", a.RequireAdmin(s.handlePayWithdrawal))
	mux.Handle("POST /v1/admin/withdrawals/{id}/refuse", a.RequireAdmin(s.handleRefuseWithdrawal))
}

func page(r *http.Request) int {
	n, err := strconv.Atoi(r.URL.Query().Get("page"))
	if err != nil || n < 1 {
		return 1
	}
	return n
}

// pageOf is the shape of every admin list.
type pageOf[T any] struct {
	Items   []T  `json:"items"`
	Page    int  `json:"page"`
	HasMore bool `json:"has_more"`
}

func writePage[T any](w http.ResponseWriter, r *http.Request, rows []T, more bool, err error) {
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, pageOf[T]{Items: rows, Page: page(r), HasMore: more})
}

func (s *Service) handleOverview(w http.ResponseWriter, r *http.Request) {
	o, err := s.Overview(r.Context())
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, o)
}

func (s *Service) handleUsers(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	rows, more, err := s.Users(r.Context(), q.Get("q"), q.Get("filter"), page(r))
	writePage(w, r, rows, more, err)
}

func (s *Service) handleUser(w http.ResponseWriter, r *http.Request) {
	d, err := s.User(r.Context(), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, d)
}

type noteBody struct {
	Reason string `json:"reason"`
}

func (s *Service) handleSuspend(w http.ResponseWriter, r *http.Request) {
	var req noteBody
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.Suspend(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Reason); err != nil {
		httpx.Error(w, err)
		return
	}
	s.handleUser(w, r)
}

func (s *Service) handleUnsuspend(w http.ResponseWriter, r *http.Request) {
	var req noteBody
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.Unsuspend(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Reason); err != nil {
		httpx.Error(w, err)
		return
	}
	s.handleUser(w, r)
}

func (s *Service) handleVerify(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Verified bool   `json:"verified"`
		Note     string `json:"note"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.SetVerified(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Verified, req.Note); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleJobs(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	rows, more, err := s.Jobs(r.Context(), q.Get("q"), q.Get("status"), page(r))
	writePage(w, r, rows, more, err)
}

func (s *Service) handleJob(w http.ResponseWriter, r *http.Request) {
	d, err := s.Job(r.Context(), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, d)
}

func (s *Service) handleResolveEscrow(w http.ResponseWriter, r *http.Request) {
	var req struct {
		// A pointer, so a missing field is refused rather than read as 0%.
		ProviderPercent *int64 `json:"provider_percent"`
		Note            string `json:"note"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if req.ProviderPercent == nil || *req.ProviderPercent < 0 || *req.ProviderPercent > 100 {
		httpx.Error(w, apperr.BadRequest("invalid_percent", "provider_percent must be between 0 and 100"))
		return
	}
	j, err := s.ResolveEscrow(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), *req.ProviderPercent, req.Note)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, j)
}

func (s *Service) handleCloseClaim(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Note string `json:"note"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	j, err := s.CloseClaim(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Note)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, j)
}

func (s *Service) handlePayments(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	rows, more, err := s.Payments(r.Context(), q.Get("type"), q.Get("q"), page(r))
	writePage(w, r, rows, more, err)
}

func (s *Service) handleMoney(w http.ResponseWriter, r *http.Request) {
	m, err := s.Money(r.Context())
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, m)
}

func (s *Service) report(r *http.Request) (*Report, error) {
	q := r.URL.Query()
	start, end, err := ParseRange(q.Get("from"), q.Get("to"), s.now())
	if err != nil {
		return nil, err
	}
	return s.Report(r.Context(), start, end)
}

func (s *Service) handleReport(w http.ResponseWriter, r *http.Request) {
	rep, err := s.report(r)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rep)
}

// rupees writes paisa as a plain decimal that spreadsheets read as a number.
func rupees(paisa int64) string {
	sign := ""
	if paisa < 0 {
		sign, paisa = "-", -paisa
	}
	return fmt.Sprintf("%s%d.%02d", sign, paisa/100, paisa%100)
}

func (s *Service) handleReportCSV(w http.ResponseWriter, r *http.Request) {
	rep, err := s.report(r)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="subidha360-%s-to-%s.csv"`, rep.From, rep.To))
	out := csv.NewWriter(w)
	out.Write([]string{"Date", "Jobs posted", "Jobs completed", "Jobs cancelled", "New users",
		"Customer spend on finished work (Rs)", "Commission (Rs)", "Paid to providers (Rs)", "Refunds (Rs)", "Wallet top-ups (Rs)", "Withdrawals sent (Rs)"})
	row := func(label string, d Day) []string {
		return []string{label, strconv.FormatInt(d.Posted, 10), strconv.FormatInt(d.Completed, 10),
			strconv.FormatInt(d.Cancelled, 10), strconv.FormatInt(d.NewUsers, 10),
			rupees(d.GMV), rupees(d.Commission), rupees(d.Payouts), rupees(d.Refunds), rupees(d.TopUps), rupees(d.Withdrawals)}
	}
	for _, d := range rep.Days {
		out.Write(row(d.Date, d))
	}
	out.Write(row("Total", rep.Totals))
	out.Flush()
}

func (s *Service) handleActions(w http.ResponseWriter, r *http.Request) {
	rows, more, err := s.Actions(r.Context(), r.URL.Query().Get("target"), page(r))
	writePage(w, r, rows, more, err)
}

func (s *Service) handleDocuments(w http.ResponseWriter, r *http.Request) {
	rows, err := s.provider.Documents(r.Context(), r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, rows)
}

func (s *Service) handleDecideCheck(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Approve bool   `json:"approve"`
		Reason  string `json:"reason"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.DecideCheck(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Approve, req.Reason); err != nil {
		httpx.Error(w, err)
		return
	}
	s.handleUser(w, r)
}

func (s *Service) handleWithdrawals(w http.ResponseWriter, r *http.Request) {
	rows, more, err := s.Withdrawals(r.Context(), r.URL.Query().Get("status"), page(r))
	writePage(w, r, rows, more, err)
}

func (s *Service) decideWithdrawal(w http.ResponseWriter, r *http.Request, paid bool) {
	var req struct {
		Note string `json:"note"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	wd, err := s.DecideWithdrawal(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), paid, req.Note)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, wd)
}

func (s *Service) handlePayWithdrawal(w http.ResponseWriter, r *http.Request) {
	s.decideWithdrawal(w, r, true)
}

func (s *Service) handleRefuseWithdrawal(w http.ResponseWriter, r *http.Request) {
	s.decideWithdrawal(w, r, false)
}
