package safety

import (
	"slices"
	"testing"
)

func TestScan(t *testing.T) {
	cases := []struct {
		body string
		want []string
	}{
		{"I will come at 10 tomorrow", nil},
		{"The part costs Rs 1200, I will add it to the bid", nil},
		{"Call me on 9841234567", []string{ReasonContactShared}},
		{"my number is +977 984-123-4567", []string{ReasonContactShared}},
		{"98 4123 4567 is my number", []string{ReasonContactShared}},
		{"Just pay me cash when I finish", []string{ReasonOffPlatform}},
		{"Message me on WhatsApp", []string{ReasonOffPlatform}},
		{"esewa ma pathaunus", []string{ReasonOffPlatform}},
		{"नगद दिनुहोस्", []string{ReasonOffPlatform}},
		{"Send to my eSewa 9801234567 directly, pay direct", []string{ReasonContactShared, ReasonOffPlatform}},
		// Words that only contain a keyword are not flagged.
		{"The cashew tree in the yard", nil},
	}
	for _, c := range cases {
		if got := Scan(c.body); !slices.Equal(got, c.want) {
			t.Errorf("Scan(%q) = %v, want %v", c.body, got, c.want)
		}
	}
}
