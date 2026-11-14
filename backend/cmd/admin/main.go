// Command admin grants or removes admin access. No API can do this, so a
// stolen admin session can never create more admins.
//
//	go run ./cmd/admin -phone +9779812345678
//	go run ./cmd/admin -phone +9779812345678 -remove
//	go run ./cmd/admin -list
//
// It reads MONGO_URI and MONGO_DB like the API. The person must have logged in
// once, so their account exists.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"

	"subidha360/backend/internal/platform/mongodb"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	phone := flag.String("phone", "", "phone number in +977 form, as shown in the app")
	remove := flag.Bool("remove", false, "remove admin access instead of granting it")
	list := flag.Bool("list", false, "list current admins")
	flag.Parse()

	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		return errors.New("MONGO_URI is not set")
	}
	name := os.Getenv("MONGO_DB")
	if name == "" {
		name = "subidha360"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	client, err := mongodb.Connect(ctx, uri)
	if err != nil {
		return err
	}
	defer client.Disconnect(context.Background())
	users := client.Database(name).Collection(mongodb.Users)

	if *list {
		cur, err := users.Find(ctx, bson.M{"is_admin": true})
		if err != nil {
			return err
		}
		var rows []struct {
			Phone string `bson:"phone_number"`
			Name  string `bson:"display_name"`
		}
		if err := cur.All(ctx, &rows); err != nil {
			return err
		}
		if len(rows) == 0 {
			fmt.Println("No admins yet.")
		}
		for _, r := range rows {
			fmt.Printf("%s  %s\n", r.Phone, r.Name)
		}
		return nil
	}
	if *phone == "" {
		flag.Usage()
		return errors.New("-phone is required")
	}

	update := bson.M{"$set": bson.M{"is_admin": true}}
	if *remove {
		update = bson.M{"$unset": bson.M{"is_admin": ""}}
	}
	res, err := users.UpdateOne(ctx, bson.M{"phone_number": *phone}, update)
	if err != nil {
		return err
	}
	if res.MatchedCount == 0 {
		return fmt.Errorf("no account with phone %s. Log in once in the app first", *phone)
	}
	if *remove {
		fmt.Printf("%s is no longer an admin.\n", *phone)
	} else {
		fmt.Printf("%s is now an admin. Log out and back in, then open Profile > Admin dashboard.\n", *phone)
	}
	return nil
}
