package roomapp

import (
	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/gameclient"
)

func applyPartyQueueProjection(room *domain.RoomAggregate, result gameclient.GetPartyQueueStatusResult, ownerMemberID string) (changed bool) {
	if room == nil {
		return false
	}

	nextQueuePhase, nextTerminalReason := resolveQueuePhaseAndTerminalReason(
		result.QueuePhase,
		result.QueueTerminalReason,
		result.QueueState,
		result.OK,
	)
	nextStatusText := resolveQueueStatusText(result.QueueStatusText, result.AssignmentStatusText, result.QueueState)
	if nextStatusText == "" && !result.OK {
		nextStatusText = "Battle allocation failed"
	}

	ready := isBattleEntryReadyStatus(result) && result.OK
	nextBattlePhase := nextQueuePhaseToBattlePhase(nextQueuePhase)
	switch nextQueuePhase {
	case QueuePhaseQueued:
		nextBattlePhase = BattlePhaseIdle
	case QueuePhaseCompleted:
		nextBattlePhase = BattlePhaseCompleted
	}
	if ready {
		nextBattlePhase = BattlePhaseReady
	}

	return roomTransitionEngine.ApplyQueueProjection(room, ownerMemberID, QueueProjectionUpdate{
		QueuePhase:          nextQueuePhase,
		QueueTerminalReason: nextTerminalReason,
		QueueStatusText:     nextStatusText,
		QueueEntryID:        room.QueueState.QueueEntryID,
		QueueErrorCode:      result.ErrorCode,
		QueueUserMessage:    result.UserMessage,
		BattlePhase:         nextBattlePhase,
		BattleReady:         ready,
		AssignmentID:        result.AssignmentID,
		MatchID:             result.MatchID,
		BattleID:            result.BattleID,
		ServerHost:          result.ServerHost,
		ServerPort:          result.ServerPort,
	})
}
