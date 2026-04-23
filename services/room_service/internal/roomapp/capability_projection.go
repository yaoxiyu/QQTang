package roomapp

import (
	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/manifest"
)

func rebuildRoomCapabilities(room *domain.RoomAggregate, ownerMemberID string, query *manifest.Query) {
	if room == nil {
		return
	}
	room.Capabilities = projectRoomCapabilities(room, ownerMemberID, query)
}

func projectRoomCapabilities(room *domain.RoomAggregate, ownerMemberID string, query *manifest.Query) domain.RoomCapabilitySet {
	capabilities := domain.RoomCapabilitySet{}
	if room == nil {
		return capabilities
	}
	isOwnerPresent := ownerMemberID != ""
	isMatchRoom := isMatchRoomKind(room.RoomKind)
	isManualRoom := isManualRoomKind(room.RoomKind)
	phase := room.RoomState.Phase
	if phase == "" {
		phase = RoomPhaseIdle
	}

	capabilities.CanLeaveRoom = phase != RoomPhaseClosed

	capabilities.CanToggleReady = isStableIdleForMemberOps(phase)
	capabilities.CanUpdateSelection = isOwnerPresent && isManualRoom && phase == RoomPhaseIdle
	capabilities.CanUpdateMatchRoomConfig = isOwnerPresent && isMatchRoom && phase == RoomPhaseIdle
	capabilities.CanStartManualBattle = isOwnerPresent && isManualRoom && phase == RoomPhaseIdle && allMembersReadyByPhase(room.Members) && hasCompleteManualSelection(room)
	requiredPartySize := 0
	if query != nil {
		requiredPartySize = query.RequiredPartySize(room.Selection.MatchFormatID)
	}
	capabilities.CanEnterQueue = isOwnerPresent && isMatchRoom && phase == RoomPhaseIdle && allMembersReadyByPhase(room.Members) && hasMatchQueueConfig(room) && requiredPartySize > 0 && len(room.Members) == requiredPartySize
	capabilities.CanCancelQueue = isOwnerPresent && isMatchRoom && (phase == RoomPhaseQueueActive || phase == RoomPhaseBattleAllocating || phase == RoomPhaseBattleEntryReady)
	return capabilities
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
