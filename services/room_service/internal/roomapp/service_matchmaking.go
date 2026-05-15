package roomapp

import (
	"fmt"

	"qqtang/services/room_service/internal/gameclient"
)

func (s *Service) EnterMatchQueue(input EnterMatchQueueInput) (*SnapshotProjection, error) {
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
	if !allMembersReady(room.Members) {
		return nil, ErrMembersNotReady
	}
	requiredPartySize := s.query.RequiredPartySize(room.Selection.MatchFormatID)
	if len(room.Members) != requiredPartySize {
		return nil, ErrPartySizeMismatch
	}
	selectedModeIDs := append([]string{}, room.Selection.SelectedModeIDs...)
	if len(selectedModeIDs) == 0 && room.Selection.ModeID != "" {
		selectedModeIDs = []string{room.Selection.ModeID}
	}
	if _, err := s.query.ValidateMatchRoomConfig(room.Selection.MatchFormatID, selectedModeIDs); err != nil {
		return nil, ErrInvalidSelection
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	queueType := queueTypeByRoomKind(room.RoomKind)
	roomTransitionEngine.ApplyQueueEnterRequested(room, s.roomOwnerByID[input.RoomID])
	gameInput := gameclient.EnterPartyQueueInput{
		RoomID:          room.RoomID,
		RoomKind:        room.RoomKind,
		QueueType:       queueType,
		MatchFormatID:   room.Selection.MatchFormatID,
		SelectedModeIDs: append([]string{}, room.Selection.SelectedModeIDs...),
		Members:         buildPartyMembers(room.Members),
	}
	result, err := s.game.EnterPartyQueue(gameInput)
	if err != nil {
		roomTransitionEngine.ApplyQueueEnterFailed(room, s.roomOwnerByID[input.RoomID], "ENTER_QUEUE_RPC_ERROR", err.Error())
		return nil, err
	}
	if !result.OK {
		roomTransitionEngine.ApplyQueueEnterFailed(room, s.roomOwnerByID[input.RoomID], result.ErrorCode, result.UserMessage)
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	room.Queue.QueueType = queueType
	queuePhase, terminalReason := resolveQueuePhaseAndTerminalReason(
		result.QueuePhase,
		result.QueueTerminalReason,
		result.QueueState,
		result.OK,
	)
	statusText := resolveQueueStatusText(result.QueueStatusText, result.StatusText, result.QueueState)
	roomTransitionEngine.ApplyQueueAccepted(
		room,
		s.roomOwnerByID[input.RoomID],
		queuePhase,
		terminalReason,
		statusText,
		result.QueueEntryID,
		"",
		"",
	)
	room.Queue.QueueType = queueType
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) CancelMatchQueue(input CancelMatchQueueInput) (*SnapshotProjection, error) {
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
	switch room.RoomState.Phase {
	case RoomPhaseQueueActive, RoomPhaseBattleAllocating, RoomPhaseBattleEntryReady:
	default:
		return nil, ErrRoomPhaseInvalid
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}
	previousRoomPhase := room.RoomState.Phase
	roomTransitionEngine.ApplyQueueCancelRequested(room, s.roomOwnerByID[input.RoomID])

	result, err := s.game.CancelPartyQueue(gameclient.CancelPartyQueueInput{
		RoomID:       room.RoomID,
		RoomKind:     room.RoomKind,
		QueueType:    room.Queue.QueueType,
		QueueEntryID: room.Queue.QueueEntryID,
	})
	if err != nil {
		roomTransitionEngine.ApplyQueueCancelFailed(room, s.roomOwnerByID[input.RoomID], previousRoomPhase)
		return nil, err
	}
	if !result.OK {
		roomTransitionEngine.ApplyQueueCancelFailed(room, s.roomOwnerByID[input.RoomID], previousRoomPhase)
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}
	roomTransitionEngine.ApplyQueueCancelled(room, s.roomOwnerByID[input.RoomID])
	return s.snapshotProjectionLocked(room), nil
}
