// Package backup exports every collection to gzipped files, and restores them.
//
// Each collection becomes <name>.jsonl.gz: one canonical Extended JSON
// document per line, so types such as dates and 64-bit integers survive the
// round trip exactly. A manifest records what was written. Indexes are not
// saved; the API creates them when it starts.
package backup

import (
	"bufio"
	"compress/gzip"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

const (
	manifestName = "manifest.json"
	suffix       = ".jsonl.gz"
	batchSize    = 500
	// maxLine allows for the largest document MongoDB stores.
	maxLine = 64 << 20
)

// Manifest describes one backup.
type Manifest struct {
	Database    string           `json:"database"`
	CreatedAt   time.Time        `json:"created_at"`
	Collections map[string]int64 `json:"collections"`
}

// Export writes every collection of db into dir, which must not exist yet,
// so a backup is never mixed with an older one.
func Export(ctx context.Context, db *mongo.Database, dir string) (*Manifest, error) {
	if _, err := os.Stat(dir); err == nil {
		return nil, fmt.Errorf("%s already exists; choose a new folder", dir)
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	names, err := db.ListCollectionNames(ctx, bson.M{"type": "collection"})
	if err != nil {
		return nil, fmt.Errorf("list collections: %w", err)
	}
	slices.Sort(names)
	m := &Manifest{Database: db.Name(), CreatedAt: time.Now().UTC(), Collections: map[string]int64{}}
	for _, name := range names {
		if strings.HasPrefix(name, "system.") {
			continue
		}
		n, err := exportOne(ctx, db.Collection(name), filepath.Join(dir, name+suffix))
		if err != nil {
			return nil, fmt.Errorf("export %s: %w", name, err)
		}
		m.Collections[name] = n
	}
	body, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return nil, err
	}
	// The manifest is written last: a folder without one is an unfinished
	// backup and Import refuses it.
	if err := os.WriteFile(filepath.Join(dir, manifestName), body, 0o600); err != nil {
		return nil, err
	}
	return m, nil
}

func exportOne(ctx context.Context, c *mongo.Collection, path string) (int64, error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	gz := gzip.NewWriter(f)
	w := bufio.NewWriter(gz)
	cur, err := c.Find(ctx, bson.M{})
	if err != nil {
		return 0, err
	}
	defer cur.Close(ctx)
	var n int64
	for cur.Next(ctx) {
		line, err := bson.MarshalExtJSON(cur.Current, true, false)
		if err != nil {
			return 0, err
		}
		w.Write(line)
		w.WriteByte('\n')
		n++
	}
	if err := cur.Err(); err != nil {
		return 0, err
	}
	if err := w.Flush(); err != nil {
		return 0, err
	}
	if err := gz.Close(); err != nil {
		return 0, err
	}
	return n, f.Sync()
}

// ErrNotEmpty stops a restore from mixing a backup into live data.
var ErrNotEmpty = errors.New("the target database already has data; restore into a new database name, or pass replace")

// Import restores a backup into db. With replace, existing collections that
// the backup contains are dropped first; otherwise db must be empty.
func Import(ctx context.Context, db *mongo.Database, dir string, replace bool) (*Manifest, error) {
	body, err := os.ReadFile(filepath.Join(dir, manifestName))
	if err != nil {
		return nil, fmt.Errorf("read manifest (is this a finished backup?): %w", err)
	}
	var m Manifest
	if err := json.Unmarshal(body, &m); err != nil {
		return nil, fmt.Errorf("read manifest: %w", err)
	}
	existing, err := db.ListCollectionNames(ctx, bson.M{"type": "collection"})
	if err != nil {
		return nil, fmt.Errorf("list collections: %w", err)
	}
	for _, name := range existing {
		if _, inBackup := m.Collections[name]; !inBackup {
			continue
		}
		n, err := db.Collection(name).EstimatedDocumentCount(ctx)
		if err != nil {
			return nil, err
		}
		if n > 0 && !replace {
			return nil, ErrNotEmpty
		}
	}
	for name, want := range m.Collections {
		c := db.Collection(name)
		if replace {
			if err := c.Drop(ctx); err != nil {
				return nil, fmt.Errorf("drop %s: %w", name, err)
			}
		}
		got, err := importOne(ctx, c, filepath.Join(dir, name+suffix))
		if err != nil {
			return nil, fmt.Errorf("restore %s: %w", name, err)
		}
		if got != want {
			return nil, fmt.Errorf("restore %s: read %d documents, the manifest says %d", name, got, want)
		}
	}
	return &m, nil
}

func importOne(ctx context.Context, c *mongo.Collection, path string) (int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		return 0, err
	}
	defer gz.Close()
	scan := bufio.NewScanner(gz)
	scan.Buffer(make([]byte, 0, 1<<20), maxLine)
	var n int64
	batch := make([]any, 0, batchSize)
	flush := func() error {
		if len(batch) == 0 {
			return nil
		}
		if _, err := c.InsertMany(ctx, batch); err != nil {
			return err
		}
		batch = batch[:0]
		return nil
	}
	for scan.Scan() {
		var doc bson.Raw
		if err := bson.UnmarshalExtJSON(scan.Bytes(), true, &doc); err != nil {
			return 0, fmt.Errorf("line %d: %w", n+1, err)
		}
		batch = append(batch, doc)
		n++
		if len(batch) == batchSize {
			if err := flush(); err != nil {
				return 0, err
			}
		}
	}
	if err := scan.Err(); err != nil {
		return 0, err
	}
	return n, flush()
}
