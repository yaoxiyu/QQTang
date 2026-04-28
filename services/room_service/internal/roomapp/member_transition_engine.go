package roomapp

import "qqtang/services/room_service/internal/domain"

func toggleMemberReady(room *domain.RoomAggregate, memberID string) bool {
	if room == nil {
		return false
	}
	member, ok := room.Members[memberID]
	if !ok {
		return false
	}
	if member.MemberPhase != "" && member.MemberPhase != MemberPhaseIdle && member.MemberPhase != MemberPhaseReady {
		return false
	}
	member.Ready = !member.Ready
	if member.Ready {
		member.MemberPhase = MemberPhaseReady
	} else {
		member.MemberPhase = MemberPhaseIdle
	}
	room.Members[memberID] = member
	return true
}

func lockMembersForQueue(room *domain.RoomAggregate) {
	if room == nil {
		return
	}
	for memberID, member := range room.Members {
		if member.MemberPhase == MemberPhaseDisconnected {
			continue
		}
		member.MemberPhase = MemberPhaseQueueLocked
		room.Members[memberID] = member
	}
}

func promoteMembersToBattle(room *domain.RoomAggregate) {
	if room == nil {
		return
	}
	for memberID, member := range room.Members {
		if member.MemberPhase == MemberPhaseDisconnected {
			continue
		}
		member.MemberPhase = MemberPhaseInBattle
		room.Members[memberID] = member
	}
}

func releaseMembersToIdle(room *domain.RoomAggregate) {
	if room == nil {
		return
	}
	for memberID, member := range room.Members {
		if member.MemberPhase == MemberPhaseDisconnected {
			continue
		}
		member.MemberPhase = MemberPhaseIdle
		member.Ready = false
		room.Members[memberID] = member
	}
}

func releaseMembersPreservingReady(room *domain.RoomAggregate) {
	if room == nil {
		return
	}
	for memberID, member := range room.Members {
		if member.MemberPhase == MemberPhaseDisconnected {
			continue
		}
		if member.Ready {
			member.MemberPhase = MemberPhaseReady
		} else {
			member.MemberPhase = MemberPhaseIdle
		}
		room.Members[memberID] = member
	}
}

func markMemberDisconnected(room *domain.RoomAggregate, memberID string) {
	if room == nil {
		return
	}
	member, ok := room.Members[memberID]
	if !ok {
		return
	}
	member.MemberPhase = MemberPhaseDisconnected
	room.Members[memberID] = member
}

func restoreMemberPhase(room *domain.RoomAggregate, memberID string) {
	if room == nil {
		return
	}
	member, ok := room.Members[memberID]
	if !ok {
		return
	}
	switch room.RoomState.Phase {
	case RoomPhaseIdle, RoomPhaseClosed, "":
		if member.Ready {
			member.MemberPhase = MemberPhaseReady
		} else {
			member.MemberPhase = MemberPhaseIdle
		}
	case RoomPhaseQueueEntering, RoomPhaseQueueActive, RoomPhaseQueueCancelling, RoomPhaseBattleAllocating, RoomPhaseBattleEntryReady, RoomPhaseBattleEntering:
		member.MemberPhase = MemberPhaseQueueLocked
	case RoomPhaseInBattle:
		member.MemberPhase = MemberPhaseInBattle
	case RoomPhaseReturningToRoom:
		member.MemberPhase = MemberPhaseIdle
	}
	room.Members[memberID] = member
}
