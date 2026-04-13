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
	if got := int(summary.CareerSummary["career_total_matches"].(int32)); got != 1 {
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
	if err := applyFinalizeMigration(context.Background(), pool); err != nil {
		t.Fatalf("apply migration: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	return pool
}

func applyFinalizeMigration(ctx context.Context, pool *pgxpool.Pool) error {
	migrationPath := filepath.Join("..", "..", "migrations", "0001_phase20_matchmaking_and_progression_init.sql")
	sqlBytes, err := os.ReadFile(migrationPath)
	if err != nil {
		return err
	}
	_, err = pool.Exec(ctx, string(sqlBytes))
	return err
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
