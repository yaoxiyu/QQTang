package roomapp

import (
	"strings"

	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/manifest"
)

func (s *Service) validateLoadout(loadout Loadout) (Loadout, error) {
	resolved := loadout
	if resolved.CharacterID == "" {
		resolved.CharacterID = s.manifest.Manifest().Assets.DefaultCharacterID
	}
	if !s.manifest.HasLegalCharacterID(resolved.CharacterID) {
		return Loadout{}, ErrInvalidLoadout
	}
	if resolved.BubbleStyleID == "" {
		resolved.BubbleStyleID = s.manifest.Manifest().Assets.DefaultBubbleStyleID
	}
	if !s.manifest.HasLegalBubbleStyleID(resolved.BubbleStyleID) {
		return Loadout{}, ErrInvalidLoadout
	}
	return resolved, nil
}

func (s *Service) validateSelection(roomKind string, selection Selection, memberCount int) (Selection, *manifest.MapEntry, error) {
	resolved := selection
	var mapEntry *manifest.MapEntry

	switch domain.ParseRoomKindCategory(roomKind) {
	case domain.RoomKindMatch, domain.RoomKindRanked:
		if strings.TrimSpace(resolved.MatchFormatID) == "" {
			resolved.MatchFormatID = s.query.DefaultMatchFormatID()
		}
		if len(resolved.SelectedModeIDs) == 0 && strings.TrimSpace(resolved.ModeID) == "" {
			if matchFormat := s.query.FindMatchFormat(resolved.MatchFormatID); matchFormat != nil && len(matchFormat.LegalModeIDs) > 0 {
				resolved.ModeID = matchFormat.LegalModeIDs[0]
			}
		}
		if len(resolved.SelectedModeIDs) == 0 && resolved.ModeID != "" {
			resolved.SelectedModeIDs = []string{resolved.ModeID}
		}
		if _, err := s.query.ValidateMatchRoomConfig(resolved.MatchFormatID, resolved.SelectedModeIDs); err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		queueType := "casual"
		if domain.ParseRoomKindCategory(roomKind) == domain.RoomKindRanked {
			queueType = "ranked"
		}
		mapPool, err := s.query.ResolveMapPool(resolved.MatchFormatID, resolved.SelectedModeIDs, queueType)
		if err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		mapEntry = &mapPool[0]
		resolved.MapID = mapEntry.MapID
		resolved.ModeID = mapEntry.ModeID
		resolved.RuleSetID = mapEntry.RuleSetID
	default:
		if resolved.MapID == "" {
			first := s.manifest.FirstMap()
			if first == nil {
				return Selection{}, nil, ErrInvalidSelection
			}
			resolved.MapID = first.MapID
		}
		mapEntry = s.manifest.FindMap(resolved.MapID)
		if mapEntry == nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		if resolved.ModeID == "" {
			resolved.ModeID = mapEntry.ModeID
		}
		if resolved.RuleSetID == "" {
			resolved.RuleSetID = mapEntry.RuleSetID
		}
		if resolved.MatchFormatID == "" && len(mapEntry.MatchFormatIDs) > 0 {
			resolved.MatchFormatID = mapEntry.MatchFormatIDs[0]
		}
		validated, err := s.query.ValidateCustomRoomSelection(resolved.MapID, resolved.ModeID, resolved.RuleSetID)
		if err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		mapEntry = validated
	}

	if err := s.query.ValidateTeamAndPlayerCount(mapEntry.MapID, mapEntry.RequiredTeamCount, memberCount); err != nil {
		return Selection{}, nil, ErrInvalidSelection
	}
	return resolved, mapEntry, nil
}
