package job

import "testing"

func TestCanTransition(t *testing.T) {
	tests := []struct {
		from, to Status
		want     bool
	}{
		{StatusBroadcasting, StatusEscalating, true},
		{StatusBroadcasting, StatusAccepted, true},
		{StatusEscalating, StatusManualFallback, true},
		{StatusEscalating, StatusAccepted, true},
		{StatusAccepted, StatusInProgress, true},
		{StatusAccepted, StatusCancelled, true},
		{StatusInProgress, StatusCompleted, true},
		{StatusInProgress, StatusCancelled, true},
		{StatusManualFallback, StatusCancelled, true},
		{StatusBroadcasting, StatusExpired, true},
		{StatusEscalating, StatusExpired, true},
		{StatusInProgress, StatusDisputed, true},
		{StatusDisputed, StatusCompleted, true},
		{StatusDisputed, StatusCancelled, true},

		{StatusAccepted, StatusDisputed, false},
		{StatusAccepted, StatusExpired, false},
		{StatusExpired, StatusAccepted, false},
		{StatusCompleted, StatusDisputed, false},

		{StatusBroadcasting, StatusInProgress, false},
		{StatusBroadcasting, StatusCompleted, false},
		{StatusAccepted, StatusCompleted, false},
		{StatusManualFallback, StatusAccepted, false},
		{StatusCompleted, StatusCancelled, false},
		{StatusCancelled, StatusBroadcasting, false},
	}
	for _, tt := range tests {
		if got := CanTransition(tt.from, tt.to); got != tt.want {
			t.Errorf("CanTransition(%s, %s) = %v, want %v", tt.from, tt.to, got, tt.want)
		}
	}
}
