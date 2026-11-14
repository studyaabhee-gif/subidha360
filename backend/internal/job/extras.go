package job

import (
	"context"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"slices"
	"strings"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"

	"subidha360/backend/internal/apperr"
	"subidha360/backend/internal/auth"
	"subidha360/backend/internal/geo"
	"subidha360/backend/internal/platform/httpx"
	"subidha360/backend/internal/platform/mongodb"
)

const (
	maxJobPhotos  = 4
	maxPhotoBytes = 5 << 20
	// maxReschedules stops a seeker moving a provider's booking endlessly.
	maxReschedules = 3
	// trackingFreshFor is how long a position counts as live. An older one
	// means the provider stopped sharing or lost signal.
	trackingFreshFor = 10 * time.Minute
)

var photoTypes = []string{"image/jpeg", "image/png", "image/webp"}

// changeableStatuses are the states in which a seeker can still change the
// request: nobody has started work.
var changeableStatuses = []Status{StatusBroadcasting, StatusEscalating, StatusManualFallback, StatusAccepted}

// Tracking is the assigned provider's last shared position.
type Tracking struct {
	Location geo.Point `bson:"location"`
	At       time.Time `bson:"at"`
}

// Photo is a picture of the problem. Photos are stored apart from the job so
// that job lists stay small.
type Photo struct {
	ID        string    `bson:"_id"`
	JobID     string    `bson:"job_id"`
	Type      string    `bson:"type"`
	Data      []byte    `bson:"data"`
	CreatedAt time.Time `bson:"created_at"`
}

// blurLocation hides the exact pin from providers who have only been offered
// the job. Two decimal places is roughly a kilometre: enough to judge the trip.
func (j *Job) blurLocation(viewerID string) {
	if viewerID == j.SeekerID || viewerID == j.ProviderID {
		return
	}
	for i, v := range j.JobLocation.Coordinates {
		j.JobLocation.Coordinates[i] = math.Round(v*100) / 100
	}
}

// seekerJob loads a job for a change only its seeker may make, while work has
// not started.
func (s *Service) seekerJob(ctx context.Context, seekerID, id string) (*Job, error) {
	j, err := s.Party(ctx, seekerID, id)
	if err != nil {
		return nil, err
	}
	if j.SeekerID != seekerID {
		return nil, apperr.Forbidden("not_the_seeker", "only the person who posted the job can do this")
	}
	if !slices.Contains(changeableStatuses, j.Status) {
		return nil, errConflict
	}
	return j, nil
}

// AddPhoto stores a picture of the problem and returns its ID.
func (s *Service) AddPhoto(ctx context.Context, seekerID, id string, data []byte) (string, error) {
	kind := http.DetectContentType(data)
	if !slices.Contains(photoTypes, kind) {
		return "", apperr.BadRequest("invalid_photo", "photos must be JPEG, PNG or WebP images")
	}
	photoID := uuid.NewString()
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		if _, err := s.seekerJob(ctx, seekerID, id); err != nil {
			return err
		}
		// Matching on the last allowed slot keeps the limit true under
		// concurrent uploads.
		res, err := s.jobs.UpdateOne(ctx, bson.M{
			"_id": id, fmt.Sprintf("photo_ids.%d", maxJobPhotos-1): bson.M{"$exists": false},
		}, bson.M{"$push": bson.M{"photo_ids": photoID}})
		if err != nil {
			return fmt.Errorf("add photo id: %w", err)
		}
		if res.ModifiedCount == 0 {
			return apperr.Conflict("too_many_photos", fmt.Sprintf("a job can have up to %d photos", maxJobPhotos))
		}
		_, err = s.photos.InsertOne(ctx, Photo{ID: photoID, JobID: id, Type: kind, Data: data, CreatedAt: time.Now().UTC()})
		if err != nil {
			return fmt.Errorf("insert photo: %w", err)
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	return photoID, nil
}

// PhotoFor returns a photo to anyone who may see its job.
func (s *Service) PhotoFor(ctx context.Context, viewerID, id, photoID string) (*Photo, error) {
	if _, err := s.Get(ctx, viewerID, id); err != nil {
		return nil, err
	}
	var p Photo
	err := s.photos.FindOne(ctx, bson.M{"_id": photoID, "job_id": id}).Decode(&p)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, apperr.NotFound("photo_not_found", "photo not found")
	}
	if err != nil {
		return nil, fmt.Errorf("load photo: %w", err)
	}
	return &p, nil
}

// DeletePhoto removes a picture the seeker no longer wants shared.
func (s *Service) DeletePhoto(ctx context.Context, seekerID, id, photoID string) error {
	return mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		if _, err := s.seekerJob(ctx, seekerID, id); err != nil {
			return err
		}
		res, err := s.photos.DeleteOne(ctx, bson.M{"_id": photoID, "job_id": id})
		if err != nil {
			return fmt.Errorf("delete photo: %w", err)
		}
		if res.DeletedCount == 0 {
			return apperr.NotFound("photo_not_found", "photo not found")
		}
		_, err = s.jobs.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$pull": bson.M{"photo_ids": photoID}})
		if err != nil {
			return fmt.Errorf("remove photo id: %w", err)
		}
		return nil
	})
}

// Reschedule moves the requested time. An assigned provider is told, because
// they committed to the old time.
func (s *Service) Reschedule(ctx context.Context, seekerID, id, date, slot string) (*Job, error) {
	if err := validateSchedule(date, slot, time.Now()); err != nil {
		return nil, err
	}
	err := mongodb.Tx(ctx, s.client, func(ctx context.Context) error {
		j, err := s.seekerJob(ctx, seekerID, id)
		if err != nil {
			return err
		}
		if j.RescheduleCount >= maxReschedules {
			return apperr.Conflict("reschedule_limit", fmt.Sprintf("a job can be rescheduled up to %d times", maxReschedules))
		}
		_, err = s.jobs.UpdateOne(ctx, bson.M{"_id": id}, bson.M{
			"$set": bson.M{"preferred_date": date, "preferred_slot": slot, "updated_at": time.Now().UTC()},
			"$inc": bson.M{"reschedule_count": 1},
		})
		if err != nil {
			return fmt.Errorf("reschedule: %w", err)
		}
		if j.ProviderID == "" {
			return nil
		}
		return s.noteRescheduled(ctx, j, date, slot)
	})
	if err != nil {
		return nil, err
	}
	return s.load(ctx, id)
}

// ShareLocation records the assigned provider's position while the job is live.
func (s *Service) ShareLocation(ctx context.Context, providerID, id string, lat, lng float64) error {
	point, err := geo.NewPoint(lat, lng)
	if err != nil {
		return err
	}
	j, err := s.Party(ctx, providerID, id)
	if err != nil {
		return err
	}
	if j.ProviderID != providerID {
		return apperr.Forbidden("not_the_provider", "only the assigned provider can share a location")
	}
	res, err := s.jobs.UpdateOne(ctx, bson.M{
		"_id": id, "status": bson.M{"$in": []Status{StatusAccepted, StatusInProgress}},
	}, bson.M{"$set": bson.M{"provider_location": Tracking{Location: point, At: time.Now().UTC()}}})
	if err != nil {
		return fmt.Errorf("share location: %w", err)
	}
	if res.MatchedCount == 0 {
		return errConflict
	}
	return nil
}

// StopSharing erases the provider's position.
func (s *Service) StopSharing(ctx context.Context, providerID, id string) error {
	j, err := s.Party(ctx, providerID, id)
	if err != nil {
		return err
	}
	if j.ProviderID != providerID {
		return apperr.Forbidden("not_the_provider", "only the assigned provider can stop sharing")
	}
	_, err = s.jobs.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$unset": bson.M{"provider_location": ""}})
	if err != nil {
		return fmt.Errorf("stop sharing: %w", err)
	}
	return nil
}

// LiveLocation returns the provider's position to the job's two parties, or
// nil when it is not being shared.
func (s *Service) LiveLocation(ctx context.Context, userID, id string, now time.Time) (*Tracking, error) {
	j, err := s.Party(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	if j.ProviderLocation == nil || now.Sub(j.ProviderLocation.At) > trackingFreshFor {
		return nil, nil
	}
	return j.ProviderLocation, nil
}

// checkPreferred confirms a requested provider really offers this service.
func (s *Service) checkPreferred(ctx context.Context, seekerID, providerID string, categoryID int) error {
	invalid := apperr.BadRequest("invalid_provider", "that provider does not offer this service")
	if providerID == seekerID {
		return invalid
	}
	p, err := s.users.Get(ctx, providerID)
	if err != nil {
		var e *apperr.Error
		if errors.As(err, &e) {
			return invalid
		}
		return err
	}
	if p.ProviderProfile == nil || !slices.Contains(p.ProviderProfile.CategoryIDs, categoryID) {
		return invalid
	}
	return nil
}

func (s *Service) handleAddPhoto(w http.ResponseWriter, r *http.Request) {
	data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxPhotoBytes))
	if err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			httpx.Error(w, apperr.New(http.StatusRequestEntityTooLarge, "photo_too_large", "photos can be up to 5 MB"))
			return
		}
		httpx.Error(w, apperr.BadRequest("invalid_photo", "the photo could not be read"))
		return
	}
	photoID, err := s.AddPhoto(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), data)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]string{"id": photoID})
}

func (s *Service) handlePhoto(w http.ResponseWriter, r *http.Request) {
	p, err := s.PhotoFor(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), r.PathValue("photoID"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	h := w.Header()
	h.Set("Content-Type", p.Type)
	h.Set("X-Content-Type-Options", "nosniff")
	h.Set("Cache-Control", "private, max-age=3600")
	w.Write(p.Data)
}

func (s *Service) handleDeletePhoto(w http.ResponseWriter, r *http.Request) {
	err := s.DeletePhoto(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), r.PathValue("photoID"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleReschedule(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Date string `json:"preferred_date"`
		Slot string `json:"preferred_slot"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	j, err := s.Reschedule(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), strings.TrimSpace(req.Date), strings.TrimSpace(req.Slot))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, j)
}

func (s *Service) handleShareLocation(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Lat float64 `json:"lat"`
		Lng float64 `json:"lng"`
	}
	if err := httpx.Decode(w, r, &req); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.ShareLocation(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), req.Lat, req.Lng); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleStopSharing(w http.ResponseWriter, r *http.Request) {
	if err := s.StopSharing(r.Context(), auth.UserID(r.Context()), r.PathValue("id")); err != nil {
		httpx.Error(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleTracking(w http.ResponseWriter, r *http.Request) {
	t, err := s.LiveLocation(r.Context(), auth.UserID(r.Context()), r.PathValue("id"), time.Now())
	if err != nil {
		httpx.Error(w, err)
		return
	}
	if t == nil {
		httpx.JSON(w, http.StatusOK, map[string]any{"active": false})
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"active": true,
		"lat":    t.Location.Coordinates[1],
		"lng":    t.Location.Coordinates[0],
		"at":     t.At,
	})
}
