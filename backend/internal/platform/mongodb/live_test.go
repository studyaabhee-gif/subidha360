package mongodb

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
)

// TestLiveDatabase checks that MONGO_URI supports what the app depends on, using
// a temporary database that it drops afterwards. It runs only with MONGO_LIVE_TEST=1.
func TestLiveDatabase(t *testing.T) {
	if os.Getenv("MONGO_LIVE_TEST") != "1" {
		t.Skip("set MONGO_LIVE_TEST=1 and MONGO_URI to run")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	client, err := Connect(ctx, os.Getenv("MONGO_URI"))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Disconnect(context.Background())

	db := client.Database("subidha360_livecheck_" + uuid.NewString()[:8])
	defer db.Drop(context.Background())

	var hello bson.M
	if err := client.Database("admin").RunCommand(ctx, bson.D{{Key: "hello", Value: 1}}).Decode(&hello); err != nil {
		t.Fatal(err)
	}
	if hello["setName"] == nil {
		t.Fatal("not a replica set, so transactions will not work")
	}
	t.Logf("replica set confirmed, server wire version %v", hello["maxWireVersion"])

	if err := EnsureIndexes(ctx, db); err != nil {
		t.Fatal(err)
	}
	t.Log("indexes created")

	accounts := db.Collection(WalletAccounts)
	err = Tx(ctx, client, func(ctx context.Context) error {
		_, err := accounts.InsertOne(ctx, bson.M{"_id": "committed", "balance": 1})
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	abort := errors.New("abort on purpose")
	err = Tx(ctx, client, func(ctx context.Context) error {
		if _, err := accounts.InsertOne(ctx, bson.M{"_id": "rolled-back", "balance": 1}); err != nil {
			return err
		}
		return abort
	})
	if !errors.Is(err, abort) {
		t.Fatalf("err = %v", err)
	}
	if n, err := accounts.CountDocuments(ctx, bson.M{"_id": "committed"}); err != nil || n != 1 {
		t.Fatalf("committed count = %d, err = %v", n, err)
	}
	if n, err := accounts.CountDocuments(ctx, bson.M{"_id": "rolled-back"}); err != nil || n != 0 {
		t.Fatalf("rolled-back count = %d, err = %v", n, err)
	}
	t.Log("transactions commit and roll back")

	users := db.Collection(Users)
	area := bson.M{"type": "Polygon", "coordinates": bson.A{bson.A{
		bson.A{85.30, 27.70}, bson.A{85.35, 27.70}, bson.A{85.35, 27.74}, bson.A{85.30, 27.74}, bson.A{85.30, 27.70},
	}}}
	_, err = users.InsertOne(ctx, bson.M{"_id": "provider", "phone_number": "+9779800000000", "provider_profile": bson.M{"service_area": area}})
	if err != nil {
		t.Fatal(err)
	}
	inside := bson.M{"type": "Point", "coordinates": bson.A{85.3240, 27.7172}}
	nearby := bson.M{"type": "Point", "coordinates": bson.A{85.3240, 27.7600}}
	field := "provider_profile.service_area"
	checks := map[string]bson.M{
		"point in area":   {field: bson.M{"$geoIntersects": bson.M{"$geometry": inside}}},
		"point near area": {field: bson.M{"$nearSphere": bson.M{"$geometry": nearby, "$maxDistance": 5000}}},
	}
	for name, filter := range checks {
		if err := users.FindOne(ctx, filter).Err(); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
	}
	t.Log("geo searches work")
}
