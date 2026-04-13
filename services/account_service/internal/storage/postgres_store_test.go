package storage

import (
	"context"
	"testing"
)

func TestNewPostgresStoreRejectsInvalidDSN(t *testing.T) {
	_, err := NewPostgresStore(context.Background(), "://bad-dsn", false)
	if err == nil {
		t.Fatal("expected invalid dsn error")
	}
}

func TestPostgresStorePingOnNilStore(t *testing.T) {
	var store *PostgresStore
	if err := store.Ping(context.Background()); err != ErrStoreUnavailable {
		t.Fatalf("expected ErrStoreUnavailable, got %v", err)
	}
}
