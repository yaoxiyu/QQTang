package storage

import (
	"context"
	"time"
)

type MatchResultRecord struct {
	MatchID           string
	AssignmentID      string
	RoomID            string
	RoomKind          string
	SeasonID          string
	ModeID            string
	RuleSetID         string
	MapID             string
	FinishReason      string
	ScorePolicy       string
	WinnerTeamIDsJSON string
	WinnerPeerIDsJSON string
	StartedAt         *time.Time
	FinishedAt        time.Time
	ResultHash        string
	FinalizeRevision  int
}

type PlayerMatchResultRecord struct {
	MatchID          string
	AccountID        string
	ProfileID        string
	TeamID           int
	PeerID           int
	Outcome          string
	PlayerScore      int
	TeamScore        int
	Placement        int
	RatingBefore     int
	RatingDelta      int
	RatingAfter      int
	SeasonPointDelta int
	CareerXPDelta    int
	GoldDelta        int
}

type FinalizeRepository struct {
	db DBTX
}

func NewFinalizeRepository(db DBTX) *FinalizeRepository {
	return &FinalizeRepository{db: db}
}

func (r *FinalizeRepository) FindMatchResult(ctx context.Context, matchID string) (MatchResultRecord, error) {
	var record MatchResultRecord
	var startedAt *time.Time
	err := r.db.QueryRow(ctx, `
		SELECT match_id, assignment_id, room_id, room_kind, season_id, mode_id, rule_set_id, map_id,
		       finish_reason, score_policy, winner_team_ids_json::text, winner_peer_ids_json::text,
		       started_at, finished_at, result_hash, finalize_revision
		FROM match_results
		WHERE match_id = $1
	`, matchID).Scan(
		&record.MatchID, &record.AssignmentID, &record.RoomID, &record.RoomKind, &record.SeasonID, &record.ModeID,
		&record.RuleSetID, &record.MapID, &record.FinishReason, &record.ScorePolicy, &record.WinnerTeamIDsJSON,
		&record.WinnerPeerIDsJSON, &startedAt, &record.FinishedAt, &record.ResultHash, &record.FinalizeRevision,
	)
	if err != nil {
		return MatchResultRecord{}, mapNotFound(err)
	}
	record.StartedAt = startedAt
	return record, nil
}

func (r *FinalizeRepository) InsertMatchResult(ctx context.Context, record MatchResultRecord) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO match_results (
			match_id, assignment_id, room_id, room_kind, season_id, mode_id, rule_set_id, map_id,
			finish_reason, score_policy, winner_team_ids_json, winner_peer_ids_json, started_at,
			finished_at, result_hash, finalize_revision, created_at, updated_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12::jsonb,$13,$14,$15,$16,NOW(),NOW()
		)
	`, record.MatchID, record.AssignmentID, record.RoomID, record.RoomKind, record.SeasonID, record.ModeID,
		record.RuleSetID, record.MapID, record.FinishReason, record.ScorePolicy, record.WinnerTeamIDsJSON,
		record.WinnerPeerIDsJSON, record.StartedAt, record.FinishedAt, record.ResultHash, record.FinalizeRevision)
	return err
}

func (r *FinalizeRepository) InsertPlayerMatchResult(ctx context.Context, record PlayerMatchResultRecord) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO player_match_results (
			match_id, account_id, profile_id, team_id, peer_id, outcome, player_score, team_score, placement,
			rating_before, rating_delta, rating_after, season_point_delta, career_xp_delta, gold_delta, created_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,NOW()
		)
	`, record.MatchID, record.AccountID, record.ProfileID, record.TeamID, record.PeerID, record.Outcome,
		record.PlayerScore, record.TeamScore, record.Placement, record.RatingBefore, record.RatingDelta,
		record.RatingAfter, record.SeasonPointDelta, record.CareerXPDelta, record.GoldDelta)
	return err
}
