package roomapp

import "qqtang/services/room_service/internal/domain"

func rebuildRoomCapabilities(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	isOwnerPresent := ownerMemberID != ""
	isMatchRoom := isMatchRoomKind(room.RoomKind)
	isManualRoom := isManualRoomKind(room.RoomKind)
	phase := room.RoomState.Phase
	if phase == "" {
		phase = RoomPhaseIdle
	}

	room.Capabilities.CanLeaveRoom = phase != RoomPhaseClosed

	room.Capabilities.CanToggleReady = isStableIdleForMemberOps(phase)
	room.Capabilities.CanUpdateSelection = isOwnerPresent && isManualRoom && phase == RoomPhaseIdle
	room.Capabilities.CanUpdateMatchRoomConfig = isOwnerPresent && isMatchRoom && phase == RoomPhaseIdle
	room.Capabilities.CanStartManualBattle = isOwnerPresent && isManualRoom && phase == RoomPhaseIdle && allMembersReadyByPhase(room.Members) && hasCompleteManualSelection(room)
	room.Capabilities.CanEnterQueue = isOwnerPresent && isMatchRoom && phase == RoomPhaseIdle && allMembersReadyByPhase(room.Members) && hasMatchQueueConfig(room) && len(room.Members) == requiredPartySizeFromMatchFormat(room.Selection.MatchFormatID)
	room.Capabilities.CanCancelQueue = isOwnerPresent && isMatchRoom && (phase == RoomPhaseQueueActive || phase == RoomPhaseBattleAllocating || phase == RoomPhaseBattleEntryReady)
}

func isStableIdleForMemberOps(roomPhase string) bool {
	return roomPhase == RoomPhaseIdle
}

func allMembersReadyByPhase(members map[string]domain.RoomMember) bool {
	if len(members) == 0 {
		return false
	}
	for _, member := range members {
		if member.MemberPhase != MemberPhaseReady {
			return false
		}
	}
	return true
}

func hasMatchQueueConfig(room *domain.RoomAggregate) bool {
	if room == nil {
		return false
	}
	if room.Selection.MatchFormatID == "" {
		return false
	}
	return len(room.Selection.SelectedModeIDs) > 0 || room.Selection.ModeID != ""
}

func hasCompleteManualSelection(room *domain.RoomAggregate) bool {
	if room == nil {
		return false
	}
	return room.Selection.MapID != "" && room.Selection.RuleSetID != "" && room.Selection.ModeID != ""
}
