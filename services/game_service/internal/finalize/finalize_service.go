package finalize

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"qqtang/services/game_service/internal/rating"
	"qqtang/services/game_service/internal/reward"
	"qqtang/services/game_service/internal/storage"
)

var (
	ErrFinalizeAlreadyCommitted    = errors.New("MATCH_FINALIZE_ALREADY_COMMITTED")
	ErrFinalizeHashMismatch        = errors.New("MATCH_FINALIZE_HASH_MISMATCH")
	ErrFinalizeAssignmentNotFound  = errors.New("MATCH_FINALIZE_ASSIGNMENT_NOT_FOUND")
	ErrFinalizeMemberResultInvalid = errors.New("MATCH_FINALIZE_MEMBER_RESULT_INVALID")
	ErrSettlementMatchNotFound     = errors.New("SETTLEMENT_MATCH_NOT_FOUND")
)

type Service struct {
	pool          *pgxpool.Pool
	ratingService *rating.EloService
	rewardService *reward.Service
}

func NewService(pool *pgxpool.Pool, ratingService *rating.EloService, rewardService *reward.Service) *Service {
	return &Service{pool: pool, ratingService: ratingService, rewardService: rewardService}
}

func (s *Service) Finalize(ctx context.Context, input FinalizeInput) (FinalizeResult, error) {
	if input.MatchID == "" || input.AssignmentID == "" || len(input.MemberResults) == 0 {
		return FinalizeResult{}, ErrFinalizeMemberResultInvalid
	}

	readRepo := storage.NewFinalizeRepository(s.pool)
	existing, err := readRepo.FindMatchResult(ctx, input.MatchID)
	if err == nil {
		if existing.ResultHash != input.ResultHash {
			return FinalizeResult{}, ErrFinalizeHashMismatch
		}
		return FinalizeResult{
			FinalizeState:    "committed",
			MatchID:          existing.MatchID,
			AssignmentID:     existing.AssignmentID,
			AlreadyCommitted: true,
			ResultHash:       existing.ResultHash,
			FinalizedAt:      existing.FinishedAt,
		}, nil
	} else if !errors.Is(err, storage.ErrNotFound) {
		return FinalizeResult{}, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return FinalizeResult{}, err
	}
	defer tx.Rollback(ctx)

	assignmentRepo := storage.NewAssignmentRepository(tx)
	finalizeRepo := storage.NewFinalizeRepository(tx)
	ratingRepo := storage.NewRatingRepository(tx)
	rewardRepo := storage.NewRewardRepository(tx)
	careerRepo := storage.NewCareerRepository(tx)

	assignmentRecord, err := assignmentRepo.FindByID(ctx, input.AssignmentID)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			return FinalizeResult{}, ErrFinalizeAssignmentNotFound
		}
		return FinalizeResult{}, err
	}
	if assignmentRecord.MatchID != input.MatchID {
		return FinalizeResult{}, ErrFinalizeAssignmentNotFound
	}

	winnerTeamJSON, _ := json.Marshal(input.WinnerTeamIDs)
	winnerPeerJSON, _ := json.Marshal(input.WinnerPeerIDs)
	if err := finalizeRepo.InsertMatchResult(ctx, storage.MatchResultRecord{
		MatchID:           input.MatchID,
		AssignmentID:      input.AssignmentID,
		RoomID:            input.RoomID,
		RoomKind:          input.RoomKind,
		SeasonID:          input.SeasonID,
		ModeID:            input.ModeID,
		RuleSetID:         input.RuleSetID,
		MapID:             input.MapID,
		FinishReason:      input.FinishReason,
		ScorePolicy:       input.ScorePolicy,
		WinnerTeamIDsJSON: string(winnerTeamJSON),
		WinnerPeerIDsJSON: string(winnerPeerJSON),
		StartedAt:         input.StartedAt,
		FinishedAt:        input.FinishedAt,
		ResultHash:        input.ResultHash,
		FinalizeRevision:  1,
	}); err != nil {
		return FinalizeResult{}, err
	}

	summary := SettlementSummary{}
	finalizedAt := time.Now().UTC()
	for _, member := range input.MemberResults {
		assignmentMember, err := assignmentRepo.FindMember(ctx, input.AssignmentID, member.AccountID)
		if err != nil || assignmentMember.ProfileID != member.ProfileID {
			return FinalizeResult{}, ErrFinalizeMemberResultInvalid
		}

		snapshot, err := ratingRepo.FindSnapshot(ctx, input.SeasonID, member.AccountID)
		if err != nil && !errors.Is(err, storage.ErrNotFound) {
			return FinalizeResult{}, err
		}
		if errors.Is(err, storage.ErrNotFound) {
			snapshot = storage.SeasonRatingSnapshot{
				SeasonID:  input.SeasonID,
				AccountID: member.AccountID,
				ProfileID: member.ProfileID,
				Rating:    assignmentMember.RatingBefore,
				RankTier:  rating.MapRankTier(assignmentMember.RatingBefore),
			}
		}

		delta := s.ratingService.ComputeDelta(rating.PlayerDeltaInput{
			QueueType:    assignmentRecord.QueueType,
			RatingBefore: snapshot.Rating,
			OpponentAvg:  1000,
			Outcome:      member.Outcome,
		})
		rewardBreakdown := s.rewardService.Build(assignmentRecord.QueueType, member.Outcome)

		if err := finalizeRepo.InsertPlayerMatchResult(ctx, storage.PlayerMatchResultRecord{
			MatchID:          input.MatchID,
			AccountID:        member.AccountID,
			ProfileID:        member.ProfileID,
			TeamID:           member.TeamID,
			PeerID:           member.PeerID,
			Outcome:          member.Outcome,
			PlayerScore:      member.PlayerScore,
			TeamScore:        member.TeamScore,
			Placement:        member.Placement,
			RatingBefore:     snapshot.Rating,
			RatingDelta:      delta.RatingDelta,
			RatingAfter:      delta.RatingAfter,
			SeasonPointDelta: rewardBreakdown.SeasonPointDelta,
			CareerXPDelta:    rewardBreakdown.CareerXPDelta,
			GoldDelta:        rewardBreakdown.GoldDelta,
		}); err != nil {
			return FinalizeResult{}, err
		}

		switch member.Outcome {
		case "win":
			snapshot.Wins++
		case "loss":
			snapshot.Losses++
		default:
			snapshot.Draws++
		}
		snapshot.MatchesPlayed++
		snapshot.LastMatchID = input.MatchID
		snapshot.Rating = delta.RatingAfter
		snapshot.RankTier = rating.MapRankTier(delta.RatingAfter)
		if err := ratingRepo.UpsertSnapshot(ctx, snapshot); err != nil {
			return FinalizeResult{}, err
		}

		winRateBP := 0
		if snapshot.MatchesPlayed > 0 {
			winRateBP = snapshot.Wins * 10000 / snapshot.MatchesPlayed
		}
		if err := careerRepo.Upsert(ctx, storage.CareerSummary{
			ProfileID:           member.ProfileID,
			AccountID:           member.AccountID,
			TotalMatches:        snapshot.MatchesPlayed,
			TotalWins:           snapshot.Wins,
			TotalLosses:         snapshot.Losses,
			TotalDraws:          snapshot.Draws,
			WinRateBP:           winRateBP,
			CurrentSeasonID:     input.SeasonID,
			CurrentRating:       snapshot.Rating,
			CurrentRankTier:     snapshot.RankTier,
			LastMatchID:         input.MatchID,
			LastMatchOutcome:    member.Outcome,
			LastMatchFinishedAt: &input.FinishedAt,
		}); err != nil {
			return FinalizeResult{}, err
		}

		rewardRows := []struct {
			rewardType string
			delta      int
		}{
			{"season_point", rewardBreakdown.SeasonPointDelta},
			{"career_xp", rewardBreakdown.CareerXPDelta},
			{"soft_gold", rewardBreakdown.GoldDelta},
		}
		for _, row := range rewardRows {
			if row.delta == 0 {
				continue
			}
			id, err := ledgerID()
			if err != nil {
				return FinalizeResult{}, err
			}
			if err := rewardRepo.Insert(ctx, storage.RewardLedgerEntry{
				LedgerID:   id,
				AccountID:  member.AccountID,
				ProfileID:  member.ProfileID,
				MatchID:    input.MatchID,
				RewardType: row.rewardType,
				Delta:      row.delta,
				SourceType: "match_finalize",
				ExtraJSON:  "{}",
				IssuedAt:   finalizedAt,
			}); err != nil {
				return FinalizeResult{}, err
			}
		}

		summary.ProfileCount++
		summary.SeasonPointTotal += rewardBreakdown.SeasonPointDelta
		summary.CareerXPTotal += rewardBreakdown.CareerXPDelta
		summary.SoftGoldTotal += rewardBreakdown.GoldDelta
	}

	if err := assignmentRepo.MarkFinalized(ctx, input.AssignmentID, finalizedAt); err != nil {
		return FinalizeResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return FinalizeResult{}, err
	}

	return FinalizeResult{
		FinalizeState:     "committed",
		MatchID:           input.MatchID,
		AssignmentID:      input.AssignmentID,
		ResultHash:        input.ResultHash,
		SettlementSummary: summary,
		FinalizedAt:       finalizedAt,
	}, nil
}

func (s *Service) GetMatchSummary(ctx context.Context, matchID string, accountID string, profileID string) (MatchSummaryView, error) {
	type summaryRow struct {
		Outcome             string
		RatingBefore        int
		RatingDelta         int
		RatingAfter         int
		SeasonPointDelta    int
		CareerXPDelta       int
		GoldDelta           int
		RankTierAfter       string
		CurrentSeasonID     string
		CurrentRating       int
		CurrentRankTier     string
		TotalMatches        int
		TotalWins           int
		TotalLosses         int
		TotalDraws          int
		WinRateBP           int
		LastMatchID         string
		LastMatchOutcome    string
		LastMatchFinishedAt *time.Time
	}

	var row summaryRow
	err := s.pool.QueryRow(ctx, `
		SELECT pmr.outcome, pmr.rating_before, pmr.rating_delta, pmr.rating_after, pmr.season_point_delta,
		       pmr.career_xp_delta, pmr.gold_delta, srs.rank_tier, cs.current_season_id, cs.current_rating,
		       cs.current_rank_tier, cs.total_matches, cs.total_wins, cs.total_losses, cs.total_draws,
		       cs.win_rate_bp, cs.last_match_id, cs.last_match_outcome, cs.last_match_finished_at
		FROM player_match_results pmr
		JOIN season_rating_snapshots srs
		  ON srs.account_id = pmr.account_id AND srs.last_match_id = pmr.match_id
		JOIN career_summaries cs
		  ON cs.profile_id = pmr.profile_id
		WHERE pmr.match_id = $1 AND pmr.account_id = $2 AND pmr.profile_id = $3
		LIMIT 1
	`, matchID, accountID, profileID).Scan(
		&row.Outcome, &row.RatingBefore, &row.RatingDelta, &row.RatingAfter, &row.SeasonPointDelta,
		&row.CareerXPDelta, &row.GoldDelta, &row.RankTierAfter, &row.CurrentSeasonID, &row.CurrentRating,
		&row.CurrentRankTier, &row.TotalMatches, &row.TotalWins, &row.TotalLosses, &row.TotalDraws,
		&row.WinRateBP, &row.LastMatchID, &row.LastMatchOutcome, &row.LastMatchFinishedAt,
	)
	if err != nil {
		return MatchSummaryView{
			MatchID:         matchID,
			ProfileID:       profileID,
			ServerSyncState: "pending",
			CareerSummary:   map[string]any{},
			RewardSummary:   []map[string]any{},
			UpdatedAt:       time.Now().UTC(),
		}, nil
	}

	return MatchSummaryView{
		MatchID:          matchID,
		ProfileID:        profileID,
		ServerSyncState:  "committed",
		Outcome:          row.Outcome,
		RatingBefore:     row.RatingBefore,
		RatingDelta:      row.RatingDelta,
		RatingAfter:      row.RatingAfter,
		RankTierAfter:    row.RankTierAfter,
		SeasonPointDelta: row.SeasonPointDelta,
		CareerXPDelta:    row.CareerXPDelta,
		GoldDelta:        row.GoldDelta,
		RewardSummary: []map[string]any{
			{"reward_type": "season_point", "delta": row.SeasonPointDelta},
			{"reward_type": "career_xp", "delta": row.CareerXPDelta},
			{"reward_type": "soft_gold", "delta": row.GoldDelta},
		},
		CareerSummary: map[string]any{
			"current_season_id":      row.CurrentSeasonID,
			"current_rating":         row.CurrentRating,
			"current_rank_tier":      row.CurrentRankTier,
			"career_total_matches":   row.TotalMatches,
			"career_total_wins":      row.TotalWins,
			"career_total_losses":    row.TotalLosses,
			"career_total_draws":     row.TotalDraws,
			"career_win_rate_bp":     row.WinRateBP,
			"last_match_id":          row.LastMatchID,
			"last_match_outcome":     row.LastMatchOutcome,
			"last_match_finished_at": row.LastMatchFinishedAt,
		},
		UpdatedAt: time.Now().UTC(),
	}, nil
}

func ledgerID() (string, error) {
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return "ledger_" + hex.EncodeToString(buf), nil
}
