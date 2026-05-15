package roomapp

import (
	"qqtang/services/room_service/internal/domain"
)

func (s *Service) UpdateProfile(input UpdateProfileInput) (*SnapshotProjection, error) {
	resolvedLoadout, err := s.validateLoadout(input.Loadout)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[input.MemberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	if input.PlayerName != "" {
		member.PlayerName = input.PlayerName
	}
	if input.TeamID > 0 {
		member.TeamID = input.TeamID
	}
	member.Loadout = domain.RoomLoadout{
		CharacterID:   resolvedLoadout.CharacterID,
		BubbleStyleID: resolvedLoadout.BubbleStyleID,
	}
	room.Members[input.MemberID] = member
	s.touchRoomSnapshotLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) UpdateSelection(input UpdateSelectionInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isManualRoomKind(room.RoomKind) {
		return nil, ErrManualRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}
	roomKind := room.RoomKind
	if roomKind == "" {
		roomKind = "private_room"
	}
	resolvedSelection, mapEntry, err := s.validateSelection(roomKind, input.Selection, len(room.Members))
	if err != nil {
		return nil, err
	}
	room.Selection = domain.RoomSelection{
		MapID:           resolvedSelection.MapID,
		RuleSetID:       resolvedSelection.RuleSetID,
		ModeID:          resolvedSelection.ModeID,
		MatchFormatID:   resolvedSelection.MatchFormatID,
		SelectedModeIDs: append([]string{}, resolvedSelection.SelectedModeIDs...),
	}
	room.MaxPlayerCount = mapEntry.MaxPlayerCount
	if len(input.OpenSlotIndices) > 0 {
		normalizedSlots, normalizeErr := normalizeOpenSlotIndices(input.OpenSlotIndices, mapEntry.MaxPlayerCount, room.Members)
		if normalizeErr != nil {
			return nil, normalizeErr
		}
		room.OpenSlotIndices = normalizedSlots
	} else {
		room.OpenSlotIndices = expandOpenSlotIndices(room.OpenSlotIndices, mapEntry.MaxPlayerCount, room.Members)
	}
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) UpdateMatchRoomConfig(input UpdateMatchRoomConfigInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isMatchRoomKind(room.RoomKind) {
		return nil, ErrMatchRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}

	selectedModeIDs := append([]string{}, input.SelectedModeIDs...)
	if len(selectedModeIDs) == 0 && room.Selection.ModeID != "" {
		selectedModeIDs = []string{room.Selection.ModeID}
	}
	if _, err := s.query.ValidateMatchRoomConfig(input.MatchFormatID, selectedModeIDs); err != nil {
		return nil, ErrInvalidSelection
	}

	queueType := "casual"
	if room.RoomKind == "ranked_match_room" {
		queueType = "ranked"
	}
	mapPool, err := s.query.ResolveMapPool(input.MatchFormatID, selectedModeIDs, queueType)
	if err != nil || len(mapPool) == 0 {
		return nil, ErrInvalidSelection
	}
	mapEntry := mapPool[0]

	room.Selection.MatchFormatID = input.MatchFormatID
	room.Selection.SelectedModeIDs = selectedModeIDs
	room.Selection.MapID = mapEntry.MapID
	room.Selection.ModeID = mapEntry.ModeID
	room.Selection.RuleSetID = mapEntry.RuleSetID
	room.MaxPlayerCount = mapEntry.MaxPlayerCount
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}
