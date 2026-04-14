package storage

import (
	"errors"

	"github.com/jackc/pgx/v5/pgconn"
)

var (
	ErrNotFound               = errors.New("not found")
	ErrConcurrentStateChanged = errors.New("concurrent state changed")
)

func IsConstraintViolation(err error, constraint string) bool {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		return false
	}
	switch pgErr.Code {
	case "23503", "23505", "23514":
		return constraint == "" || pgErr.ConstraintName == constraint
	default:
		return false
	}
}
