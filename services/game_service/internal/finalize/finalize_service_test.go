package finalize

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"qqtang/services/game_service/internal/rating"
	"qqtang/services/game_service/internal/reward"
	"qqtang/services/game_service/internal/storage"
)

func TestFinalizeIdempotenceAndCareerRefresh(t *testing.T) {
	pool := openFinalizeTestPool(t)
	if pool == nil {
		return
	}
	ctx := context.Background()
	resetFinalizeSchema(t, ctx, pool)
	seedFinalizeAssignment(t, ctx, pool, "assign_a", "match_a")
	service := NewService(pool, rating.NewEloService(), reward.NewService())
	input := buildFinalizeInput("assign_a", "match_a", "sha256:stable")

	first, err := service.Finalize(ctx, input)
	if err != nil {
		t.Fatalf("first finalize failed: %v", err)
	}
	if first.AlreadyCommitted {
		t.Fatal("first finalize should not be marked as already committed")
	}
	second, err := service.Finalize(ctx, input)
	if err != nil {
		t.Fatalf("second finalize failed: %v", err)
	}
	if !second.AlreadyCommitted {
		t.Fatal("second finalize should be idempotent and already committed")
	}

	var ledgerCount int
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM reward_ledger_entries WHERE match_id = $1`, "match_a").Scan(&ledgerCount); err != nil {
		t.Fatalf("count reward ledger: %v", err)
	}
	if ledgerCount != 6 {
		t.Fatalf("expected exactly 6 reward ledger entries after duplicate finalize, got %d", ledgerCount)
	}

	summary, err := service.GetMatchSummary(ctx, "match_a", "account_a", "profile_a")
	if err != nil {
		t.Fatalf("GetMatchSummary failed: %v", err)
	}
	if summary.ServerSyncState != "committed" {
		t.Fatalf("expected committed summary, got %s", summary.ServerSyncState)
	}
	if got := summaryInt(summary.CareerSummary["career_total_matches"]); got != 1 {
		t.Fatalf("expected career total matches 1, got %d", got)
	}
}

func TestFinalizeHashMismatch(t *testing.T) {
	pool := openFinalizeTestPool(t)
	if pool == nil {
		return
	}
	ctx := context.Background()
	resetFinalizeSchema(t, ctx, pool)
	seedFinalizeAssignment(t, ctx, pool, "assign_b", "match_b")
	service := NewService(pool, rating.NewEloService(), reward.NewService())

	if _, err := service.Finalize(ctx, buildFinalizeInput("assign_b", "match_b", "sha256:first")); err != nil {
		t.Fatalf("initial finalize failed: %v", err)
	}
	_, err := service.Finalize(ctx, buildFinalizeInput("assign_b", "match_b", "sha256:second"))
	if !errors.Is(err, ErrFinalizeHashMismatch) {
		t.Fatalf("expected ErrFinalizeHashMismatch, got %v", err)
	}
}

func TestFinalizeDataIntegrityConstraints(t *testing.T) {
	pool := openFinalizeTestPool(t)
	if pool == nil {
		return
	}
	ctx := context.Background()
	resetFinalizeSchema(t, ctx, pool)
	seedFinalizeAssignment(t, ctx, pool, "assign_constraints", "match_constraints")

	finalizeRepo := storage.NewFinalizeRepository(pool)
	finishedAt := time.Now().UTC()
	if err := finalizeRepo.InsertMatchResult(ctx, storage.MatchResultRecord{
		MatchID:           "match_constraints",
		AssignmentID:      "assign_constraints",
		RoomID:            "room_alpha",
		RoomKind:          "matchmade_room",
		SeasonID:          "season_s1",
		ModeID:            "mode_ranked",
		RuleSetID:         "rule_standard",
		MapID:             "map_arcade",
		FinishReason:      "last_survivor",
		ScorePolicy:       "team_score",
		WinnerTeamIDsJSON: "[]",
		WinnerPeerIDsJSON: "[]",
		FinishedAt:        finishedAt,
		ResultHash:        "sha256:constraints",
		FinalizeRevision:  1,
	}); err != nil {
		t.Fatalf("insert baseline match result: %v", err)
	}

	err := finalizeRepo.InsertMatchResult(ctx, storage.MatchResultRecord{
		MatchID:           "match_constraints_second",
		AssignmentID:      "assign_constraints",
		RoomID:            "room_alpha",
		RoomKind:          "matchmade_room",
		SeasonID:          "season_s1",
		ModeID:            "mode_ranked",
		RuleSetID:         "rule_standard",
		MapID:             "map_arcade",
		FinishReason:      "last_survivor",
		ScorePolicy:       "team_score",
		WinnerTeamIDsJSON: "[]",
		WinnerPeerIDsJSON: "[]",
		FinishedAt:        finishedAt,
		ResultHash:        "sha256:constraints-second",
		FinalizeRevision:  1,
	})
	if !storage.IsConstraintViolation(err, "uq_match_results_assignment") {
		t.Fatalf("expected assignment finalize uniqueness violation, got %v", err)
	}

	err = finalizeRepo.InsertPlayerMatchResult(ctx, storage.PlayerMatchResultRecord{
		MatchID:      "match_constraints",
		AccountID:    "account_a",
		ProfileID:    "profile_a",
		TeamID:       1,
		PeerID:       1,
		Outcome:      "cheated",
		RatingBefore: 1000,
		RatingDelta:  0,
		RatingAfter:  1000,
	})
	if !storage.IsConstraintViolation(err, "chk_player_match_results_outcome") {
		t.Fatalf("expected player outcome check violation, got %v", err)
	}

	rewardRepo := storage.NewRewardRepository(pool)
	entry := storage.RewardLedgerEntry{
		LedgerID:   "ledger_constraints_a",
		AccountID:  "account_a",
		ProfileID:  "profile_a",
		MatchID:    "match_constraints",
		RewardType: "soft_gold",
		Delta:      10,
		SourceType: "match_finalize",
		ExtraJSON:  "{}",
		IssuedAt:   finishedAt,
	}
	if err := rewardRepo.Insert(ctx, entry); err != nil {
		t.Fatalf("insert baseline reward ledger: %v", err)
	}
	entry.LedgerID = "ledger_constraints_b"
	err = rewardRepo.Insert(ctx, entry)
	if !storage.IsConstraintViolation(err, "uq_reward_ledger_entries_match_account_type_source") {
		t.Fatalf("expected reward ledger uniqueness violation, got %v", err)
	}

	ratingRepo := storage.NewRatingRepository(pool)
	err = ratingRepo.UpsertSnapshot(ctx, storage.SeasonRatingSnapshot{
		SeasonID:      "season_s1",
		AccountID:     "account_a",
		ProfileID:     "profile_a",
		Rating:        1000,
		RankTier:      "mythic",
		MatchesPlayed: 1,
		Wins:          1,
		LastMatchID:   "match_constraints",
	})
	if !storage.IsConstraintViolation(err, "chk_season_rating_snapshots_rank_tier") {
		t.Fatalf("expected rating rank tier check violation, got %v", err)
	}
}

func openFinalizeTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := strings.TrimSpace(os.Getenv("GAME_TEST_POSTGRES_DSN"))
	if dsn == "" {
		t.Skip("GAME_TEST_POSTGRES_DSN is not set; skipping finalize integration tests")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("open pgx pool: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	lockGameTestDatabase(t, pool)
	if err := applyFinalizeMigration(context.Background(), pool); err != nil {
		t.Fatalf("apply migration: %v", err)
	}
	return pool
}

func lockGameTestDatabase(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()
	conn, err := pool.Acquire(ctx)
	if err != nil {
		t.Fatalf("acquire db lock connection: %v", err)
	}
	deadline := time.Now().Add(2 * time.Minute)
	for {
		var locked bool
		if err := conn.QueryRow(ctx, `SELECT pg_try_advisory_lock(240031013)`).Scan(&locked); err != nil {
			conn.Release()
			t.Fatalf("acquire db advisory lock: %v", err)
		}
		if locked {
			break
		}
		if time.Now().After(deadline) {
			conn.Release()
			t.Fatal("timed out waiting for db advisory lock")
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Cleanup(func() {
		_, _ = conn.Exec(context.Background(), `SELECT pg_advisory_unlock(240031013)`)
		conn.Release()
	})
}

func applyFinalizeMigration(ctx context.Context, pool *pgxpool.Pool) error {
	migrationDir := filepath.Join("..", "..", "migrations")
	entries, err := os.ReadDir(migrationDir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".sql") {
			continue
		}
		migrationPath := filepath.Join(migrationDir, entry.Name())
		sqlBytes, err := os.ReadFile(migrationPath)
		if err != nil {
			return err
		}
		if _, err := pool.Exec(ctx, string(sqlBytes)); err != nil {
			return err
		}
	}
	return nil
}

func resetFinalizeSchema(t *testing.T, ctx context.Context, pool *pgxpool.Pool) {
	t.Helper()
	_, err := pool.Exec(ctx, `
		TRUNCATE TABLE
			reward_ledger_entries,
			player_match_results,
			match_results,
			career_summaries,
			season_rating_snapshots,
			matchmaking_assignment_members,
			matchmaking_assignments
		CASCADE
	`)
	if err != nil {
		t.Fatalf("reset schema: %v", err)
	}
}

func seedFinalizeAssignment(t *testing.T, ctx context.Context, pool *pgxpool.Pool, assignmentID string, matchID string) {
	t.Helper()
	now := time.Now().UTC()
	_, err := pool.Exec(ctx, `
		INSERT INTO matchmaking_assignments (
			assignment_id, queue_key, queue_type, season_id, room_id, room_kind, match_id,
			mode_id, rule_set_id, map_id, server_host, server_port, captain_account_id,
			assignment_revision, expected_member_count, state, captain_deadline_unix_sec,
			commit_deadline_unix_sec, created_at, updated_at
		) VALUES (
			$1, 'ranked:mode:rule', 'ranked', 'season_s1', 'room_alpha', 'matchmade_room', $2,
			'mode_ranked', 'rule_standard', 'map_arcade', '127.0.0.1', 9000, 'account_a',
			1, 2, 'assigned', $3, $4, NOW(), NOW()
		)
	`, assignmentID, matchID, now.Add(time.Minute).Unix(), now.Add(5*time.Minute).Unix())
	if err != nil {
		t.Fatalf("insert assignment: %v", err)
	}
	_, err = pool.Exec(ctx, `
		INSERT INTO matchmaking_assignment_members (
			assignment_id, account_id, profile_id, ticket_role, assigned_team_id, rating_before, join_state, result_state
		) VALUES
			($1, 'account_a', 'profile_a', 'create', 1, 1000, 'assigned', ''),
			($1, 'account_b', 'profile_b', 'join', 2, 1000, 'assigned', '')
	`, assignmentID)
	if err != nil {
		t.Fatalf("insert assignment members: %v", err)
	}
}

func buildFinalizeInput(assignmentID string, matchID string, resultHash string) FinalizeInput {
	finishedAt := time.Now().UTC()
	return FinalizeInput{
		MatchID:      matchID,
		AssignmentID: assignmentID,
		RoomID:       "room_alpha",
		RoomKind:     "matchmade_room",
		SeasonID:     "season_s1",
		ModeID:       "mode_ranked",
		RuleSetID:    "rule_standard",
		MapID:        "map_arcade",
		FinishedAt:   finishedAt,
		FinishReason: "last_survivor",
		ScorePolicy:  "team_score",
		WinnerTeamIDs: []int{
			1,
		},
		ResultHash: resultHash,
		MemberResults: []MemberResultInput{
			{AccountID: "account_a", ProfileID: "profile_a", TeamID: 1, PeerID: 1, Outcome: "win", PlayerScore: 5, TeamScore: 10, Placement: 1},
			{AccountID: "account_b", ProfileID: "profile_b", TeamID: 2, PeerID: 2, Outcome: "loss", PlayerScore: 1, TeamScore: 4, Placement: 2},
		},
	}
}

func summaryInt(value any) int {
	switch typed := value.(type) {
	case int:
		return typed
	case int32:
		return int(typed)
	case int64:
		return int(typed)
	default:
		return 0
	}
}
