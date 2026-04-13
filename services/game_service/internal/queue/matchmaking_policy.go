package queue

import "fmt"

func BuildQueueKey(queueType string, modeID string, ruleSetID string) string {
	return fmt.Sprintf("%s:%s:%s:2v2", queueType, modeID, ruleSetID)
}
