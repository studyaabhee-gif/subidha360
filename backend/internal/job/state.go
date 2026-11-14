package job

// Status is a position in the job state machine (spec section 4.1).
type Status string

const (
	StatusBroadcasting   Status = "BROADCASTING"
	StatusEscalating     Status = "ESCALATING"
	StatusManualFallback Status = "MANUAL_FALLBACK"
	StatusAccepted       Status = "ACCEPTED"
	StatusInProgress     Status = "IN_PROGRESS"
	StatusCompleted      Status = "COMPLETED"
	StatusCancelled      Status = "CANCELLED"
	// StatusDisputed pauses escrow release until an admin decides the split.
	StatusDisputed Status = "DISPUTED"
	// StatusExpired means the seeker never picked a bid. Unlike a cancellation
	// it moves no money and triggers no penalty review.
	StatusExpired Status = "EXPIRED"
)

// OpenStatuses are the states in which a job can receive and accept bids.
var OpenStatuses = []Status{StatusBroadcasting, StatusEscalating}

var transitions = map[Status][]Status{
	StatusBroadcasting:   {StatusEscalating, StatusAccepted, StatusCancelled, StatusExpired},
	StatusEscalating:     {StatusManualFallback, StatusAccepted, StatusCancelled, StatusExpired},
	StatusManualFallback: {StatusCancelled},
	StatusAccepted:       {StatusInProgress, StatusCancelled},
	StatusInProgress:     {StatusCompleted, StatusCancelled, StatusDisputed},
	StatusDisputed:       {StatusCompleted, StatusCancelled},
}

// CanTransition reports whether the state machine allows moving from one status to another.
func CanTransition(from, to Status) bool {
	for _, s := range transitions[from] {
		if s == to {
			return true
		}
	}
	return false
}
