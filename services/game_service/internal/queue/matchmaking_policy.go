package queue

import (
	"fmt"
	"strings"

	"qqtang/services/shared/contentmanifest"
)

var configuredManifestQuery *contentmanifest.Query

func ConfigureContentManifestQuery(query *contentmanifest.Query) {
	configuredManifestQuery = query
}

func BuildQueueKey(queueType string, parts ...string) string {
	matchFormatID := ""
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

func BuildPartyQueueKey(queueType string, matchFormatID string) string {
	return fmt.Sprintf("%s:%s", queueType, normalizeMatchFormatID(matchFormatID))
}

func normalizeMatchFormatID(matchFormatID string) string {
	normalized := strings.TrimSpace(matchFormatID)
	if normalized != "" {
		return normalized
	}
	if configuredManifestQuery != nil {
		return configuredManifestQuery.DefaultMatchFormatID()
	}
	return ""
}
