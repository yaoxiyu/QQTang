package roomapp

import "qqtang/services/room_service/internal/domain"

type RoomTransitionEngine struct{}

func (RoomTransitionEngine) ApplyCreateRoom(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	if room.RoomState.Phase == "" {
		room.RoomState.Phase = RoomPhaseIdle
	}
	if room.RoomState.LastReason == "" {
		room.RoomState.LastReason = RoomReasonNone
	}
	if room.QueueState.Phase == "" {
		room.QueueState.Phase = QueuePhaseIdle
	}
	if room.QueueState.TerminalReason == "" {
		room.QueueState.TerminalReason = QueueReasonNone
	}
	if room.BattleState.Phase == "" {
		room.BattleState.Phase = BattlePhaseIdle
	}
	if room.BattleState.TerminalReason == "" {
		room.BattleState.TerminalReason = BattleReasonNone
	}
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyToggleReady(room *domain.RoomAggregate, ownerMemberID string) {
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyQueueEnterRequested(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseQueueEntering
	room.RoomState.LastReason = RoomReasonNone
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyQueueAccepted(room *domain.RoomAggregate, ownerMemberID, queuePhase, terminalReason, statusText, queueEntryID, errorCode, userMessage string) {
	if room == nil {
		return
	}
	room.QueueState.Phase = queuePhase
	room.QueueState.TerminalReason = terminalReasonOrNone(terminalReason)
	room.QueueState.StatusText = statusText
	room.QueueState.QueueEntryID = queueEntryID
	room.QueueState.ErrorCode = errorCode
	room.QueueState.UserMessage = userMessage
	room.RoomState.Phase = mapQueuePhaseToRoomPhase(queuePhase)
	if room.QueueState.Phase == QueuePhaseCompleted {
		room.RoomState.Phase = RoomPhaseIdle
	}
	if queuePhase == QueuePhaseQueued || queuePhase == QueuePhaseAssignmentPending || queuePhase == QueuePhaseAllocatingBattle || queuePhase == QueuePhaseEntryReady {
		lockMembersForQueue(room)
	}
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyQueueEnterFailed(room *domain.RoomAggregate, ownerMemberID, errorCode, userMessage string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseIdle
	room.RoomState.LastReason = RoomReasonQueueFailed
	room.QueueState.Phase = QueuePhaseIdle
	room.QueueState.TerminalReason = QueueReasonNone
	room.QueueState.ErrorCode = errorCode
	room.QueueState.UserMessage = userMessage
	finalizeRoomTransition(room, ownerMemberID)
}

func (e RoomTransitionEngine) ApplyQueueUpdated(room *domain.RoomAggregate, ownerMemberID, queuePhase, terminalReason, statusText, queueEntryID, errorCode, userMessage string) {
	e.ApplyQueueAccepted(room, ownerMemberID, queuePhase, terminalReason, statusText, queueEntryID, errorCode, userMessage)
}

type QueueProjectionUpdate struct {
	QueuePhase          string
	QueueTerminalReason string
	QueueStatusText     string
	QueueEntryID        string
	QueueErrorCode      string
	QueueUserMessage    string
	BattlePhase         string
	BattleReady         bool
	AssignmentID        string
	AssignmentRevision  int
	MatchID             string
	BattleID            string
	ServerHost          string
	ServerPort          int
}

type BattleHandoffUpdate struct {
	AssignmentID       string
	AssignmentRevision int
	MatchID            string
	BattleID           string
	ServerHost         string
	ServerPort         int
	Phase              string
	TerminalReason     string
	Ready              bool
	StatusText         string
}

func (RoomTransitionEngine) ApplyQueueProjection(room *domain.RoomAggregate, ownerMemberID string, update QueueProjectionUpdate) bool {
	if room == nil {
		return false
	}
	if isProtectedBattleRoomPhase(room.RoomState.Phase) {
		return false
	}
	changed := false
	nextQueuePhase := update.QueuePhase
	if nextQueuePhase == "" {
		nextQueuePhase = QueuePhaseIdle
	}
	nextTerminalReason := terminalReasonOrNone(update.QueueTerminalReason)

	if room.QueueState.Phase != nextQueuePhase {
		room.QueueState.Phase = nextQueuePhase
		changed = true
	}
	if room.QueueState.TerminalReason != nextTerminalReason {
		room.QueueState.TerminalReason = nextTerminalReason
		changed = true
	}
	if room.QueueState.StatusText != update.QueueStatusText {
		room.QueueState.StatusText = update.QueueStatusText
		changed = true
	}
	if room.QueueState.QueueEntryID != update.QueueEntryID {
		room.QueueState.QueueEntryID = update.QueueEntryID
		changed = true
	}
	if room.QueueState.ErrorCode != update.QueueErrorCode {
		room.QueueState.ErrorCode = update.QueueErrorCode
		changed = true
	}
	if room.QueueState.UserMessage != update.QueueUserMessage {
		room.QueueState.UserMessage = update.QueueUserMessage
		changed = true
	}

	nextBattlePhase := update.BattlePhase
	if nextBattlePhase == "" {
		nextBattlePhase = nextQueuePhaseToBattlePhase(nextQueuePhase)
	}
	if update.BattleReady {
		nextBattlePhase = BattlePhaseReady
	}
	if nextQueuePhase == QueuePhaseQueued {
		nextBattlePhase = BattlePhaseIdle
	}
	if nextQueuePhase == QueuePhaseCompleted {
		nextBattlePhase = BattlePhaseCompleted
	}

	if room.BattleState.AssignmentID != update.AssignmentID {
		room.BattleState.AssignmentID = update.AssignmentID
		changed = true
	}
	if room.BattleState.AssignmentRevision != update.AssignmentRevision {
		room.BattleState.AssignmentRevision = update.AssignmentRevision
		changed = true
	}
	if room.BattleState.MatchID != update.MatchID {
		room.BattleState.MatchID = update.MatchID
		changed = true
	}
	if room.BattleState.BattleID != update.BattleID {
		room.BattleState.BattleID = update.BattleID
		changed = true
	}
	if room.BattleState.ServerHost != update.ServerHost {
		room.BattleState.ServerHost = update.ServerHost
		changed = true
	}
	if room.BattleState.ServerPort != update.ServerPort {
		room.BattleState.ServerPort = update.ServerPort
		changed = true
	}
	if room.BattleState.Phase != nextBattlePhase {
		room.BattleState.Phase = nextBattlePhase
		changed = true
	}
	if room.BattleState.Ready != update.BattleReady {
		room.BattleState.Ready = update.BattleReady
		changed = true
	}

	nextRoomPhase := mapQueuePhaseToRoomPhase(nextQueuePhase)
	if room.RoomState.Phase != nextRoomPhase {
		room.RoomState.Phase = nextRoomPhase
		changed = true
	}

	if nextQueuePhase == QueuePhaseCompleted {
		switch nextTerminalReason {
		case QueueReasonClientCancelled:
			room.RoomState.LastReason = RoomReasonQueueCancelled
		case QueueReasonAssignmentExpired:
			room.RoomState.LastReason = RoomReasonAssignmentExpired
		case QueueReasonMatchFinalized:
			room.RoomState.LastReason = RoomReasonMatchFinalized
		default:
			room.RoomState.LastReason = RoomReasonQueueFailed
		}
		if clearBattleStateProjection(&room.BattleState) {
			changed = true
		}
		releaseMembersToIdle(room)
		changed = true
	} else if nextQueuePhase == QueuePhaseQueued || nextQueuePhase == QueuePhaseAssignmentPending || nextQueuePhase == QueuePhaseAllocatingBattle || nextQueuePhase == QueuePhaseEntryReady {
		lockMembersForQueue(room)
	}

	if changed {
		finalizeRoomTransition(room, ownerMemberID)
	}
	return changed
}

func (RoomTransitionEngine) ApplyQueueCancelRequested(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseQueueCancelling
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyQueueCancelFailed(room *domain.RoomAggregate, ownerMemberID string, previousRoomPhase string) {
	if room == nil {
		return
	}
	if previousRoomPhase == "" {
		previousRoomPhase = RoomPhaseQueueActive
	}
	room.RoomState.Phase = previousRoomPhase
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyQueueCancelled(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.QueueState.Phase = QueuePhaseCompleted
	room.QueueState.TerminalReason = QueueReasonClientCancelled
	room.RoomState.Phase = RoomPhaseIdle
	room.RoomState.LastReason = RoomReasonQueueCancelled
	room.BattleState.Phase = BattlePhaseCompleted
	room.BattleState.TerminalReason = BattleReasonNone
	releaseMembersToIdle(room)
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyManualBattleRequested(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseBattleAllocating
	room.RoomState.LastReason = RoomReasonManualBattleStarted
	room.BattleState.Phase = BattlePhaseAllocating
	room.BattleState.TerminalReason = BattleReasonManualStart
	lockMembersForQueue(room)
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyManualBattleAllocationFailed(room *domain.RoomAggregate, ownerMemberID, errorCode, userMessage string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseIdle
	room.RoomState.LastReason = RoomReasonQueueFailed
	room.BattleState.Phase = BattlePhaseCompleted
	room.BattleState.TerminalReason = BattleReasonAllocationFailed
	room.BattleState.StatusText = userMessage
	room.QueueState.ErrorCode = errorCode
	room.QueueState.UserMessage = userMessage
	releaseMembersToIdle(room)
	finalizeRoomTransition(room, ownerMemberID)
}

func (e RoomTransitionEngine) ApplyBattleAllocated(room *domain.RoomAggregate, ownerMemberID, battlePhase string, ready bool) {
	e.ApplyBattleHandoffUpdated(room, ownerMemberID, BattleHandoffUpdate{
		Phase: battlePhase,
		Ready: ready,
	})
}

func (RoomTransitionEngine) ApplyBattleHandoffUpdated(room *domain.RoomAggregate, ownerMemberID string, update BattleHandoffUpdate) {
	if room == nil {
		return
	}
	battlePhase := update.Phase
	if battlePhase == "" {
		if update.Ready {
			battlePhase = BattlePhaseReady
		} else {
			battlePhase = BattlePhaseAllocating
		}
	}
	room.BattleState.AssignmentID = update.AssignmentID
	room.BattleState.AssignmentRevision = update.AssignmentRevision
	room.BattleState.MatchID = update.MatchID
	room.BattleState.BattleID = update.BattleID
	room.BattleState.ServerHost = update.ServerHost
	room.BattleState.ServerPort = update.ServerPort
	room.BattleState.Phase = battlePhase
	room.BattleState.Ready = update.Ready
	if update.TerminalReason != "" {
		room.BattleState.TerminalReason = update.TerminalReason
	}
	room.BattleState.StatusText = update.StatusText
	if update.Ready {
		room.RoomState.Phase = RoomPhaseBattleEntryReady
	} else {
		room.RoomState.Phase = RoomPhaseBattleAllocating
	}
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyBattleEntryAckRequested(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseBattleEntering
	room.BattleState.Phase = BattlePhaseEntering
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyBattleEntryAcked(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseBattleEntering
	room.RoomState.LastReason = RoomReasonBattleEntryAcknowledged
	room.BattleState.Phase = BattlePhaseEntering
	room.BattleState.TerminalReason = BattleReasonEntryAcknowledged
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyBattleStarted(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseInBattle
	room.BattleState.Phase = BattlePhaseActive
	promoteMembersToBattle(room)
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyBattleFinished(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseReturningToRoom
	room.RoomState.LastReason = RoomReasonBattleFinished
	room.BattleState.Phase = BattlePhaseReturning
	room.BattleState.TerminalReason = BattleReasonBattleFinished
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyReturnCompleted(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseIdle
	room.RoomState.LastReason = RoomReasonReturnCompleted
	room.BattleState.Phase = BattlePhaseCompleted
	room.BattleState.TerminalReason = BattleReasonReturnCompleted
	room.BattleState.AssignmentID = ""
	room.BattleState.AssignmentRevision = 0
	room.BattleState.BattleID = ""
	room.BattleState.MatchID = ""
	room.BattleState.ServerHost = ""
	room.BattleState.ServerPort = 0
	room.BattleState.Ready = false
	releaseMembersToIdle(room)
	finalizeRoomTransition(room, ownerMemberID)
}

func (RoomTransitionEngine) ApplyRoomClosed(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	room.RoomState.Phase = RoomPhaseClosed
	room.RoomState.LastReason = RoomReasonRoomClosed
	room.Capabilities = domain.RoomCapabilitySet{}
	room.Capabilities.CanLeaveRoom = false
	finalizeRoomTransition(room, ownerMemberID)
}

func mapQueuePhaseToRoomPhase(queuePhase string) string {
	switch queuePhase {
	case QueuePhaseQueued:
		return RoomPhaseQueueActive
	case QueuePhaseAssignmentPending, QueuePhaseAllocatingBattle:
		return RoomPhaseBattleAllocating
	case QueuePhaseEntryReady:
		return RoomPhaseBattleEntryReady
	case QueuePhaseCompleted, QueuePhaseIdle, "":
		return RoomPhaseIdle
	default:
		return RoomPhaseQueueActive
	}
}

func isProtectedBattleRoomPhase(roomPhase string) bool {
	switch roomPhase {
	case RoomPhaseBattleEntering, RoomPhaseInBattle, RoomPhaseReturningToRoom:
		return true
	default:
		return false
	}
}

func terminalReasonOrNone(reason string) string {
	if reason == "" {
		return QueueReasonNone
	}
	return reason
}

func finalizeRoomTransition(room *domain.RoomAggregate, ownerMemberID string) {
	if room == nil {
		return
	}
	if room.RoomState.Phase == "" {
		room.RoomState.Phase = RoomPhaseIdle
	}
	if room.RoomState.LastReason == "" {
		room.RoomState.LastReason = RoomReasonNone
	}
	if room.QueueState.Phase == "" {
		room.QueueState.Phase = QueuePhaseIdle
	}
	if room.QueueState.TerminalReason == "" {
		room.QueueState.TerminalReason = QueueReasonNone
	}
	if room.BattleState.Phase == "" {
		room.BattleState.Phase = BattlePhaseIdle
	}
	if room.BattleState.TerminalReason == "" {
		room.BattleState.TerminalReason = BattleReasonNone
	}

	room.SnapshotRevision++
	room.RoomState.Revision = room.SnapshotRevision
	syncLegacyAliases(room)
	rebuildRoomCapabilities(room, ownerMemberID, nil)
}

func syncLegacyAliases(room *domain.RoomAggregate) {
	if room == nil {
		return
	}

	room.LifecycleState = deriveLegacyLifecycleState(room.RoomState.Phase)

	room.Queue.QueueState = deriveLegacyQueueState(room.QueueState.Phase, room.QueueState.TerminalReason)
	room.Queue.QueueEntryID = room.QueueState.QueueEntryID
	room.Queue.StatusText = room.QueueState.StatusText
	room.Queue.ErrorCode = room.QueueState.ErrorCode
	room.Queue.UserMessage = room.QueueState.UserMessage

	room.BattleHandoffState.AssignmentID = room.BattleState.AssignmentID
	room.BattleHandoffState.AssignmentRevision = room.BattleState.AssignmentRevision
	room.BattleHandoffState.BattleID = room.BattleState.BattleID
	room.BattleHandoffState.MatchID = room.BattleState.MatchID
	room.BattleHandoffState.ServerHost = room.BattleState.ServerHost
	room.BattleHandoffState.ServerPort = room.BattleState.ServerPort
	room.BattleHandoffState.Ready = room.BattleState.Ready
	room.BattleHandoffState.AllocationState = deriveLegacyBattleAllocationState(room.BattleState.Phase, room.BattleState.Ready)
}
