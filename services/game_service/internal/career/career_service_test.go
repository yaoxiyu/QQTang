package career

import (
	"context"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"qqtang/services/game_service/internal/storage"
)

type fakeCareerRow struct {
	values []any
	err    error
}

func (r fakeCareerRow) Scan(dest ...any) error {
	if r.err != nil {
		return r.err
	}
	for idx := range dest {
		reflect.ValueOf(dest[idx]).Elem().Set(reflect.ValueOf(r.values[idx]))
	}
	return nil
}

type fakeCareerDB struct {
	summaryByProfile map[string]storage.CareerSummary
	snapshotByKey    map[string]storage.SeasonRatingSnapshot
}

func newFakeCareerDB() *fakeCareerDB {
	return &fakeCareerDB{
		summaryByProfile: map[string]storage.CareerSummary{},
		snapshotByKey:    map[string]storage.SeasonRatingSnapshot{},
	}
}

func (db *fakeCareerDB) Exec(_ context.Context, _ string, _ ...any) (pgconn.CommandTag, error) {
	return pgconn.NewCommandTag("OK"), nil
}

func (db *fakeCareerDB) Query(_ context.Context, _ string, _ ...any) (pgx.Rows, error) {
	return nil, nil
}

func (db *fakeCareerDB) QueryRow(_ context.Context, sql string, args ...any) pgx.Row {
	switch {
	case strings.Contains(sql, "FROM career_summaries"):
		profileID := args[0].(string)
		summary, ok := db.summaryByProfile[profileID]
		if !ok {
			return fakeCareerRow{err: pgx.ErrNoRows}
		}
		return fakeCareerRow{values: []any{
			summary.ProfileID,
			summary.AccountID,
			summary.TotalMatches,
			summary.TotalWins,
			summary.TotalLosses,
			summary.TotalDraws,
			summary.WinRateBP,
			summary.CurrentSeasonID,
			summary.CurrentRating,
			summary.CurrentRankTier,
			summary.LastMatchID,
			summary.LastMatchOutcome,
			summary.LastMatchFinishedAt,
			summary.UpdatedAt,
		}}
	case strings.Contains(sql, "FROM season_rating_snapshots"):
		key := args[0].(string) + "|" + args[1].(string)
		snapshot, ok := db.snapshotByKey[key]
		if !ok {
			return fakeCareerRow{err: pgx.ErrNoRows}
		}
		return fakeCareerRow{values: []any{
			snapshot.SeasonID,
			snapshot.AccountID,
			snapshot.ProfileID,
			snapshot.Rating,
			snapshot.RankTier,
			snapshot.MatchesPlayed,
			snapshot.Wins,
			snapshot.Losses,
			snapshot.Draws,
			snapshot.LastMatchID,
		}}
	default:
		return fakeCareerRow{err: pgx.ErrNoRows}
	}
}

func TestGetSummaryReturnsDefaultWhenCareerMissing(t *testing.T) {
	db := newFakeCareerDB()
	service := NewService(storage.NewCareerRepository(db), storage.NewRatingRepository(db))

	summary, err := service.GetSummary(context.Background(), "account_1", "profile_1")
	if err != nil {
		t.Fatalf("GetSummary returned error: %v", err)
	}
	if summary.SummaryState != "missing" {
		t.Fatalf("expected missing summary state, got %s", summary.SummaryState)
	}
	if summary.CurrentRating != 1000 || summary.CurrentRankTier != "bronze" {
		t.Fatalf("unexpected default rating view: %+v", summary)
	}
}

func TestGetSummaryRefreshesCareerAndSeasonSnapshot(t *testing.T) {
	db := newFakeCareerDB()
	now := time.Now().UTC()
	lastFinishedAt := now.Add(-time.Minute)
	db.summaryByProfile["profile_1"] = storage.CareerSummary{
		ProfileID:           "profile_1",
		AccountID:           "account_1",
		TotalMatches:        8,
		TotalWins:           5,
		TotalLosses:         2,
		TotalDraws:          1,
		WinRateBP:           6250,
		CurrentSeasonID:     "season_s1",
		CurrentRating:       1010,
		CurrentRankTier:     "silver",
		LastMatchID:         "match_8",
		LastMatchOutcome:    "win",
		LastMatchFinishedAt: &lastFinishedAt,
		UpdatedAt:           now,
	}
	db.snapshotByKey["season_s1|account_1"] = storage.SeasonRatingSnapshot{
		SeasonID:      "season_s1",
		AccountID:     "account_1",
		ProfileID:     "profile_1",
		Rating:        1048,
		RankTier:      "gold",
		MatchesPlayed: 6,
		Wins:          4,
		Losses:        1,
		Draws:         1,
		LastMatchID:   "match_8",
	}
	service := NewService(storage.NewCareerRepository(db), storage.NewRatingRepository(db))

	summary, err := service.GetSummary(context.Background(), "account_1", "profile_1")
	if err != nil {
		t.Fatalf("GetSummary returned error: %v", err)
	}
	if summary.SummaryState != "ready" {
		t.Fatalf("expected ready summary state, got %s", summary.SummaryState)
	}
	if summary.CurrentRating != 1048 || summary.CurrentRankTier != "gold" {
		t.Fatalf("expected snapshot rating to win, got rating=%d tier=%s", summary.CurrentRating, summary.CurrentRankTier)
	}
	if summary.CareerTotalMatches != 8 || summary.SeasonMatchesPlayed != 6 {
		t.Fatalf("unexpected career refresh view: %+v", summary)
	}
}
