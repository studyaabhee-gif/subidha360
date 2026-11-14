// Package geo provides the GeoJSON shapes stored in 2dsphere indexes.
package geo

import (
	"math"

	"subidha360/backend/internal/apperr"
)

const (
	earthRadiusMeters = 6371008.8
	circleVertices    = 32
)

// Point is a GeoJSON point. Coordinates are [longitude, latitude].
type Point struct {
	Type        string     `bson:"type" json:"type"`
	Coordinates [2]float64 `bson:"coordinates" json:"coordinates"`
}

// Polygon is a GeoJSON polygon: a list of closed rings of [longitude, latitude].
type Polygon struct {
	Type        string         `bson:"type" json:"type"`
	Coordinates [][][2]float64 `bson:"coordinates" json:"coordinates"`
}

func validLatLng(lat, lng float64) bool {
	return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
}

// NewPoint builds a point, rejecting out-of-range coordinates.
func NewPoint(lat, lng float64) (Point, error) {
	if !validLatLng(lat, lng) {
		return Point{}, apperr.BadRequest("invalid_location", "latitude or longitude is out of range")
	}
	return Point{Type: "Point", Coordinates: [2]float64{lng, lat}}, nil
}

// NewPolygon builds a polygon from a single outer ring, closing it if needed.
func NewPolygon(ring [][2]float64) (Polygon, error) {
	if len(ring) < 3 {
		return Polygon{}, apperr.BadRequest("invalid_service_area", "a polygon needs at least 3 points")
	}
	for _, p := range ring {
		if !validLatLng(p[1], p[0]) {
			return Polygon{}, apperr.BadRequest("invalid_service_area", "polygon points must be [longitude, latitude]")
		}
	}
	closed := append([][2]float64(nil), ring...)
	if closed[0] != closed[len(closed)-1] {
		closed = append(closed, closed[0])
	}
	if len(closed) < 4 {
		return Polygon{}, apperr.BadRequest("invalid_service_area", "a polygon needs at least 3 distinct points")
	}
	return Polygon{Type: "Polygon", Coordinates: [][][2]float64{closed}}, nil
}

// Circle approximates a radius around a point as a polygon. Storing radius
// service areas this way lets one 2dsphere query match both area types.
func Circle(lat, lng, radiusMeters float64) (Polygon, error) {
	if !validLatLng(lat, lng) {
		return Polygon{}, apperr.BadRequest("invalid_service_area", "latitude or longitude is out of range")
	}
	if radiusMeters <= 0 || radiusMeters > 100000 {
		return Polygon{}, apperr.BadRequest("invalid_service_area", "radius must be between 0 and 100 km")
	}

	latRad := lat * math.Pi / 180
	lngRad := lng * math.Pi / 180
	angular := radiusMeters / earthRadiusMeters

	ring := make([][2]float64, 0, circleVertices+1)
	for i := range circleVertices {
		// Counter-clockwise, as GeoJSON requires for an outer ring.
		bearing := -2 * math.Pi * float64(i) / circleVertices
		pLat := math.Asin(math.Sin(latRad)*math.Cos(angular) + math.Cos(latRad)*math.Sin(angular)*math.Cos(bearing))
		pLng := lngRad + math.Atan2(
			math.Sin(bearing)*math.Sin(angular)*math.Cos(latRad),
			math.Cos(angular)-math.Sin(latRad)*math.Sin(pLat),
		)
		ring = append(ring, [2]float64{pLng * 180 / math.Pi, pLat * 180 / math.Pi})
	}
	ring = append(ring, ring[0])
	return Polygon{Type: "Polygon", Coordinates: [][][2]float64{ring}}, nil
}
