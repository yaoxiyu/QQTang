package storage

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"
)

type RoomEntryTicketRecord struct {
	TicketID         string
	AccountID        string
	ProfileID        string
	DeviceSessionID  string
	RoomID           sql.NullString
	RoomKind         sql.NullString
	Purpose          string
	RequestedMatchID sql.NullString
	ClaimsJSON       json.RawMessage
	IssuedAt         time.Time
	ExpireAt         time.Time
	ConsumedAt       sql.NullTime
}

type TicketRepository struct {
	db *sql.DB
}

func NewTicketRepository(db *sql.DB) *TicketRepository {
	return &TicketRepository{db: db}
}

func (r *TicketRepository) Create(ctx context.Context, record RoomEntryTicketRecord) error {
	_, err := r.db.ExecContext(
		ctx,
		`INSERT INTO room_entry_tickets (
			ticket_id,
			account_id,
			profile_id,
			device_session_id,
			room_id,
			room_kind,
			purpose,
			requested_match_id,
			claims_json,
			issued_at,
			expire_at,
			consumed_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
		record.TicketID,
		record.AccountID,
		record.ProfileID,
		record.DeviceSessionID,
		nullStringValue(record.RoomID),
		nullStringValue(record.RoomKind),
		record.Purpose,
		nullStringValue(record.RequestedMatchID),
		[]byte(record.ClaimsJSON),
		record.IssuedAt,
		record.ExpireAt,
		record.ConsumedAt,
	)
	return err
}

func (r *TicketRepository) FindByID(ctx context.Context, ticketID string) (RoomEntryTicketRecord, error) {
	row := r.db.QueryRowContext(
		ctx,
		`SELECT
			ticket_id,
			account_id,
			profile_id,
			device_session_id,
			room_id,
			room_kind,
			purpose,
			requested_match_id,
			claims_json,
			issued_at,
			expire_at,
			consumed_at
		FROM room_entry_tickets
		WHERE ticket_id = $1`,
		ticketID,
	)
	var record RoomEntryTicketRecord
	err := row.Scan(
		&record.TicketID,
		&record.AccountID,
		&record.ProfileID,
		&record.DeviceSessionID,
		&record.RoomID,
		&record.RoomKind,
		&record.Purpose,
		&record.RequestedMatchID,
		&record.ClaimsJSON,
		&record.IssuedAt,
		&record.ExpireAt,
		&record.ConsumedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return RoomEntryTicketRecord{}, ErrNotFound
	}
	return record, err
}

func (r *TicketRepository) MarkConsumed(ctx context.Context, ticketID string, consumedAt time.Time) error {
	_, err := r.db.ExecContext(
		ctx,
		`UPDATE room_entry_tickets
		SET consumed_at = $2
		WHERE ticket_id = $1`,
		ticketID,
		consumedAt,
	)
	return err
}
