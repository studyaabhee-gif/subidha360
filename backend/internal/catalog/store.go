package catalog

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"slices"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
)

// Settings are site-wide values admins can change without a release.
type Settings struct {
	// HelplinePhone is shown in the app for people who need to talk to us.
	HelplinePhone string `bson:"helpline_phone" json:"helpline_phone"`
	// HelplineHours says when someone answers, such as "9 AM to 6 PM, Sun to Fri".
	HelplineHours string `bson:"helpline_hours" json:"helpline_hours"`
	// Company details shown in the site footer and the legal pages. Nepal
	// requires businesses to show their registration and PAN.
	CompanyName    string `bson:"company_name" json:"company_name"`
	RegistrationNo string `bson:"registration_no" json:"registration_no"`
	PAN            string `bson:"pan" json:"pan"`
	Address        string `bson:"address" json:"address"`
	Email          string `bson:"email" json:"email"`
}

// The live catalogue. Reads are far more common than edits, so every request
// reads this copy and edits replace it whole.
var (
	mu       sync.RWMutex
	current  = withCategoryIDs(defaults)
	settings Settings
)

func withCategoryIDs(cats []Category) []Category {
	out := make([]Category, len(cats))
	for i, c := range cats {
		c.Services = slices.Clone(c.Services)
		for j := range c.Services {
			c.Services[j].CategoryID = c.ID
		}
		out[i] = c
	}
	return out
}

// All returns every category with every service, hidden ones included.
func All() []Category {
	mu.RLock()
	defer mu.RUnlock()
	return withCategoryIDs(current)
}

// Public returns what customers may book: hidden services are left out.
func Public() []Category {
	out := All()
	for i := range out {
		out[i].Services = slices.DeleteFunc(out[i].Services, func(s Service) bool { return s.Hidden })
	}
	return out
}

// CurrentSettings returns the site settings.
func CurrentSettings() Settings {
	mu.RLock()
	defer mu.RUnlock()
	return settings
}

// ValidCategory reports whether id is a real category.
func ValidCategory(id int) bool {
	return CategoryName(id) != ""
}

// CategoryName returns a category's English name, or "" if unknown.
func CategoryName(id int) string {
	mu.RLock()
	defer mu.RUnlock()
	for _, c := range current {
		if c.ID == id {
			return c.Name
		}
	}
	return ""
}

// ValidService reports whether a bookable service exists within a category.
func ValidService(categoryID int, serviceID string) bool {
	mu.RLock()
	defer mu.RUnlock()
	for _, c := range current {
		if c.ID != categoryID {
			continue
		}
		for _, s := range c.Services {
			if s.ID == serviceID && !s.Hidden {
				return true
			}
		}
	}
	return false
}

// Routes registers the public catalogue and settings, so visitors can browse
// before login.
func Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /v1/catalog", func(w http.ResponseWriter, _ *http.Request) {
		httpx.JSON(w, http.StatusOK, Public())
	})
	mux.HandleFunc("GET /v1/settings", func(w http.ResponseWriter, _ *http.Request) {
		httpx.JSON(w, http.StatusOK, CurrentSettings())
	})
}

const docID = "catalog"

// stored is the single document that holds the catalogue. Version guards
// against two admins saving over each other.
type stored struct {
	ID         string     `bson:"_id"`
	Categories []Category `bson:"categories"`
	Settings   Settings   `bson:"settings"`
	Version    int64      `bson:"version"`
	UpdatedAt  time.Time  `bson:"updated_at"`
}

// Store saves the catalogue in MongoDB.
type Store struct {
	col *mongo.Collection
}

func NewStore(db *mongo.Database) *Store {
	return &Store{col: db.Collection(mongodb.Catalog)}
}

// Load reads the saved catalogue, saving the built-in one on first run.
func (s *Store) Load(ctx context.Context) error {
	_, err := s.col.UpdateOne(ctx, bson.M{"_id": docID},
		bson.M{"$setOnInsert": stored{ID: docID, Categories: withCategoryIDs(defaults), UpdatedAt: time.Now().UTC()}},
		options.UpdateOne().SetUpsert(true))
	if err != nil && !mongo.IsDuplicateKeyError(err) {
		return fmt.Errorf("seed catalog: %w", err)
	}
	doc, err := s.read(ctx)
	if err != nil {
		return err
	}
	mu.Lock()
	current, settings = withCategoryIDs(doc.Categories), doc.Settings
	mu.Unlock()
	return nil
}

func (s *Store) read(ctx context.Context) (*stored, error) {
	var doc stored
	if err := s.col.FindOne(ctx, bson.M{"_id": docID}).Decode(&doc); err != nil {
		return nil, fmt.Errorf("read catalog: %w", err)
	}
	return &doc, nil
}

// Refresh reloads the catalogue now and then, so every server instance picks
// up edits made through another one.
func (s *Store) Refresh(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if err := s.Load(ctx); err != nil {
				slog.Warn("catalog refresh failed", "err", err)
			}
		}
	}
}

// edit applies a change to the saved catalogue, retrying if another admin
// saved at the same moment.
func (s *Store) edit(ctx context.Context, change func(doc *stored) error) error {
	for range 5 {
		doc, err := s.read(ctx)
		if err != nil {
			return err
		}
		if err := change(doc); err != nil {
			return err
		}
		res, err := s.col.UpdateOne(ctx, bson.M{"_id": docID, "version": doc.Version}, bson.M{"$set": bson.M{
			"categories": doc.Categories,
			"settings":   doc.Settings,
			"version":    doc.Version + 1,
			"updated_at": time.Now().UTC(),
		}})
		if err != nil {
			return fmt.Errorf("save catalog: %w", err)
		}
		if res.MatchedCount == 1 {
			return s.Load(ctx)
		}
	}
	return errors.New("save catalog: too many concurrent edits")
}

var (
	serviceIDPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$`)
	maxGuidePaisa    = int64(10_00_000 * 100)
)

func cleanList(items []string, most, longest int, what string) ([]string, error) {
	out := []string{}
	for _, item := range items {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		if utf8.RuneCountInString(item) > longest {
			return nil, apperr.BadRequest("invalid_service", fmt.Sprintf("keep each %s under %d characters", what, longest))
		}
		if !slices.Contains(out, item) {
			out = append(out, item)
		}
	}
	if len(out) == 0 || len(out) > most {
		return nil, apperr.BadRequest("invalid_service", fmt.Sprintf("list 1 to %d %ss", most, what))
	}
	return out, nil
}

func textBetween(s string, least, most int, message string) (string, error) {
	s = strings.TrimSpace(s)
	if n := utf8.RuneCountInString(s); n < least || n > most {
		return "", apperr.BadRequest("invalid_service", message)
	}
	return s, nil
}

// clean checks a service an admin wants to save.
func (in *Service) clean() error {
	var err error
	if !serviceIDPattern.MatchString(in.ID) {
		return apperr.BadRequest("invalid_service", "the ID uses 3 to 40 lowercase letters, digits and dashes, like tap-leak")
	}
	if in.Name, err = textBetween(in.Name, 3, 60, "the name must be 3 to 60 characters"); err != nil {
		return err
	}
	if in.Summary, err = textBetween(in.Summary, 10, 160, "the summary must be 10 to 160 characters"); err != nil {
		return err
	}
	if in.NameNe, err = textBetween(in.NameNe, 0, 60, "the Nepali name must be under 60 characters"); err != nil {
		return err
	}
	if in.SummaryNe, err = textBetween(in.SummaryNe, 0, 160, "the Nepali summary must be under 160 characters"); err != nil {
		return err
	}
	if in.Symptoms, err = cleanList(in.Symptoms, 12, 40, "search phrase"); err != nil {
		return err
	}
	if in.Includes, err = cleanList(in.Includes, 8, 60, "included item"); err != nil {
		return err
	}
	if in.GuideFrom < 100*100 || in.GuideTo < in.GuideFrom || in.GuideTo > maxGuidePaisa {
		return apperr.BadRequest("invalid_price", "guide prices run from at least Rs 100 up to Rs 10 lakh, lowest first")
	}
	return nil
}

// SaveService adds a service or replaces one with the same ID. A service
// can move between categories; its ID stays the same.
func (s *Store) SaveService(ctx context.Context, in Service) error {
	if err := in.clean(); err != nil {
		return err
	}
	return s.edit(ctx, func(doc *stored) error {
		target := slices.IndexFunc(doc.Categories, func(c Category) bool { return c.ID == in.CategoryID })
		if target < 0 {
			return apperr.BadRequest("invalid_category", "choose a valid service category")
		}
		for i := range doc.Categories {
			doc.Categories[i].Services = slices.DeleteFunc(doc.Categories[i].Services, func(old Service) bool {
				return old.ID == in.ID && doc.Categories[i].ID != in.CategoryID
			})
		}
		services := doc.Categories[target].Services
		if i := slices.IndexFunc(services, func(old Service) bool { return old.ID == in.ID }); i >= 0 {
			services[i] = in
		} else {
			doc.Categories[target].Services = append(services, in)
		}
		return nil
	})
}

// SaveCategory changes a category's text. Categories themselves are fixed.
func (s *Store) SaveCategory(ctx context.Context, id int, name, tagline, nameNe, taglineNe string) error {
	var err error
	if name, err = textBetween(name, 3, 40, "the name must be 3 to 40 characters"); err != nil {
		return err
	}
	if tagline, err = textBetween(tagline, 3, 80, "the tagline must be 3 to 80 characters"); err != nil {
		return err
	}
	if nameNe, err = textBetween(nameNe, 0, 40, "the Nepali name must be under 40 characters"); err != nil {
		return err
	}
	if taglineNe, err = textBetween(taglineNe, 0, 80, "the Nepali tagline must be under 80 characters"); err != nil {
		return err
	}
	return s.edit(ctx, func(doc *stored) error {
		i := slices.IndexFunc(doc.Categories, func(c Category) bool { return c.ID == id })
		if i < 0 {
			return apperr.NotFound("category_not_found", "category not found")
		}
		c := &doc.Categories[i]
		c.Name, c.Tagline, c.NameNe, c.TaglineNe = name, tagline, nameNe, taglineNe
		return nil
	})
}

var phonePattern = regexp.MustCompile(`^[0-9+][0-9 -]{5,18}$`)

var (
	panPattern   = regexp.MustCompile(`^\d{9}$`)
	emailPattern = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)
)

// SaveSettings changes the site settings.
func (s *Store) SaveSettings(ctx context.Context, in Settings) error {
	in.HelplinePhone = strings.TrimSpace(in.HelplinePhone)
	in.HelplineHours = strings.TrimSpace(in.HelplineHours)
	if in.HelplinePhone != "" && !phonePattern.MatchString(in.HelplinePhone) {
		return apperr.BadRequest("invalid_phone", "enter a phone number, like 01-5970000 or 9801234567")
	}
	if utf8.RuneCountInString(in.HelplineHours) > 80 {
		return apperr.BadRequest("invalid_hours", "keep the hours under 80 characters")
	}
	for _, f := range []*string{&in.CompanyName, &in.RegistrationNo, &in.PAN, &in.Address, &in.Email} {
		*f = strings.TrimSpace(*f)
	}
	if in.PAN != "" && !panPattern.MatchString(in.PAN) {
		return apperr.BadRequest("invalid_pan", "a PAN is 9 digits")
	}
	if in.Email != "" && !emailPattern.MatchString(in.Email) {
		return apperr.BadRequest("invalid_email", "enter a valid email address")
	}
	if utf8.RuneCountInString(in.CompanyName) > 100 || utf8.RuneCountInString(in.RegistrationNo) > 40 || utf8.RuneCountInString(in.Address) > 160 {
		return apperr.BadRequest("invalid_company", "company details are too long")
	}
	return s.edit(ctx, func(doc *stored) error {
		doc.Settings = in
		return nil
	})
}
