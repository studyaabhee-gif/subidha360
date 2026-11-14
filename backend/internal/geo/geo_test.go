package geo

import (
	"math"
	"testing"
)

func TestNewPointStoresLongitudeFirst(t *testing.T) {
	p, err := NewPoint(27.7, 85.3)
	if err != nil {
		t.Fatal(err)
	}
	if p.Coordinates != [2]float64{85.3, 27.7} {
		t.Fatalf("coordinates = %v", p.Coordinates)
	}
}

func TestNewPointRejectsOutOfRange(t *testing.T) {
	if _, err := NewPoint(91, 0); err == nil {
		t.Fatal("expected error for latitude 91")
	}
	if _, err := NewPoint(0, 181); err == nil {
		t.Fatal("expected error for longitude 181")
	}
}

func TestCircleIsClosedAndRoughlyTheRightSize(t *testing.T) {
	const lat, lng, radius = 27.7172, 85.3240, 5000.0
	c, err := Circle(lat, lng, radius)
	if err != nil {
		t.Fatal(err)
	}
	ring := c.Coordinates[0]
	if ring[0] != ring[len(ring)-1] {
		t.Fatal("ring is not closed")
	}
	metersPerDegree := earthRadiusMeters * math.Pi / 180
	for _, p := range ring {
		dLat := (p[1] - lat) * metersPerDegree
		dLng := (p[0] - lng) * metersPerDegree * math.Cos(lat*math.Pi/180)
		if d := math.Hypot(dLat, dLng); math.Abs(d-radius) > radius*0.01 {
			t.Fatalf("vertex %v is %.0fm from centre", p, d)
		}
	}
}

func TestCircleRejectsBadRadius(t *testing.T) {
	for _, r := range []float64{0, -1, 100001} {
		if _, err := Circle(27, 85, r); err == nil {
			t.Errorf("expected error for radius %v", r)
		}
	}
}

func TestNewPolygonClosesRing(t *testing.T) {
	p, err := NewPolygon([][2]float64{{85, 27}, {86, 27}, {86, 28}})
	if err != nil {
		t.Fatal(err)
	}
	ring := p.Coordinates[0]
	if len(ring) != 4 || ring[0] != ring[3] {
		t.Fatalf("ring = %v", ring)
	}
}

func TestNewPolygonRejectsTooFewPoints(t *testing.T) {
	if _, err := NewPolygon([][2]float64{{85, 27}, {86, 27}}); err == nil {
		t.Fatal("expected error for 2 points")
	}
	if _, err := NewPolygon([][2]float64{{85, 27}, {86, 27}, {85, 27}}); err == nil {
		t.Fatal("expected error for a ring with 2 distinct points")
	}
}
