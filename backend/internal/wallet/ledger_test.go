package wallet

import (
	"context"
	"testing"
)

func TestCommissionRoundsDown(t *testing.T) {
	tests := []struct{ amount, bps, want int64 }{
		{50000, 1000, 5000},
		{99, 1000, 9},
		{1, 1000, 0},
		{50000, 0, 0},
		{50000, 10000, 50000},
	}
	for _, tt := range tests {
		if got := Commission(tt.amount, tt.bps); got != tt.want {
			t.Errorf("Commission(%d, %d) = %d, want %d", tt.amount, tt.bps, got, tt.want)
		}
	}
}

func TestPostRejectsInvalidGroupsBeforeTouchingTheDatabase(t *testing.T) {
	l := &Ledger{} // A nil client would panic if validation let these through.
	tests := map[string][]Leg{
		"unbalanced": {{Account: "a", Amount: 5}, {Account: "b", Amount: -4}},
		"single leg": {{Account: "a", Amount: 0}},
		"empty":      nil,
		"zero leg":   {{Account: "a", Amount: 0}, {Account: "b", Amount: 0}},
	}
	for name, legs := range tests {
		if err := l.Post(context.Background(), "k", "", legs); err == nil {
			t.Errorf("%s: expected error", name)
		}
	}
}
