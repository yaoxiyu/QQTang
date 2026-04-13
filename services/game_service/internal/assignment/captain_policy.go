package assignment

func NextCaptainAccountID(currentCaptain string, members []string) string {
	if len(members) == 0 {
		return ""
	}
	for idx, member := range members {
		if member == currentCaptain {
			return members[(idx+1)%len(members)]
		}
	}
	return members[0]
}
