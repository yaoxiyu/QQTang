package rating

func MapRankTier(rating int) string {
	switch {
	case rating < 900:
		return "bronze"
	case rating < 1100:
		return "silver"
	case rating < 1300:
		return "gold"
	case rating < 1500:
		return "platinum"
	default:
		return "diamond"
	}
}
