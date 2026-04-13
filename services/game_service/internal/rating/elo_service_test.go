package rating

import "testing"

func TestComputeDeltaRankedWinIncreasesRating(t *testing.T) {
	service := NewEloService()
	result := service.ComputeDelta(PlayerDeltaInput{
		QueueType:    "ranked",
		RatingBefore: 1000,
		OpponentAvg:  1000,
		Outcome:      "win",
	})
	if result.RatingDelta <= 0 {
		t.Fatalf("expected positive delta, got %d", result.RatingDelta)
	}
	if result.RatingAfter != 1000+result.RatingDelta {
		t.Fatalf("unexpected rating after: %d", result.RatingAfter)
	}
}

func TestComputeDeltaCasualIsNeutral(t *testing.T) {
	service := NewEloService()
	result := service.ComputeDelta(PlayerDeltaInput{
		QueueType:    "casual",
		RatingBefore: 1088,
		OpponentAvg:  1200,
		Outcome:      "loss",
	})
	if result.RatingDelta != 0 || result.RatingAfter != 1088 {
		t.Fatalf("expected casual queue to keep rating unchanged, got delta=%d after=%d", result.RatingDelta, result.RatingAfter)
	}
}
