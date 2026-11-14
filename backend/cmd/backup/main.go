// Command backup saves the whole database to a folder, or restores one.
//
//	go run ./cmd/backup -out backups/2026-11-13
//	go run ./cmd/backup -restore backups/2026-11-13 -db subidha360_restored
//	go run ./cmd/backup -restore backups/2026-11-13 -replace   (overwrites live data)
//
// It reads MONGO_URI and MONGO_DB like the API. Backups hold personal data and
// identity documents: keep them encrypted, off this machine, and delete old
// ones on a schedule.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"time"

	"subidha360/backend/internal/platform/backup"
	"subidha360/backend/internal/platform/mongodb"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	out := flag.String("out", "", "folder to save a backup into (must not exist)")
	restore := flag.String("restore", "", "backup folder to restore from")
	dbName := flag.String("db", "", "database to restore into (default MONGO_DB)")
	replace := flag.Bool("replace", false, "drop existing collections before restoring")
	flag.Parse()

	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		return errors.New("MONGO_URI is not set")
	}
	name := os.Getenv("MONGO_DB")
	if name == "" {
		name = "subidha360"
	}
	if *dbName != "" {
		name = *dbName
	}
	if (*out == "") == (*restore == "") {
		flag.Usage()
		return errors.New("give exactly one of -out or -restore")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Hour)
	defer cancel()
	client, err := mongodb.Connect(ctx, uri)
	if err != nil {
		return err
	}
	defer client.Disconnect(context.Background())
	db := client.Database(name)

	if *out != "" {
		m, err := backup.Export(ctx, db, *out)
		if err != nil {
			return err
		}
		fmt.Printf("Saved %d collections from %s to %s\n", len(m.Collections), name, *out)
		return nil
	}
	m, err := backup.Import(ctx, db, *restore, *replace)
	if err != nil {
		return err
	}
	fmt.Printf("Restored %d collections from %s (taken %s) into %s\n",
		len(m.Collections), *restore, m.CreatedAt.Format(time.RFC3339), name)
	return nil
}
