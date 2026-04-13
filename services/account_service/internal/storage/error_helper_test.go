package storage

import (
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
)

func TestIsConstraintViolation(t *testing.T) {
	err := &pgconn.PgError{
		Code:           uniqueViolationCode,
		ConstraintName: "uq_accounts_login_name",
	}

	if !IsConstraintViolation(err, "uq_accounts_login_name") {
		t.Fatal("expected exact constraint violation to match")
	}
	if !IsConstraintViolation(err, "") {
		t.Fatal("expected generic unique violation to match empty constraint filter")
	}
	if IsConstraintViolation(err, "uq_other") {
		t.Fatal("did not expect mismatched constraint name to match")
	}
}

func TestIsConstraintViolationFalseOnWrappedNonPgError(t *testing.T) {
	err := errors.New("plain error")
	if IsConstraintViolation(err, "uq_accounts_login_name") {
		t.Fatal("did not expect non-pg error to match")
	}
}

func TestIsConstraintViolationFalseOnOtherCode(t *testing.T) {
	err := &pgconn.PgError{
		Code:           "23503",
		ConstraintName: "fk_player_profiles_account",
	}
	if IsConstraintViolation(err, "") {
		t.Fatal("did not expect non-unique pg error to match")
	}
}
