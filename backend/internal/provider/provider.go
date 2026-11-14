// Package provider holds what a provider manages about themselves beyond the
// basic profile: identity documents, a gallery of past work and the hours
// they take jobs.
package provider

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/job"
	"subidha360/backend/internal/platform/mongodb"
	"subidha360/backend/internal/user"
)

// Document kinds. A check needs both sides of the citizenship card;
// certificates are optional extras.
const (
	DocCitizenshipFront = "citizenship_front"
	DocCitizenshipBack  = "citizenship_back"
	DocCertificate      = "certificate"
)

const (
	maxFileBytes      = 5 << 20
	maxCertificates   = 5
	maxGalleryPhotos  = 12
	maxCaptionLength  = 120
	maxDaysOff        = 60
	daysOffHorizon    = 365
	maxLabelLength    = 80
	nepalOffsetSecond = 5*3600 + 45*60
)

var (
	imageTypes    = []string{"image/jpeg", "image/png", "image/webp"}
	documentTypes = []string{"image/jpeg", "image/png", "image/webp", "application/pdf"}
	nepal         = time.FixedZone("NPT", nepalOffsetSecond)
)

// Document is an identity document or certificate. Data is never sent in
// lists; it has its own route.
type Document struct {
	ID        string    `bson:"_id" json:"id"`
	UserID    string    `bson:"user_id" json:"-"`
	Kind      string    `bson:"kind" json:"kind"`
	Label     string    `bson:"label,omitempty" json:"label,omitempty"`
	Type      string    `bson:"type" json:"type"`
	Size      int       `bson:"size" json:"size"`
	Data      []byte    `bson:"data" json:"-"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
}

// GalleryPhoto is a public picture of a provider's past work.
type GalleryPhoto struct {
	ID        string    `bson:"_id" json:"id"`
	UserID    string    `bson:"user_id" json:"-"`
	Caption   string    `bson:"caption,omitempty" json:"caption,omitempty"`
	Type      string    `bson:"type" json:"-"`
	Data      []byte    `bson:"data" json:"-"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
}

type Service struct {
	client *mongo.Client
	docs   *mongo.Collection
	photos *mongo.Collection
	users  *user.Repo
	now    func() time.Time
}

func NewService(client *mongo.Client, db *mongo.Database, users *user.Repo) *Service {
	return &Service{
		client: client,
		docs:   db.Collection(mongodb.ProviderDocuments),
		photos: db.Collection(mongodb.ProviderPhotos),
		users:  users,
		now:    func() time.Time { return time.Now().UTC() },
	}
}

func (s *Service) providerFor(ctx context.Context, id string) (*user.User, error) {
	u, err := s.users.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if !u.HasProviderProfile {
		return nil, apperr.Conflict("no_provider_profile", "create a provider profile first")
	}
	return u, nil
}

func checkFile(data []byte, allowed []string) (string, error) {
	if len(data) == 0 {
		return "", apperr.BadRequest("empty_file", "the file is empty")
	}
	if len(data) > maxFileBytes {
		return "", apperr.BadRequest("file_too_large", "files must be 5 MB or smaller")
	}
	kind := http.DetectContentType(data)
	if !slices.Contains(allowed, kind) {
		return "", apperr.BadRequest("invalid_file", "use a JPEG, PNG or WebP photo, or a PDF")
	}
	return kind, nil
}

// AddDocument stores a document. A new side of the citizenship card replaces
// the old one, and changes the documents behind any finished check, so that
// check is cleared and must be submitted again.
func (s *Service) AddDocument(ctx context.Context, userID, kind, label string, data []byte) (*Document, error) {
	if kind != DocCitizenshipFront && kind != DocCitizenshipBack && kind != DocCertificate {
		return nil, apperr.BadRequest("invalid_kind", "unknown document kind")
	}
	label = strings.TrimSpace(label)
	if utf8.RuneCountInString(label) > maxLabelLength {
		return nil, apperr.BadRequest("invalid_label", "keep the name under 80 characters")
	}
	allowed := documentTypes
	if kind != DocCertificate {
		// A photo of the card is what admins compare with the person.
		allowed = imageTypes
	}
	fileType, err := checkFile(data, allowed)
	if err != nil {
		return nil, err
	}
	d := &Document{ID: uuid.NewString(), UserID: userID, Kind: kind, Label: label, Type: fileType, Size: len(data), Data: data, CreatedAt: s.now()}
	err = mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		u, err := s.providerFor(ctx, userID)
		if err != nil {
			return err
		}
		if u.Verification != nil && u.Verification.Status == user.CheckPending {
			return apperr.Conflict("check_in_progress", "wait for the current check to finish before changing documents")
		}
		if kind == DocCertificate {
			n, err := s.docs.CountDocuments(ctx, bson.M{"user_id": userID, "kind": DocCertificate})
			if err != nil {
				return fmt.Errorf("count certificates: %w", err)
			}
			if n >= maxCertificates {
				return apperr.Conflict("too_many_certificates", fmt.Sprintf("you can add up to %d certificates", maxCertificates))
			}
		} else {
			if _, err := s.docs.DeleteMany(ctx, bson.M{"user_id": userID, "kind": kind}); err != nil {
				return fmt.Errorf("replace document: %w", err)
			}
			if err := s.users.ResetCheck(ctx, userID); err != nil {
				return err
			}
		}
		if _, err := s.docs.InsertOne(ctx, d); err != nil {
			return fmt.Errorf("insert document: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return d, nil
}

// Documents lists a provider's documents without their contents.
func (s *Service) Documents(ctx context.Context, userID string) ([]Document, error) {
	cur, err := s.docs.Find(ctx, bson.M{"user_id": userID},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}}).SetProjection(bson.M{"data": 0}))
	if err != nil {
		return nil, fmt.Errorf("find documents: %w", err)
	}
	rows := []Document{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read documents: %w", err)
	}
	return rows, nil
}

// Document returns one document with its contents. ownerID limits it to that
// owner's documents; admins pass "".
func (s *Service) Document(ctx context.Context, ownerID, id string) (*Document, error) {
	filter := bson.M{"_id": id}
	if ownerID != "" {
		filter["user_id"] = ownerID
	}
	var d Document
	err := s.docs.FindOne(ctx, filter).Decode(&d)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, apperr.NotFound("document_not_found", "document not found")
	}
	if err != nil {
		return nil, fmt.Errorf("load document: %w", err)
	}
	return &d, nil
}

// DeleteDocument removes a document the provider no longer wants kept.
func (s *Service) DeleteDocument(ctx context.Context, userID, id string) error {
	return mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		u, err := s.users.Get(ctx, userID)
		if err != nil {
			return err
		}
		if u.Verification != nil && u.Verification.Status == user.CheckPending {
			return apperr.Conflict("check_in_progress", "wait for the current check to finish before changing documents")
		}
		var d Document
		err = s.docs.FindOneAndDelete(ctx, bson.M{"_id": id, "user_id": userID}).Decode(&d)
		if errors.Is(err, mongo.ErrNoDocuments) {
			return apperr.NotFound("document_not_found", "document not found")
		}
		if err != nil {
			return fmt.Errorf("delete document: %w", err)
		}
		if d.Kind != DocCertificate {
			return s.users.ResetCheck(ctx, userID)
		}
		return nil
	})
}

// SubmitCheck sends a provider's documents to admins. Both sides of the
// citizenship card are required.
func (s *Service) SubmitCheck(ctx context.Context, userID string) error {
	return mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		if _, err := s.providerFor(ctx, userID); err != nil {
			return err
		}
		for _, kind := range []string{DocCitizenshipFront, DocCitizenshipBack} {
			n, err := s.docs.CountDocuments(ctx, bson.M{"user_id": userID, "kind": kind})
			if err != nil {
				return fmt.Errorf("count documents: %w", err)
			}
			if n == 0 {
				return apperr.BadRequest("documents_missing", "add photos of both sides of your citizenship card first")
			}
		}
		return s.users.SubmitCheck(ctx, userID, s.now())
	})
}

// AddPhoto adds a picture to a provider's public gallery.
func (s *Service) AddPhoto(ctx context.Context, userID, caption string, data []byte) (*GalleryPhoto, error) {
	caption = strings.TrimSpace(caption)
	if utf8.RuneCountInString(caption) > maxCaptionLength {
		return nil, apperr.BadRequest("invalid_caption", "keep the caption under 120 characters")
	}
	kind, err := checkFile(data, imageTypes)
	if err != nil {
		return nil, err
	}
	p := &GalleryPhoto{ID: uuid.NewString(), UserID: userID, Caption: caption, Type: kind, Data: data, CreatedAt: s.now()}
	err = mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		if _, err := s.providerFor(ctx, userID); err != nil {
			return err
		}
		n, err := s.photos.CountDocuments(ctx, bson.M{"user_id": userID})
		if err != nil {
			return fmt.Errorf("count photos: %w", err)
		}
		if n >= maxGalleryPhotos {
			return apperr.Conflict("too_many_photos", fmt.Sprintf("your gallery can hold up to %d photos", maxGalleryPhotos))
		}
		if _, err := s.photos.InsertOne(ctx, p); err != nil {
			return fmt.Errorf("insert photo: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return p, nil
}

// Gallery lists a provider's photos, newest first, without their contents.
func (s *Service) Gallery(ctx context.Context, userID string) ([]GalleryPhoto, error) {
	cur, err := s.photos.Find(ctx, bson.M{"user_id": userID},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetProjection(bson.M{"data": 0}))
	if err != nil {
		return nil, fmt.Errorf("find photos: %w", err)
	}
	rows := []GalleryPhoto{}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read photos: %w", err)
	}
	return rows, nil
}

// Photo returns one gallery photo with its contents.
func (s *Service) Photo(ctx context.Context, providerID, id string) (*GalleryPhoto, error) {
	var p GalleryPhoto
	err := s.photos.FindOne(ctx, bson.M{"_id": id, "user_id": providerID}).Decode(&p)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, apperr.NotFound("photo_not_found", "photo not found")
	}
	if err != nil {
		return nil, fmt.Errorf("load photo: %w", err)
	}
	return &p, nil
}

// DeletePhoto removes a gallery photo.
func (s *Service) DeletePhoto(ctx context.Context, userID, id string) error {
	res, err := s.photos.DeleteOne(ctx, bson.M{"_id": id, "user_id": userID})
	if err != nil {
		return fmt.Errorf("delete photo: %w", err)
	}
	if res.DeletedCount == 0 {
		return apperr.NotFound("photo_not_found", "photo not found")
	}
	return nil
}

// SetAvailability checks and saves a weekly schedule and days off. Past days
// off are dropped, so the list only holds what still matters.
func (s *Service) SetAvailability(ctx context.Context, userID string, a *user.Availability) (*user.Availability, error) {
	if a == nil {
		return nil, s.users.SetAvailability(ctx, userID, nil)
	}
	clean := &user.Availability{Weekly: map[string][]string{}, DaysOff: []string{}}
	total := 0
	for day, slots := range a.Weekly {
		if !slices.Contains(user.Weekdays, day) {
			return nil, apperr.BadRequest("invalid_day", "days must be sun, mon, tue, wed, thu, fri or sat")
		}
		kept := []string{}
		for _, slot := range job.Slots {
			if slices.Contains(slots, slot) {
				kept = append(kept, slot)
			}
		}
		if len(kept) != len(slots) {
			return nil, apperr.BadRequest("invalid_slot", "unknown time slot")
		}
		if len(kept) > 0 {
			clean.Weekly[day] = kept
			total += len(kept)
		}
	}
	if total == 0 {
		return nil, apperr.BadRequest("no_hours", "choose at least one time you can work")
	}
	today := s.now().In(nepal).Format("2006-01-02")
	last := s.now().In(nepal).AddDate(0, 0, daysOffHorizon).Format("2006-01-02")
	for _, d := range a.DaysOff {
		if _, err := time.Parse("2006-01-02", d); err != nil {
			return nil, apperr.BadRequest("invalid_date", "days off must look like 2026-11-20")
		}
		if d > last {
			return nil, apperr.BadRequest("invalid_date", "days off can be up to a year ahead")
		}
		if d >= today && !slices.Contains(clean.DaysOff, d) {
			clean.DaysOff = append(clean.DaysOff, d)
		}
	}
	if len(clean.DaysOff) > maxDaysOff {
		return nil, apperr.BadRequest("too_many_days_off", fmt.Sprintf("you can mark up to %d days off", maxDaysOff))
	}
	slices.Sort(clean.DaysOff)
	if err := s.users.SetAvailability(ctx, userID, clean); err != nil {
		return nil, err
	}
	return clean, nil
}
