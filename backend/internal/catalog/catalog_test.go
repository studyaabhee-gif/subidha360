package catalog

import "testing"

func TestCatalogIsWellFormed(t *testing.T) {
	seen := map[string]bool{}
	for _, c := range All() {
		if c.Name == "" || c.Slug == "" || len(c.Services) == 0 {
			t.Errorf("category %d is incomplete", c.ID)
		}
		for _, s := range c.Services {
			if seen[s.ID] {
				t.Errorf("duplicate service id %s", s.ID)
			}
			seen[s.ID] = true
			if s.CategoryID != c.ID {
				t.Errorf("%s has category %d, want %d", s.ID, s.CategoryID, c.ID)
			}
			if s.GuideFrom <= 0 || s.GuideTo < s.GuideFrom {
				t.Errorf("%s has a bad guide price", s.ID)
			}
			if len(s.Symptoms) == 0 || len(s.Includes) == 0 {
				t.Errorf("%s needs symptoms and includes", s.ID)
			}
		}
	}
}

func TestValidation(t *testing.T) {
	if !ValidCategory(1) || ValidCategory(999) {
		t.Fatal("ValidCategory")
	}
	if !ValidService(1, "tap-leak") || ValidService(2, "tap-leak") || ValidService(1, "nope") {
		t.Fatal("ValidService")
	}
}
