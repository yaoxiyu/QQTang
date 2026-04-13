package rating

import "math"

type PlayerDeltaInput struct {
	QueueType    string
	RatingBefore int
	OpponentAvg  int
	Outcome      string
}

type DeltaResult struct {
	RatingDelta int
	RatingAfter int
}

type EloService struct{}

func NewEloService() *EloService {
	return &EloService{}
}

func (s *EloService) ComputeDelta(input PlayerDeltaInput) DeltaResult {
	if input.QueueType != "ranked" {
		return DeltaResult{RatingDelta: 0, RatingAfter: input.RatingBefore}
	}
	if input.Outcome == "draw" {
		return DeltaResult{RatingDelta: 0, RatingAfter: input.RatingBefore}
	}

	score := 0.0
	if input.Outcome == "win" {
		score = 1.0
	}
	expected := 1.0 / (1.0 + math.Pow(10, float64(input.OpponentAvg-input.RatingBefore)/400.0))
	delta := int(math.Round(24 * (score - expected)))
	return DeltaResult{
		RatingDelta: delta,
		RatingAfter: input.RatingBefore + delta,
	}
}
