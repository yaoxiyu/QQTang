package manifest

import (
	"errors"
)

var (
	ErrManifestNotReady           = errors.New("manifest not ready")
	ErrCustomSelectionIllegal     = errors.New("custom room selection is illegal")
	ErrMatchFormatIllegal         = errors.New("match format is illegal")
	ErrMatchModeSetIllegal        = errors.New("selected match modes are illegal")
	ErrMapPoolEmpty               = errors.New("resolved map pool is empty")
	ErrMapTeamPlayerLimitExceeded = errors.New("team/player count exceeds map limit")
)

type Query struct {
	loader *Loader
}

func NewQuery(loader *Loader) *Query {
	return &Query{loader: loader}
}

func (q *Query) ValidateCustomRoomSelection(mapID, modeID, ruleSetID string) (*MapEntry, error) {
	if q == nil || q.loader == nil || !q.loader.Ready() {
		return nil, ErrManifestNotReady
	}
	mapEntry := q.loader.FindMap(mapID)
	if mapEntry == nil {
		return nil, ErrCustomSelectionIllegal
	}
	if !mapEntry.CustomRoomEnabled {
		return nil, ErrCustomSelectionIllegal
	}
	if mapEntry.ModeID != modeID || mapEntry.RuleSetID != ruleSetID {
		return nil, ErrCustomSelectionIllegal
	}
	return mapEntry, nil
}

func (q *Query) ValidateMatchRoomConfig(matchFormatID string, selectedModeIDs []string) (*MatchFormat, error) {
	if q == nil || q.loader == nil || !q.loader.Ready() {
		return nil, ErrManifestNotReady
	}
	mf := q.findMatchFormat(matchFormatID)
	if mf == nil {
		return nil, ErrMatchFormatIllegal
	}
	if len(selectedModeIDs) == 0 {
		return nil, ErrMatchModeSetIllegal
	}
	legal := make(map[string]struct{}, len(mf.LegalModeIDs))
	for _, modeID := range mf.LegalModeIDs {
		legal[modeID] = struct{}{}
	}
	for _, selectedModeID := range selectedModeIDs {
		if _, ok := legal[selectedModeID]; !ok {
			return nil, ErrMatchModeSetIllegal
		}
	}
	return mf, nil
}

func (q *Query) ResolveMapPool(matchFormatID string, selectedModeIDs []string, queueType string) ([]MapEntry, error) {
	if q == nil || q.loader == nil || !q.loader.Ready() {
		return nil, ErrManifestNotReady
	}
	if _, err := q.ValidateMatchRoomConfig(matchFormatID, selectedModeIDs); err != nil {
		return nil, err
	}
	selectedModeSet := make(map[string]struct{}, len(selectedModeIDs))
	for _, modeID := range selectedModeIDs {
		selectedModeSet[modeID] = struct{}{}
	}
	var result []MapEntry
	for _, mapEntry := range q.loader.Manifest().Maps {
		if !contains(mapEntry.MatchFormatIDs, matchFormatID) {
			continue
		}
		if _, ok := selectedModeSet[mapEntry.ModeID]; !ok {
			continue
		}
		if queueType == "ranked" && !mapEntry.RankedEnabled {
			continue
		}
		if queueType == "casual" && !mapEntry.CasualEnabled {
			continue
		}
		result = append(result, mapEntry)
	}
	if len(result) == 0 {
		return nil, ErrMapPoolEmpty
	}
	return result, nil
}

func (q *Query) ValidateTeamAndPlayerCount(mapID string, requiredTeamCount, memberCount int) error {
	if q == nil || q.loader == nil || !q.loader.Ready() {
		return ErrManifestNotReady
	}
	mapEntry := q.loader.FindMap(mapID)
	if mapEntry == nil {
		return ErrCustomSelectionIllegal
	}
	if requiredTeamCount > mapEntry.RequiredTeamCount {
		return ErrMapTeamPlayerLimitExceeded
	}
	if memberCount > mapEntry.MaxPlayerCount {
		return ErrMapTeamPlayerLimitExceeded
	}
	return nil
}

func (q *Query) findMatchFormat(matchFormatID string) *MatchFormat {
	for i := range q.loader.Manifest().MatchFormats {
		if q.loader.Manifest().MatchFormats[i].MatchFormatID == matchFormatID {
			return &q.loader.Manifest().MatchFormats[i]
		}
	}
	return nil
}
