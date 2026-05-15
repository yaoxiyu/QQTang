package roomapp

import (
	"fmt"
	"strings"

	"qqtang/services/room_service/internal/gameclient"
)

func (s *Service) StartManualRoomBattle(input StartManualRoomBattleInput) (*SnapshotProjection, error) {
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
	if !nonOwnerMembersReady(room.Members, s.roomOwnerByID[input.RoomID]) {
		return nil, ErrMembersNotReady
	}
	if !canStartManualRoom(room) {
		return nil, ErrMembersNotReady
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}
	roomTransitionEngine.ApplyManualBattleRequested(room, s.roomOwnerByID[input.RoomID])

	result, err := s.game.CreateManualRoomBattle(gameclient.CreateManualRoomBattleInput{
		RoomID:    room.RoomID,
		RoomKind:  room.RoomKind,
		MapID:     room.Selection.MapID,
		ModeID:    room.Selection.ModeID,
		RuleSetID: room.Selection.RuleSetID,
		Members:   buildPartyMembers(room.Members),
	})
	if err != nil {
		roomTransitionEngine.ApplyManualBattleAllocationFailed(room, s.roomOwnerByID[input.RoomID], "MANUAL_BATTLE_ALLOCATE_RPC_ERROR", err.Error())
		s.syncDirectoryEntryLocked(room)
		return nil, err
	}
	if !result.OK {
		roomTransitionEngine.ApplyManualBattleAllocationFailed(room, s.roomOwnerByID[input.RoomID], result.ErrorCode, result.UserMessage)
		s.syncDirectoryEntryLocked(room)
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	ready := result.Ready || isManualBattleAllocationReady(result.AllocationState, result.ServerHost, result.ServerPort)
	phase := BattlePhaseAllocating
	if ready {
		phase = BattlePhaseReady
	}
	roomTransitionEngine.ApplyBattleHandoffUpdated(room, s.roomOwnerByID[input.RoomID], BattleHandoffUpdate{
		AssignmentID:       result.AssignmentID,
		AssignmentRevision: result.AssignmentRevision,
		MatchID:            result.MatchID,
		BattleID:           result.BattleID,
		ServerHost:         result.ServerHost,
		ServerPort:         result.ServerPort,
		Phase:              phase,
		TerminalReason:     BattleReasonManualStart,
		Ready:              ready,
	})
	if isManualRoomKind(room.RoomKind) && room.QueueState.QueueEntryID != "" {
		s.metrics.queueStateManualRoomWriteCount.Add(1)
		panic("DEBT-011: manual room must not write QueueState")
	}
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) AckBattleEntry(input AckBattleEntryInput) (*SnapshotProjection, error) {
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
	handoff := room.BattleState
	if room.RoomState.Phase == RoomPhaseInBattle && room.BattleState.Phase == BattlePhaseActive {
		if handoff.AssignmentID == "" || handoff.AssignmentID != input.AssignmentID {
			return nil, fmt.Errorf("assignment mismatch")
		}
		if handoff.BattleID != "" && input.BattleID != "" && handoff.BattleID != input.BattleID {
			return nil, fmt.Errorf("battle mismatch")
		}
		if handoff.MatchID != "" && input.MatchID != "" && handoff.MatchID != input.MatchID {
			return nil, fmt.Errorf("match mismatch")
		}
		s.syncDirectoryEntryLocked(room)
		return s.snapshotProjectionLocked(room), nil
	}
	if room.RoomState.Phase != RoomPhaseBattleEntryReady || room.BattleState.Phase != BattlePhaseReady {
		return nil, ErrRoomPhaseInvalid
	}
	if handoff.AssignmentID == "" || handoff.AssignmentID != input.AssignmentID {
		return nil, fmt.Errorf("assignment mismatch")
	}
	if handoff.BattleID != "" && input.BattleID != "" && handoff.BattleID != input.BattleID {
		return nil, fmt.Errorf("battle mismatch")
	}
	if handoff.MatchID != "" && input.MatchID != "" && handoff.MatchID != input.MatchID {
		return nil, fmt.Errorf("match mismatch")
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	result, err := s.game.CommitAssignmentReady(gameclient.CommitAssignmentReadyInput{
		RoomID:             room.RoomID,
		RoomKind:           room.RoomKind,
		AssignmentID:       input.AssignmentID,
		AccountID:          member.AccountID,
		ProfileID:          member.ProfileID,
		AssignmentRevision: handoff.AssignmentRevision,
		BattleID:           input.BattleID,
		MatchID:            input.MatchID,
	})
	if err != nil {
		return nil, err
	}
	if !result.OK {
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	roomTransitionEngine.ApplyBattleEntryAckRequested(room, s.roomOwnerByID[input.RoomID])
	room.BattleState.StatusText = "battle_entry_acknowledged"
	roomTransitionEngine.ApplyBattleEntryAcked(room, s.roomOwnerByID[input.RoomID])
	if strings.TrimSpace(result.CommittedState) == "committed" {
		roomTransitionEngine.ApplyBattleStarted(room, s.roomOwnerByID[input.RoomID])
	}
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}
