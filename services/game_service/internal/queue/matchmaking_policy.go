package queue

import "fmt"

func BuildQueueKey(queueType string, parts ...string) string {
	matchFormatID := "2v2"
	modeID := ""
	ruleSetID := ""
	if len(parts) == 2 {
		modeID = parts[0]
		ruleSetID = parts[1]
	} else if len(parts) >= 3 {
		matchFormatID = normalizeMatchFormatID(parts[0])
		modeID = parts[1]
		ruleSetID = parts[2]
	}
	return fmt.Sprintf("%s:%s:%s:%s", queueType, modeID, ruleSetID, matchFormatID)
}

func normalizeMatchFormatID(matchFormatID string) string {
	if matchFormatID == "" {
		return "2v2"
	}
	return matchFormatID
}
