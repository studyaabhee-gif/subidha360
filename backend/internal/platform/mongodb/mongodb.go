// Package mongodb manages the MongoDB connection, transactions and indexes.
package mongodb

import (
	"context"
	"fmt"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"go.mongodb.org/mongo-driver/v2/mongo/writeconcern"
)

// Collection names.
const (
	Users          = "users"
	Jobs           = "jobs"
	Bids           = "bids"
	WalletAccounts = "wallet_accounts"
	WalletLedger   = "wallet_ledger"
	Notifications  = "notifications"
	Devices        = "devices"
	Reviews        = "reviews"
	Messages       = "messages"
	JobPhotos      = "job_photos"
	// ProviderDocuments holds identity documents. Only the owner and admins
	// may read them.
	ProviderDocuments = "provider_documents"
	// ProviderPhotos is each provider's public gallery of past work.
	ProviderPhotos = "provider_photos"
	// Withdrawals are requests to move wallet money to a bank or eWallet.
	Withdrawals = "withdrawals"
	// Catalog is one document: the service list and site settings.
	Catalog         = "catalog"
	SupportThreads  = "support_threads"
	SupportMessages = "support_messages"
	// Flags are reports and automatic warning signs about accounts.
	Flags = "flags"
	// DailyViews holds one counter per page per day, and nothing personal.
	DailyViews = "daily_views"
	// AdminActions is the audit log of everything admins change.
	AdminActions = "admin_actions"
)

// Connect opens a client and verifies the server is reachable.
func Connect(ctx context.Context, uri string) (*mongo.Client, error) {
	client, err := mongo.Connect(options.Client().ApplyURI(uri).SetWriteConcern(writeconcern.Majority()))
	if err != nil {
		return nil, fmt.Errorf("connect: %w", err)
	}
	if err := client.Ping(ctx, nil); err != nil {
		return nil, fmt.Errorf("ping: %w", err)
	}
	return client, nil
}

// Tx runs fn in a transaction. If ctx already carries a session, fn joins that
// transaction, so services can compose. The driver may call fn more than once
// on transient errors, so fn must have no side effects outside the database.
// Transactions require a replica set.
func Tx(ctx context.Context, client *mongo.Client, fn func(ctx context.Context) error) error {
	if mongo.SessionFromContext(ctx) != nil {
		return fn(ctx)
	}
	session, err := client.StartSession()
	if err != nil {
		return fmt.Errorf("start session: %w", err)
	}
	defer session.EndSession(ctx)

	_, err = session.WithTransaction(ctx, func(ctx context.Context) (any, error) {
		return nil, fn(ctx)
	})
	return err
}

// EnsureIndexes creates every index and, as a side effect, every collection.
// Collections must exist before the first transaction touches them.
func EnsureIndexes(ctx context.Context, db *mongo.Database) error {
	indexes := map[string][]mongo.IndexModel{
		Users: {
			{Keys: bson.D{{Key: "phone_number", Value: 1}}, Options: options.Index().SetUnique(true)},
			{Keys: bson.D{{Key: "created_at", Value: -1}}},
			{Keys: bson.D{{Key: "provider_profile.service_area", Value: "2dsphere"}}},
			{Keys: bson.D{{Key: "verification.status", Value: 1}}},
		},
		Jobs: {
			{Keys: bson.D{{Key: "job_location", Value: "2dsphere"}}},
			{Keys: bson.D{{Key: "seeker_id", Value: 1}, {Key: "created_at", Value: -1}}},
			{Keys: bson.D{{Key: "status", Value: 1}, {Key: "window_ends_at", Value: 1}}},
			{Keys: bson.D{{Key: "eligible_provider_ids", Value: 1}, {Key: "status", Value: 1}}},
			{Keys: bson.D{{Key: "created_at", Value: -1}}},
			{Keys: bson.D{{Key: "provider_id", Value: 1}, {Key: "created_at", Value: -1}}},
			{Keys: bson.D{{Key: "status", Value: 1}, {Key: "created_at", Value: -1}}},
		},
		Bids: {
			{Keys: bson.D{{Key: "job_id", Value: 1}, {Key: "provider_id", Value: 1}}, Options: options.Index().SetUnique(true)},
		},
		WalletLedger: {
			// Makes each posting idempotent: a group can only be written once.
			{Keys: bson.D{{Key: "group_key", Value: 1}, {Key: "leg", Value: 1}}, Options: options.Index().SetUnique(true)},
			{Keys: bson.D{{Key: "account_id", Value: 1}, {Key: "created_at", Value: -1}}},
			{Keys: bson.D{{Key: "reference_job_id", Value: 1}}},
			{Keys: bson.D{{Key: "created_at", Value: -1}}},
			{Keys: bson.D{{Key: "transaction_type", Value: 1}, {Key: "created_at", Value: -1}}},
		},
		Notifications: {
			{Keys: bson.D{{Key: "status", Value: 1}, {Key: "next_attempt_at", Value: 1}}},
			{Keys: bson.D{{Key: "user_id", Value: 1}, {Key: "created_at", Value: -1}}},
		},
		Devices: {
			{Keys: bson.D{{Key: "user_id", Value: 1}}},
		},
		Reviews: {
			{Keys: bson.D{{Key: "provider_id", Value: 1}, {Key: "created_at", Value: -1}}},
		},
		ProviderDocuments: {
			{Keys: bson.D{{Key: "user_id", Value: 1}, {Key: "kind", Value: 1}}},
		},
		ProviderPhotos: {
			{Keys: bson.D{{Key: "user_id", Value: 1}, {Key: "created_at", Value: -1}}},
		},
		Withdrawals: {
			// One waiting request per person keeps the books simple to follow.
			{Keys: bson.D{{Key: "user_id", Value: 1}}, Options: options.Index().SetUnique(true).SetPartialFilterExpression(bson.M{"status": "PENDING"})},
			{Keys: bson.D{{Key: "status", Value: 1}, {Key: "created_at", Value: -1}}},
			{Keys: bson.D{{Key: "user_id", Value: 1}, {Key: "created_at", Value: -1}}},
		},
		SupportThreads: {
			{Keys: bson.D{{Key: "user_id", Value: 1}, {Key: "last_message_at", Value: -1}}},
			{Keys: bson.D{{Key: "status", Value: 1}, {Key: "last_message_at", Value: -1}}},
		},
		SupportMessages: {
			{Keys: bson.D{{Key: "thread_id", Value: 1}, {Key: "created_at", Value: 1}}},
		},
		DailyViews: {
			{Keys: bson.D{{Key: "day", Value: 1}}},
		},
		Flags: {
			{Keys: bson.D{{Key: "dedupe_key", Value: 1}}, Options: options.Index().SetUnique(true)},
			{Keys: bson.D{{Key: "status", Value: 1}, {Key: "created_at", Value: -1}}},
			{Keys: bson.D{{Key: "reported_id", Value: 1}, {Key: "created_at", Value: -1}}},
		},
		AdminActions: {
			{Keys: bson.D{{Key: "at", Value: -1}}},
			{Keys: bson.D{{Key: "target_id", Value: 1}, {Key: "at", Value: -1}}},
		},
		Messages: {
			{Keys: bson.D{{Key: "job_id", Value: 1}, {Key: "created_at", Value: 1}}},
		},
	}
	for name, models := range indexes {
		if _, err := db.Collection(name).Indexes().CreateMany(ctx, models); err != nil {
			return fmt.Errorf("indexes for %s: %w", name, err)
		}
	}

	// wallet_accounts only uses _id, so it has no index to create it implicitly.
	names, err := db.ListCollectionNames(ctx, bson.M{"name": WalletAccounts})
	if err != nil {
		return fmt.Errorf("list collections: %w", err)
	}
	if len(names) == 0 {
		if err := db.CreateCollection(ctx, WalletAccounts); err != nil {
			return fmt.Errorf("create %s: %w", WalletAccounts, err)
		}
	}
	return nil
}
