// Package user stores the single user entity shared by Seeker and Provider roles.
package user

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/geo"
	"subidha360/backend/internal/platform/mongodb"
)

// mongoInvalidGeometry is the server error code for an index key that is not
// valid GeoJSON, such as a self-intersecting polygon.
const mongoInvalidGeometry = 16755

// User deliberately has no active_ui_state: the spec keeps that on the device.
type User struct {
	ID                 string `bson:"_id" json:"id"`
	PhoneNumber        string `bson:"phone_number" json:"phone_number"`
	HasProviderProfile bool   `bson:"has_provider_profile" json:"has_provider_profile"`
	DisplayName        string `bson:"display_name,omitempty" json:"display_name"`
	// IsAdmin is set directly in the database; no API can grant it.
	IsAdmin bool `bson:"is_admin,omitempty" json:"is_admin,omitempty"`
	// Verification tracks the identity check behind IsVerified.
	Verification *Verification `bson:"verification,omitempty" json:"verification,omitempty"`
	// Availability limits which scheduled jobs a provider is offered. Nil
	// means any time.
	Availability *Availability `bson:"availability,omitempty" json:"availability,omitempty"`
	// Suspension is set by an admin. A suspended user cannot log in or act.
	Suspension      *Suspension      `bson:"suspension,omitempty" json:"suspension,omitempty"`
	ProviderProfile *ProviderProfile `bson:"provider_profile,omitempty" json:"provider_profile,omitempty"`
	// These sit outside ProviderProfile so editing a profile cannot reset them.
	// FavoriteProviderIDs are providers this user wants to hire again.
	FavoriteProviderIDs []string `bson:"favorite_provider_ids,omitempty" json:"favorite_provider_ids,omitempty"`
	// TermsVersion is the version of the terms and privacy policy the person
	// last agreed to, and TermsAcceptedAt when.
	TermsVersion    string     `bson:"terms_version,omitempty" json:"terms_version,omitempty"`
	TermsAcceptedAt *time.Time `bson:"terms_accepted_at,omitempty" json:"terms_accepted_at,omitempty"`
	IsVerified      bool       `bson:"is_verified,omitempty" json:"is_verified"`
	RatingSum       int        `bson:"rating_sum,omitempty" json:"-"`
	RatingCount     int        `bson:"rating_count,omitempty" json:"-"`
	JobsCompleted   int        `bson:"jobs_completed,omitempty" json:"-"`
	CreatedAt       time.Time  `bson:"created_at" json:"created_at"`
}

// Identity check statuses.
const (
	CheckPending  = "PENDING"
	CheckApproved = "APPROVED"
	CheckRejected = "REJECTED"
)

// Verification is the state of a provider's identity check.
type Verification struct {
	Status      string     `bson:"status" json:"status"`
	SubmittedAt time.Time  `bson:"submitted_at" json:"submitted_at"`
	DecidedAt   *time.Time `bson:"decided_at,omitempty" json:"decided_at,omitempty"`
	// Reason is shown to the provider when a check is rejected.
	Reason    string `bson:"reason,omitempty" json:"reason,omitempty"`
	DecidedBy string `bson:"decided_by,omitempty" json:"-"`
}

// Availability is a provider's weekly working slots and days off.
type Availability struct {
	// Weekly maps "mon" to "sun" to the two-hour slots worked that day.
	Weekly  map[string][]string `bson:"weekly" json:"weekly"`
	DaysOff []string            `bson:"days_off" json:"days_off"`
}

// Weekdays are the keys of Availability.Weekly, indexed by time.Weekday.
var Weekdays = []string{"sun", "mon", "tue", "wed", "thu", "fri", "sat"}

// AvailableAt matches providers free for a scheduled job. A job wanted as
// soon as possible matches everyone, as does a provider with no schedule.
func AvailableAt(date, slot string) bson.M {
	day, err := time.Parse("2006-01-02", date)
	if date == "" || slot == "" || err != nil {
		return nil
	}
	return bson.M{"$or": bson.A{
		bson.M{"availability": bson.M{"$exists": false}},
		bson.M{
			"availability.weekly." + Weekdays[day.Weekday()]: slot,
			"availability.days_off":                          bson.M{"$ne": date},
		},
	}}
}

// Suspension records why and by whom an account was locked.
type Suspension struct {
	Reason string    `bson:"reason" json:"reason"`
	By     string    `bson:"by" json:"by"`
	At     time.Time `bson:"at" json:"at"`
}

type ProviderProfile struct {
	ServiceArea     geo.Polygon `bson:"service_area" json:"service_area"`
	CategoryIDs     []int       `bson:"category_ids" json:"category_ids"`
	IsOnline        bool        `bson:"is_online" json:"is_online"`
	Bio             string      `bson:"bio,omitempty" json:"bio"`
	YearsExperience int         `bson:"years_experience,omitempty" json:"years_experience"`
}

// PublicProfile is what others may see about a provider. It deliberately
// leaves out the phone number and exact service area.
type PublicProfile struct {
	ID              string    `json:"id"`
	Name            string    `json:"name"`
	Bio             string    `json:"bio"`
	YearsExperience int       `json:"years_experience"`
	CategoryIDs     []int     `json:"category_ids"`
	Verified        bool      `json:"verified"`
	Rating          float64   `json:"rating"`
	ReviewCount     int       `json:"review_count"`
	JobsCompleted   int       `json:"jobs_completed"`
	MemberSince     time.Time `json:"member_since"`
	// Availability is when the provider takes jobs. Missing means any time.
	Availability *Availability `json:"availability,omitempty"`
}

// Public builds the shareable view of a user.
func (u *User) Public() PublicProfile {
	p := PublicProfile{
		ID:            u.ID,
		Name:          u.DisplayName,
		Verified:      u.IsVerified,
		ReviewCount:   u.RatingCount,
		JobsCompleted: u.JobsCompleted,
		MemberSince:   u.CreatedAt,
		Availability:  u.Availability,
		CategoryIDs:   []int{},
	}
	if p.Name == "" {
		p.Name = "New provider"
	}
	if u.RatingCount > 0 {
		p.Rating = float64(u.RatingSum) / float64(u.RatingCount)
	}
	if u.ProviderProfile != nil {
		p.Bio = u.ProviderProfile.Bio
		p.YearsExperience = u.ProviderProfile.YearsExperience
		p.CategoryIDs = u.ProviderProfile.CategoryIDs
	}
	return p
}

type Repo struct {
	users *mongo.Collection
}

func NewRepo(db *mongo.Database) *Repo {
	return &Repo{users: db.Collection(mongodb.Users)}
}

// FindOrCreateByPhone returns the user for a phone number, creating it on first login.
func (r *Repo) FindOrCreateByPhone(ctx context.Context, phone string) (*User, error) {
	update := bson.M{"$setOnInsert": bson.M{
		"_id":                  uuid.NewString(),
		"has_provider_profile": false,
		"created_at":           time.Now().UTC(),
	}}
	opts := options.FindOneAndUpdate().SetUpsert(true).SetReturnDocument(options.After)

	var u User
	err := r.users.FindOneAndUpdate(ctx, bson.M{"phone_number": phone}, update, opts).Decode(&u)
	if mongo.IsDuplicateKeyError(err) {
		// Two first logins raced; the other one created the user.
		err = r.users.FindOne(ctx, bson.M{"phone_number": phone}).Decode(&u)
	}
	if err != nil {
		return nil, fmt.Errorf("find or create user: %w", err)
	}
	return &u, nil
}

func (r *Repo) Get(ctx context.Context, id string) (*User, error) {
	var u User
	err := r.users.FindOne(ctx, bson.M{"_id": id}).Decode(&u)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, apperr.NotFound("user_not_found", "user not found")
	}
	if err != nil {
		return nil, fmt.Errorf("get user: %w", err)
	}
	return &u, nil
}

// SetProviderProfile creates or replaces a user's provider profile.
func (r *Repo) SetProviderProfile(ctx context.Context, id string, p ProviderProfile) error {
	res, err := r.users.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$set": bson.M{
		"has_provider_profile": true,
		"provider_profile":     p,
	}})
	var we mongo.WriteException
	if errors.As(err, &we) && we.HasErrorCode(mongoInvalidGeometry) {
		return apperr.BadRequest("invalid_service_area", "service area is not a valid polygon")
	}
	if err != nil {
		return fmt.Errorf("set provider profile: %w", err)
	}
	if res.MatchedCount == 0 {
		return apperr.NotFound("user_not_found", "user not found")
	}
	return nil
}

// SetDisplayName changes the name others see.
func (r *Repo) SetDisplayName(ctx context.Context, id, name string) error {
	res, err := r.users.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$set": bson.M{"display_name": name}})
	if err != nil {
		return fmt.Errorf("set display name: %w", err)
	}
	if res.MatchedCount == 0 {
		return apperr.NotFound("user_not_found", "user not found")
	}
	return nil
}

// SetVerified records the outcome of an admin's identity check.
func (r *Repo) SetVerified(ctx context.Context, id string, verified bool) error {
	res, err := r.users.UpdateOne(ctx,
		bson.M{"_id": id, "has_provider_profile": true},
		bson.M{"$set": bson.M{"is_verified": verified}},
	)
	if err != nil {
		return fmt.Errorf("set verified: %w", err)
	}
	if res.MatchedCount == 0 {
		return apperr.NotFound("provider_not_found", "provider not found")
	}
	return nil
}

// SetSuspension locks an account. Admins cannot be suspended, so one admin
// can never lock out the rest.
func (r *Repo) SetSuspension(ctx context.Context, id string, s Suspension) error {
	res, err := r.users.UpdateOne(ctx,
		bson.M{"_id": id, "is_admin": bson.M{"$ne": true}},
		bson.M{"$set": bson.M{"suspension": s}},
	)
	if err != nil {
		return fmt.Errorf("set suspension: %w", err)
	}
	if res.MatchedCount == 0 {
		if _, err := r.Get(ctx, id); err != nil {
			return err
		}
		return apperr.Conflict("cannot_suspend_admin", "remove admin access before suspending this account")
	}
	return nil
}

// ClearSuspension unlocks an account.
func (r *Repo) ClearSuspension(ctx context.Context, id string) error {
	res, err := r.users.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$unset": bson.M{"suspension": ""}})
	if err != nil {
		return fmt.Errorf("clear suspension: %w", err)
	}
	if res.MatchedCount == 0 {
		return apperr.NotFound("user_not_found", "user not found")
	}
	return nil
}

// AddRating folds one review into a provider's running totals.
func (r *Repo) AddRating(ctx context.Context, id string, rating int) error {
	_, err := r.users.UpdateOne(ctx, bson.M{"_id": id},
		bson.M{"$inc": bson.M{"rating_sum": rating, "rating_count": 1}})
	if err != nil {
		return fmt.Errorf("add rating: %w", err)
	}
	return nil
}

// AddCompletedJob counts a finished job towards a provider's record.
func (r *Repo) AddCompletedJob(ctx context.Context, id string) error {
	_, err := r.users.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$inc": bson.M{"jobs_completed": 1}})
	if err != nil {
		return fmt.Errorf("add completed job: %w", err)
	}
	return nil
}

// PublicProfiles returns the public view of several users, keyed by ID.
func (r *Repo) PublicProfiles(ctx context.Context, ids []string) (map[string]PublicProfile, error) {
	cur, err := r.users.Find(ctx, bson.M{"_id": bson.M{"$in": ids}})
	if err != nil {
		return nil, fmt.Errorf("find profiles: %w", err)
	}
	var rows []User
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read profiles: %w", err)
	}
	profiles := make(map[string]PublicProfile, len(rows))
	for i := range rows {
		profiles[rows[i].ID] = rows[i].Public()
	}
	return profiles, nil
}

// maxFavorites keeps the list short enough to be useful.
const maxFavorites = 50

// AddFavorite remembers a provider. Adding one twice changes nothing.
func (r *Repo) AddFavorite(ctx context.Context, id, providerID string) error {
	if id == providerID {
		return apperr.BadRequest("invalid_favorite", "you cannot favourite yourself")
	}
	p, err := r.Get(ctx, providerID)
	if err != nil {
		return err
	}
	if p.ProviderProfile == nil {
		return apperr.BadRequest("invalid_favorite", "only providers can be favourites")
	}
	res, err := r.users.UpdateOne(ctx, bson.M{
		"_id": id, fmt.Sprintf("favorite_provider_ids.%d", maxFavorites-1): bson.M{"$exists": false},
	}, bson.M{"$addToSet": bson.M{"favorite_provider_ids": providerID}})
	if err != nil {
		return fmt.Errorf("add favourite: %w", err)
	}
	if res.MatchedCount == 0 {
		return apperr.Conflict("too_many_favorites", "remove a favourite before adding another")
	}
	return nil
}

// RemoveFavorite forgets a provider.
func (r *Repo) RemoveFavorite(ctx context.Context, id, providerID string) error {
	_, err := r.users.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$pull": bson.M{"favorite_provider_ids": providerID}})
	if err != nil {
		return fmt.Errorf("remove favourite: %w", err)
	}
	return nil
}

// SetOnline toggles whether a provider receives broadcasts.
func (r *Repo) SetOnline(ctx context.Context, id string, online bool) error {
	res, err := r.users.UpdateOne(ctx,
		bson.M{"_id": id, "has_provider_profile": true},
		bson.M{"$set": bson.M{"provider_profile.is_online": online}},
	)
	if err != nil {
		return fmt.Errorf("set online: %w", err)
	}
	if res.MatchedCount == 0 {
		return apperr.Conflict("no_provider_profile", "create a provider profile first")
	}
	return nil
}

// ProvidersCovering returns online providers in a category whose service area
// contains the point, excluding one user (the job's seeker).
func (r *Repo) ProvidersCovering(ctx context.Context, p geo.Point, categoryID int, exclude string, when bson.M) ([]string, error) {
	return r.providerIDs(ctx, bson.M{"$geoIntersects": bson.M{"$geometry": p}}, categoryID, exclude, when)
}

// ProvidersNear is the escalated form of ProvidersCovering: it also matches
// providers whose service area is within maxMeters of the point.
func (r *Repo) ProvidersNear(ctx context.Context, p geo.Point, maxMeters float64, categoryID int, exclude string, when bson.M) ([]string, error) {
	return r.providerIDs(ctx, bson.M{"$nearSphere": bson.M{"$geometry": p, "$maxDistance": maxMeters}}, categoryID, exclude, when)
}

func (r *Repo) providerIDs(ctx context.Context, area bson.M, categoryID int, exclude string, when bson.M) ([]string, error) {
	filter := bson.M{
		"_id":                           bson.M{"$ne": exclude},
		"provider_profile.is_online":    true,
		"provider_profile.category_ids": categoryID,
		"provider_profile.service_area": area,
		"suspension":                    bson.M{"$exists": false},
	}
	for k, v := range when {
		filter[k] = v
	}
	cur, err := r.users.Find(ctx, filter, options.Find().SetProjection(bson.M{"_id": 1}))
	if err != nil {
		return nil, fmt.Errorf("find providers: %w", err)
	}
	var rows []struct {
		ID string `bson:"_id"`
	}
	if err := cur.All(ctx, &rows); err != nil {
		return nil, fmt.Errorf("read providers: %w", err)
	}
	ids := make([]string, len(rows))
	for i, row := range rows {
		ids[i] = row.ID
	}
	return ids, nil
}

// SetAvailability saves a provider's schedule. Nil removes it, so the
// provider is offered jobs at any time.
func (r *Repo) SetAvailability(ctx context.Context, id string, a *Availability) error {
	update := bson.M{"$unset": bson.M{"availability": ""}}
	if a != nil {
		update = bson.M{"$set": bson.M{"availability": a}}
	}
	res, err := r.users.UpdateOne(ctx, bson.M{"_id": id, "has_provider_profile": true}, update)
	if err != nil {
		return fmt.Errorf("set availability: %w", err)
	}
	if res.MatchedCount == 0 {
		return apperr.Conflict("no_provider_profile", "create a provider profile first")
	}
	return nil
}

// SubmitCheck asks admins to check a provider's documents.
func (r *Repo) SubmitCheck(ctx context.Context, id string, at time.Time) error {
	res, err := r.users.UpdateOne(ctx,
		bson.M{"_id": id, "has_provider_profile": true, "verification.status": bson.M{"$nin": bson.A{CheckPending, CheckApproved}}},
		bson.M{"$set": bson.M{"verification": Verification{Status: CheckPending, SubmittedAt: at}}},
	)
	if err != nil {
		return fmt.Errorf("submit check: %w", err)
	}
	if res.MatchedCount == 0 {
		u, err := r.Get(ctx, id)
		if err != nil {
			return err
		}
		if !u.HasProviderProfile {
			return apperr.Conflict("no_provider_profile", "create a provider profile first")
		}
		return apperr.Conflict("check_in_progress", "your documents are already being checked or approved")
	}
	return nil
}

// DecideCheck records an admin's decision on a waiting check. Approval also
// grants the verified badge; rejection removes it.
func (r *Repo) DecideCheck(ctx context.Context, id string, approved bool, reason, by string, at time.Time) error {
	status := CheckRejected
	if approved {
		status = CheckApproved
		reason = ""
	}
	res, err := r.users.UpdateOne(ctx,
		bson.M{"_id": id, "verification.status": CheckPending},
		bson.M{"$set": bson.M{
			"verification.status":     status,
			"verification.decided_at": at,
			"verification.reason":     reason,
			"verification.decided_by": by,
			"is_verified":             approved,
		}},
	)
	if err != nil {
		return fmt.Errorf("decide check: %w", err)
	}
	if res.MatchedCount == 0 {
		return apperr.Conflict("no_check_waiting", "this provider has no identity check waiting")
	}
	return nil
}

// ResetCheck clears a finished check, because the documents behind it
// changed. The badge goes with it, so swapping a card after approval cannot
// keep a badge earned with another one.
func (r *Repo) ResetCheck(ctx context.Context, id string) error {
	_, err := r.users.UpdateOne(ctx,
		bson.M{"_id": id, "verification.status": bson.M{"$in": bson.A{CheckApproved, CheckRejected}}},
		bson.M{"$unset": bson.M{"verification": ""}, "$set": bson.M{"is_verified": false}},
	)
	if err != nil {
		return fmt.Errorf("reset check: %w", err)
	}
	return nil
}

// AcceptTerms records that a person agreed to a version of the terms. Agreeing
// to the same version again keeps the first date.
func (r *Repo) AcceptTerms(ctx context.Context, id, version string, at time.Time) error {
	_, err := r.users.UpdateOne(ctx,
		bson.M{"_id": id, "terms_version": bson.M{"$ne": version}},
		bson.M{"$set": bson.M{"terms_version": version, "terms_accepted_at": at}},
	)
	if err != nil {
		return fmt.Errorf("accept terms: %w", err)
	}
	return nil
}
