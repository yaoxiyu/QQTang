package storage

import (
	"context"
	"time"
)

type PartyQueueMember struct {
	PartyQueueEntryID string
	AccountID         string
	ProfileID         string
	DeviceSessionID   string
	SeatIndex         int
	RatingSnapshot    int
	CreatedAt         time.Time
	UpdatedAt         time.Time
}

type PartyQueueMemberRepository struct {
	db DBTX
}

func NewPartyQueueMemberRepository(db DBTX) *PartyQueueMemberRepository {
	return &PartyQueueMemberRepository{db: db}
}

func (r *PartyQueueMemberRepository) Insert(ctx context.Context, member PartyQueueMember) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO matchmaking_party_queue_members (
			party_queue_entry_id, account_id, profile_id, device_session_id,
			seat_index, rating_snapshot, created_at, updated_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8
		)
	`, member.PartyQueueEntryID, member.AccountID, member.ProfileID, member.DeviceSessionID,
		member.SeatIndex, member.RatingSnapshot, member.CreatedAt, member.UpdatedAt)
	return err
}

func (r *PartyQueueMemberRepository) ListByEntryID(ctx context.Context, entryID string) ([]PartyQueueMember, error) {
	rows, err := r.db.Query(ctx, `
		SELECT party_queue_entry_id, account_id, profile_id, device_session_id,
		       seat_index, rating_snapshot, created_at, updated_at
		FROM matchmaking_party_queue_members
		WHERE party_queue_entry_id = $1
		ORDER BY seat_index ASC, created_at ASC
	`, entryID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	members := []PartyQueueMember{}
	for rows.Next() {
		var member PartyQueueMember
		if err := rows.Scan(
			&member.PartyQueueEntryID,
			&member.AccountID,
			&member.ProfileID,
			&member.DeviceSessionID,
			&member.SeatIndex,
			&member.RatingSnapshot,
			&member.CreatedAt,
			&member.UpdatedAt,
		); err != nil {
			return nil, err
		}
		members = append(members, member)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return members, nil
}
