package roomapp

import (
	"fmt"
	"time"

	"qqtang/services/room_service/internal/auth"
	"qqtang/services/room_service/internal/domain"
)

func (s *Service) CreateRoom(input CreateRoomInput) (*SnapshotProjection, error) {
	if !s.Ready() {
		return nil, fmt.Errorf("room app not ready")
	}
	normalizedRoomKind, err := normalizeRoomKind(input.RoomKind)
	if err != nil {
		return nil, err
	}
	input.RoomKind = normalizedRoomKind
	if _, err := s.verifier.VerifyWithExpected(input.RoomTicket, auth.ExpectedRoomTicket{
		Purpose:   "create",
		RoomKind:  input.RoomKind,
		AccountID: input.AccountID,
		ProfileID: input.ProfileID,
	}); err != nil {
		return nil, ErrInvalidTicket
	}

	resolvedLoadout, err := s.validateLoadout(input.Loadout)
	if err != nil {
		return nil, err
	}
	resolvedSelection, mapEntry, err := s.validateSelection(input.RoomKind, input.Selection, 1)
	if err != nil {
		return nil, err
	}

	roomID := s.nextID("room")
	memberID := s.nextID("member")
	reconnectToken := s.nextID("reconnect")
	member := domain.RoomMember{
		MemberID:        memberID,
		AccountID:       input.AccountID,
		ProfileID:       input.ProfileID,
		PlayerName:      input.PlayerName,
		TeamID:          1,
		SlotIndex:       0,
		MemberPhase:     MemberPhaseIdle,
		ConnectionState: "connected",
		ConnectionID:    input.ConnectionID,
		ReconnectToken:  reconnectToken,
		Ready:           false,
		Loadout: domain.RoomLoadout{
			CharacterID:   resolvedLoadout.CharacterID,
			BubbleStyleID: resolvedLoadout.BubbleStyleID,
		},
	}

	agg := &domain.RoomAggregate{
		RoomID:          roomID,
		RoomKind:        input.RoomKind,
		RoomDisplayName: input.RoomDisplayName,
		Selection: domain.RoomSelection{
			MapID:           resolvedSelection.MapID,
			RuleSetID:       resolvedSelection.RuleSetID,
			ModeID:          resolvedSelection.ModeID,
			MatchFormatID:   resolvedSelection.MatchFormatID,
			SelectedModeIDs: append([]string{}, resolvedSelection.SelectedModeIDs...),
		},
		Members: map[string]domain.RoomMember{
			member.MemberID: member,
		},
		Queue: domain.RoomQueueState{
			QueueType: "",
		},
		ResumeBindings: map[string]domain.ResumeBinding{
			member.MemberID: {
				MemberID:                member.MemberID,
				ReconnectToken:          reconnectToken,
				ReconnectDeadlineUnixMS: time.Now().Add(30 * time.Second).UnixMilli(),
			},
		},
		RoomState: domain.RoomFSMState{
			Phase:      RoomPhaseIdle,
			LastReason: RoomReasonNone,
		},
		QueueState: domain.QueueFSMProjection{
			Phase:          QueuePhaseIdle,
			TerminalReason: QueueReasonNone,
		},
		BattleState: domain.BattleHandoffFSMProjection{
			Phase:          BattlePhaseIdle,
			TerminalReason: BattleReasonNone,
		},
		MaxPlayerCount:  mapEntry.MaxPlayerCount,
		OpenSlotIndices: defaultOpenSlotIndices(mapEntry.MaxPlayerCount),
	}
	roomTransitionEngine.ApplyCreateRoom(agg, memberID)

	s.mu.Lock()
	s.roomsByID[roomID] = agg
	s.roomByMemberID[memberID] = roomID
	s.roomOwnerByID[roomID] = memberID
	s.syncDirectoryEntryLocked(agg)
	s.mu.Unlock()

	return s.snapshotProjectionLocked(agg), nil
}

func (s *Service) JoinRoom(input JoinRoomInput) (*SnapshotProjection, error) {
	if _, err := s.verifier.VerifyWithExpected(input.RoomTicket, auth.ExpectedRoomTicket{
		Purpose:   "join",
		RoomID:    input.RoomID,
		AccountID: input.AccountID,
		ProfileID: input.ProfileID,
	}); err != nil {
		return nil, ErrInvalidTicket
	}
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
	slotIndex, ok := firstAvailableSlot(room.OpenSlotIndices, room.Members)
	if !ok {
		return nil, ErrRoomNotJoinable
	}

	memberID := s.nextID("member")
	reconnectToken := s.nextID("reconnect")
	teamID := resolveJoinTeamID(room.Members)
	room.Members[memberID] = domain.RoomMember{
		MemberID:        memberID,
		AccountID:       input.AccountID,
		ProfileID:       input.ProfileID,
		PlayerName:      input.PlayerName,
		TeamID:          teamID,
		SlotIndex:       slotIndex,
		MemberPhase:     MemberPhaseIdle,
		ConnectionState: "connected",
		ConnectionID:    input.ConnectionID,
		ReconnectToken:  reconnectToken,
		Ready:           false,
		Loadout: domain.RoomLoadout{
			CharacterID:   resolvedLoadout.CharacterID,
			BubbleStyleID: resolvedLoadout.BubbleStyleID,
		},
	}
	room.ResumeBindings[memberID] = domain.ResumeBinding{
		MemberID:                memberID,
		ReconnectToken:          reconnectToken,
		ReconnectDeadlineUnixMS: time.Now().Add(30 * time.Second).UnixMilli(),
	}
	s.roomByMemberID[memberID] = room.RoomID
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func resolveJoinTeamID(members map[string]domain.RoomMember) int {
	const maxTeamID = 8
	if len(members) == 1 {
		for _, member := range members {
			for teamID := 1; teamID <= maxTeamID; teamID++ {
				if teamID != member.TeamID {
					return teamID
				}
			}
		}
		return 1
	}

	teamCounts := make(map[int]int, maxTeamID)
	for _, member := range members {
		if member.TeamID >= 1 && member.TeamID <= maxTeamID {
			teamCounts[member.TeamID]++
		}
	}
	bestTeamID := 1
	bestCount := len(members) + 1
	for teamID := 1; teamID <= maxTeamID; teamID++ {
		count, ok := teamCounts[teamID]
		if !ok {
			continue
		}
		if count < bestCount {
			bestTeamID = teamID
			bestCount = count
		}
	}
	return bestTeamID
}

func (s *Service) ResumeRoom(input ResumeRoomInput) (*SnapshotProjection, error) {
	if _, err := s.verifier.VerifyWithExpected(input.RoomTicket, auth.ExpectedRoomTicket{
		Purpose: "resume",
		RoomID:  input.RoomID,
	}); err != nil {
		return nil, ErrInvalidTicket
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
	binding := room.ResumeBindings[input.MemberID]
	if binding.ReconnectToken != input.ReconnectToken {
		return nil, ErrReconnectForbidden
	}
	member.ConnectionID = input.ConnectionID
	member.ConnectionState = "connected"
	room.Members[input.MemberID] = member
	delete(s.emptyBattleRoomCleanupDue, input.RoomID)
	restoreMemberPhase(room, input.MemberID)
	s.touchRoomSnapshotLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) MarkDisconnected(roomID string, memberID string) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[roomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[memberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	member.ConnectionState = "disconnected"
	member.ConnectionID = ""
	room.Members[memberID] = member
	markMemberDisconnected(room, memberID)
	s.updateEmptyBattleCleanupLocked(room, time.Now())
	s.syncDirectoryEntryLocked(room)
	s.touchRoomSnapshotLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) LeaveRoom(input LeaveRoomInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	delete(room.Members, input.MemberID)
	delete(room.ResumeBindings, input.MemberID)
	delete(s.roomByMemberID, input.MemberID)
	ownerChanged := false
	if s.roomOwnerByID[input.RoomID] == input.MemberID {
		s.roomOwnerByID[input.RoomID] = selectNextRoomOwner(room.Members)
		ownerChanged = true
	}

	if len(room.Members) == 0 && shouldDelayEmptyBattleCleanup(room) {
		s.registry.RemoveRoomEntry(input.RoomID)
		s.scheduleEmptyBattleCleanupLocked(room, time.Now())
		return nil, nil
	}
	if len(room.Members) == 0 {
		s.destroyRoomLocked(input.RoomID)
		return nil, nil
	}
	s.updateEmptyBattleCleanupLocked(room, time.Now())
	roomTransitionEngine.ApplyMemberLeft(room, s.roomOwnerByID[input.RoomID], ownerChanged)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) updateEmptyBattleCleanupLocked(room *domain.RoomAggregate, now time.Time) {
	if room == nil {
		return
	}
	if isBattleRoomEmpty(room) && shouldDelayEmptyBattleCleanup(room) {
		s.scheduleEmptyBattleCleanupLocked(room, now)
		return
	}
	delete(s.emptyBattleRoomCleanupDue, room.RoomID)
}

func (s *Service) scheduleEmptyBattleCleanupLocked(room *domain.RoomAggregate, now time.Time) {
	if room == nil {
		return
	}
	grace := s.emptyBattleCleanupGrace
	if grace <= 0 {
		grace = 30 * time.Second
	}
	s.emptyBattleRoomCleanupDue[room.RoomID] = now.Add(grace)
}

func (s *Service) destroyRoomLocked(roomID string) {
	room := s.roomsByID[roomID]
	if room != nil {
		for memberID := range room.Members {
			delete(s.roomByMemberID, memberID)
		}
	}
	s.registry.RemoveRoomEntry(roomID)
	delete(s.roomsByID, roomID)
	delete(s.roomOwnerByID, roomID)
	delete(s.emptyBattleRoomCleanupDue, roomID)
}

func isBattleRoomEmpty(room *domain.RoomAggregate) bool {
	if room == nil {
		return false
	}
	if len(room.Members) == 0 {
		return true
	}
	for _, member := range room.Members {
		if member.ConnectionState != "disconnected" {
			return false
		}
	}
	return true
}

func shouldDelayEmptyBattleCleanup(room *domain.RoomAggregate) bool {
	if room == nil || room.BattleState.BattleID == "" {
		return false
	}
	switch room.BattleState.Phase {
	case "", BattlePhaseIdle, BattlePhaseCompleted, "failed", "cancelled":
		return false
	default:
		return true
	}
}
