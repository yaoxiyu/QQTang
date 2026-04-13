package reward

type RewardBreakdown struct {
	SeasonPointDelta int
	CareerXPDelta    int
	GoldDelta        int
}

type Service struct{}

func NewService() *Service {
	return &Service{}
}

func (s *Service) Build(queueType string, outcome string) RewardBreakdown {
	if queueType == "ranked" {
		switch outcome {
		case "win":
			return RewardBreakdown{SeasonPointDelta: 12, CareerXPDelta: 30, GoldDelta: 80}
		case "loss":
			return RewardBreakdown{SeasonPointDelta: 4, CareerXPDelta: 15, GoldDelta: 40}
		default:
			return RewardBreakdown{SeasonPointDelta: 6, CareerXPDelta: 20, GoldDelta: 50}
		}
	}
	switch outcome {
	case "win":
		return RewardBreakdown{CareerXPDelta: 20, GoldDelta: 50}
	case "loss":
		return RewardBreakdown{CareerXPDelta: 10, GoldDelta: 25}
	default:
		return RewardBreakdown{CareerXPDelta: 15, GoldDelta: 35}
	}
}
