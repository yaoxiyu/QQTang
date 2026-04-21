package rpcapi

import (
	gamev1 "qqtang/services/game_service/internal/gen/qqt/gamev1shim"

	"qqtang/services/game_service/internal/assignment"
	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/game_service/internal/queue"
)

func mapEnterPartyQueueInput(req *gamev1.EnterPartyQueueRequest) queue.EnterPartyQueueInput {
	members := req.GetMembers()
	mappedMembers := make([]queue.PartyQueueMemberInput, 0, len(members))
	for _, member := range members {
		if member == nil {
			continue
		}
		mappedMembers = append(mappedMembers, queue.PartyQueueMemberInput{
			AccountID: member.GetAccountId(),
			ProfileID: member.GetProfileId(),
			SeatIndex: int(member.GetTeamId()),
		})
	}
	return queue.EnterPartyQueueInput{
		PartyRoomID:     roomIDFromContext(req.GetContext()),
		QueueType:       req.GetQueueType(),
		MatchFormatID:   req.GetMatchFormatId(),
		SelectedModeIDs: append([]string{}, req.GetSelectedModeIds()...),
		Members:         mappedMembers,
	}
}

func mapCreateManualRoomBattleInput(req *gamev1.CreateManualRoomBattleRequest) battlealloc.ManualRoomBattleInput {
	members := req.GetMembers()
	mappedMembers := make([]battlealloc.ManualRoomMember, 0, len(members))
	for _, member := range members {
		if member == nil {
			continue
		}
		mappedMembers = append(mappedMembers, battlealloc.ManualRoomMember{
			AccountID:      member.GetAccountId(),
			ProfileID:      member.GetProfileId(),
			AssignedTeamID: int(member.GetTeamId()),
		})
	}
	return battlealloc.ManualRoomBattleInput{
		SourceRoomID:        roomIDFromContext(req.GetContext()),
		SourceRoomKind:      roomKindFromContext(req.GetContext()),
		ModeID:              req.GetModeId(),
		RuleSetID:           req.GetRuleSetId(),
		MapID:               req.GetMapId(),
		ExpectedMemberCount: len(mappedMembers),
		Members:             mappedMembers,
	}
}

func mapCommitAssignmentReadyInput(req *gamev1.CommitAssignmentReadyRequest) assignment.CommitInput {
	return assignment.CommitInput{
		AssignmentID: req.GetAssignmentId(),
		AccountID:    "",
		ProfileID:    "",
		RoomID:       roomIDFromContext(req.GetContext()),
	}
}

func successEnterPartyQueue(status queue.PartyQueueStatus) *gamev1.EnterPartyQueueResponse {
	return &gamev1.EnterPartyQueueResponse{
		Ok:                 true,
		QueueEntryId:       status.QueueEntryID,
		QueueState:         status.QueueState,
		QueuePhase:         status.QueuePhase,
		QueueTerminalReason: status.QueueTerminalReason,
		QueueStatusText:    status.QueueStatusText,
	}
}

func errorEnterPartyQueue(code, message string) *gamev1.EnterPartyQueueResponse {
	return &gamev1.EnterPartyQueueResponse{
		Ok:          false,
		ErrorCode:   code,
		UserMessage: message,
	}
}

func successCancelPartyQueue(status queue.PartyQueueStatus) *gamev1.CancelPartyQueueResponse {
	return &gamev1.CancelPartyQueueResponse{
		Ok:                 true,
		QueueState:         status.QueueState,
		QueuePhase:         status.QueuePhase,
		QueueTerminalReason: status.QueueTerminalReason,
		QueueStatusText:    status.QueueStatusText,
	}
}

func errorCancelPartyQueue(code, message string) *gamev1.CancelPartyQueueResponse {
	return &gamev1.CancelPartyQueueResponse{
		Ok:          false,
		ErrorCode:   code,
		UserMessage: message,
	}
}

func successGetPartyQueueStatus(status queue.PartyQueueStatus) *gamev1.GetPartyQueueStatusResponse {
	return &gamev1.GetPartyQueueStatusResponse{
		Ok:                   true,
		QueueState:           status.QueueState,
		AssignmentId:         status.AssignmentID,
		MatchId:              status.MatchID,
		BattleId:             status.BattleID,
		ServerHost:           status.ServerHost,
		ServerPort:           int32(status.ServerPort),
		QueuePhase:           status.QueuePhase,
		QueueTerminalReason:  status.QueueTerminalReason,
		QueueStatusText:      status.QueueStatusText,
		AssignmentStatusText: status.AssignmentStatusText,
		AllocationPhase:      status.AllocationPhase,
		AllocationReason:     status.AllocationReason,
		BattleEntryReady:     status.BattleEntryReady,
	}
}

func errorGetPartyQueueStatus(code, message string) *gamev1.GetPartyQueueStatusResponse {
	return &gamev1.GetPartyQueueStatusResponse{
		Ok:          false,
		ErrorCode:   code,
		UserMessage: message,
	}
}

func successCreateManualRoomBattle(result battlealloc.ManualRoomBattleResult) *gamev1.CreateManualRoomBattleResponse {
	return &gamev1.CreateManualRoomBattleResponse{
		Ok:           true,
		AssignmentId: result.AssignmentID,
		MatchId:      result.MatchID,
		BattleId:     result.BattleID,
		ServerHost:   result.ServerHost,
		ServerPort:   int32(result.ServerPort),
	}
}

func errorCreateManualRoomBattle(code, message string) *gamev1.CreateManualRoomBattleResponse {
	return &gamev1.CreateManualRoomBattleResponse{
		Ok:          false,
		ErrorCode:   code,
		UserMessage: message,
	}
}

func successCommitAssignmentReady(result assignment.CommitResult) *gamev1.CommitAssignmentReadyResponse {
	return &gamev1.CommitAssignmentReadyResponse{
		Ok:             true,
		CommittedState: result.CommitState,
	}
}

func errorCommitAssignmentReady(code, message string) *gamev1.CommitAssignmentReadyResponse {
	return &gamev1.CommitAssignmentReadyResponse{
		Ok:          false,
		ErrorCode:   code,
		UserMessage: message,
	}
}

func roomIDFromContext(ctx *gamev1.RoomContext) string {
	if ctx == nil {
		return ""
	}
	return ctx.GetRoomId()
}

func roomKindFromContext(ctx *gamev1.RoomContext) string {
	if ctx == nil {
		return ""
	}
	return ctx.GetRoomKind()
}
