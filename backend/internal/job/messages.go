package job

import (
	"context"
	"fmt"

	"subidha360/backend/internal/notify"
)

// Notification types, which the app uses to route a tap to the right screen.
const (
	noteJobBroadcast      = "job.broadcast"
	noteJobFallback       = "job.manual_fallback"
	noteJobExpired        = "job.expired"
	noteJobStarted        = "job.started"
	noteJobCompleted      = "job.completed"
	noteJobCancelled      = "job.cancelled"
	noteBidReceived       = "bid.received"
	noteBidAccepted       = "bid.accepted"
	noteConfirmNeeded     = "completion.confirm_needed"
	noteAutoReleaseWarned = "completion.auto_release_warning"
	noteDisputeRaised     = "dispute.raised"
	noteEscrowResolved    = "escrow.resolved"
	noteWarrantyClaim     = "warranty.claim"
	noteJobRescheduled    = "job.rescheduled"
)

func note(userID string, j *Job, kind, title, body string) notify.Message {
	return notify.Message{UserID: userID, JobID: j.ID, Type: kind, Title: title, Body: body}
}

// criticalNote can fall back to SMS. Reserve it for messages with a money
// consequence or a commitment, since each SMS has a real cost.
func criticalNote(userID string, j *Job, kind, title, body string) notify.Message {
	m := note(userID, j, kind, title, body)
	m.Critical = true
	return m
}

// otherParty returns the seeker if given the provider, and the reverse.
func otherParty(j *Job, userID string) string {
	if userID == j.SeekerID {
		return j.ProviderID
	}
	return j.SeekerID
}

func (s *Service) noteBroadcast(ctx context.Context, j *Job, providers []string) error {
	msgs := make([]notify.Message, len(providers))
	for i, id := range providers {
		msgs[i] = note(id, j, noteJobBroadcast, "New job nearby", "A new job matches your services. Open the app to bid.")
	}
	return s.notify.Enqueue(ctx, msgs...)
}

// noteConfirmation tells the other party about the first confirmation. For a
// seeker this is the warning that makes auto-release fair.
func (s *Service) noteConfirmation(ctx context.Context, j *Job, confirmedBy string) error {
	if confirmedBy == j.ProviderID {
		body := fmt.Sprintf("The provider marked your job as finished. Payment releases automatically in %.0f hours unless you raise a dispute.",
			s.opts.AutoReleaseAfter.Hours())
		return s.notify.Enqueue(ctx, criticalNote(j.SeekerID, j, noteConfirmNeeded, "Confirm your job", body))
	}
	return s.notify.Enqueue(ctx, note(j.ProviderID, j, noteConfirmNeeded, "Job confirmed", "The seeker confirmed the job is finished. Please confirm too."))
}

func (s *Service) noteCompleted(ctx context.Context, j *Job) error {
	return s.notify.Enqueue(ctx,
		note(j.SeekerID, j, noteJobCompleted, "Job completed", "Your job is complete and the payment has been released."),
		note(j.ProviderID, j, noteJobCompleted, "Payment received", "The job is complete and your earnings are in your wallet."),
	)
}

func (s *Service) noteCancelled(ctx context.Context, j *Job, cancelledBy string, held bool) error {
	if j.ProviderID == "" {
		return nil // Nobody else was committed to this job.
	}
	body := "The other party cancelled this job."
	switch {
	case held:
		body = fmt.Sprintf("The seeker cancelled during work. The payment is under review for up to %.0f hours.", s.opts.EscrowReviewWindow.Hours())
	case cancelledBy == j.ProviderID:
		body = "The provider cancelled this job. Your payment has been refunded to your wallet."
	}
	return s.notify.Enqueue(ctx, criticalNote(otherParty(j, cancelledBy), j, noteJobCancelled, "Job cancelled", body))
}

func (s *Service) noteRescheduled(ctx context.Context, j *Job, date, slot string) error {
	when := "as soon as possible"
	if date != "" {
		when = fmt.Sprintf("%s, %s", date, slot)
	}
	return s.notify.Enqueue(ctx, criticalNote(j.ProviderID, j, noteJobRescheduled, "Job time changed",
		"The customer moved this job to "+when+". Check that it still works for you."))
}

func (s *Service) noteResolved(ctx context.Context, j *Job, providerPercent int64) error {
	body := fmt.Sprintf("The held payment was settled: %d%% to the provider, the rest to the seeker. Check your wallet.", providerPercent)
	return s.notify.Enqueue(ctx,
		criticalNote(j.SeekerID, j, noteEscrowResolved, "Payment settled", body),
		criticalNote(j.ProviderID, j, noteEscrowResolved, "Payment settled", body),
	)
}
