package gameclient

import gamev1 "qqtang/services/room_service/internal/gen/qqt/gamev1shim"

func toPBRoomContext(roomID, roomKind string) *gamev1.RoomContext {
	return &gamev1.RoomContext{
		RoomId:   roomID,
		RoomKind: roomKind,
	}
}

func toPBPartyMembers(input []PartyMember) []*gamev1.PartyMember {
	result := make([]*gamev1.PartyMember, 0, len(input))
	for _, member := range input {
		result = append(result, &gamev1.PartyMember{
			AccountId:       member.AccountID,
			ProfileId:       member.ProfileID,
			TeamId:          int32(member.TeamID),
			CharacterId:     member.CharacterID,
			CharacterSkinId: member.CharacterSkinID,
			BubbleStyleId:   member.BubbleStyleID,
			BubbleSkinId:    member.BubbleSkinID,
		})
	}
	return result
}

func fromPBEnterPartyQueue(response *gamev1.EnterPartyQueueResponse) EnterPartyQueueResult {
	if response == nil {
		return EnterPartyQueueResult{}
	}
	statusText := response.GetQueueStatusText()
	if statusText == "" {
		statusText = response.GetQueueState()
	}
	return EnterPartyQueueResult{
		OK:                  response.GetOk(),
		QueueEntryID:        response.GetQueueEntryId(),
		QueueState:          response.GetQueueState(),
		QueuePhase:          response.GetQueuePhase(),
		QueueTerminalReason: response.GetQueueTerminalReason(),
		QueueStatusText:     response.GetQueueStatusText(),
		StatusText:          statusText,
		ErrorCode:           response.GetErrorCode(),
		UserMessage:         response.GetUserMessage(),
	}
}

func fromPBCancelPartyQueue(response *gamev1.CancelPartyQueueResponse) CancelPartyQueueResult {
	if response == nil {
		return CancelPartyQueueResult{}
	}
	statusText := response.GetQueueStatusText()
	if statusText == "" {
		statusText = response.GetQueueState()
	}
	return CancelPartyQueueResult{
		OK:                  response.GetOk(),
		QueueState:          response.GetQueueState(),
		QueuePhase:          response.GetQueuePhase(),
		QueueTerminalReason: response.GetQueueTerminalReason(),
		QueueStatusText:     response.GetQueueStatusText(),
		StatusText:          statusText,
		ErrorCode:           response.GetErrorCode(),
		UserMessage:         response.GetUserMessage(),
	}
}

func fromPBGetPartyQueueStatus(response *gamev1.GetPartyQueueStatusResponse) GetPartyQueueStatusResult {
	if response == nil {
		return GetPartyQueueStatusResult{}
	}
	return GetPartyQueueStatusResult{
		OK:                   response.GetOk(),
		QueueState:           response.GetQueueState(),
		QueuePhase:           response.GetQueuePhase(),
		QueueTerminalReason:  response.GetQueueTerminalReason(),
		QueueStatusText:      response.GetQueueStatusText(),
		AssignmentStatusText: response.GetAssignmentStatusText(),
		AllocationPhase:      response.GetAllocationPhase(),
		AllocationReason:     response.GetAllocationReason(),
		BattleEntryReady:     response.GetBattleEntryReady(),
		AssignmentID:         response.GetAssignmentId(),
		AssignmentRevision:   int(response.GetAssignmentRevision()),
		MatchID:              response.GetMatchId(),
		BattleID:             response.GetBattleId(),
		ServerHost:           response.GetServerHost(),
		ServerPort:           int(response.GetServerPort()),
		ErrorCode:            response.GetErrorCode(),
		UserMessage:          response.GetUserMessage(),
	}
}

func fromPBCreateManualRoomBattle(response *gamev1.CreateManualRoomBattleResponse) CreateManualRoomBattleResult {
	if response == nil {
		return CreateManualRoomBattleResult{}
	}
	ready := response.GetOk() && response.GetServerHost() != "" && response.GetServerPort() > 0
	return CreateManualRoomBattleResult{
		OK:                 response.GetOk(),
		AssignmentID:       response.GetAssignmentId(),
		AssignmentRevision: int(response.GetAssignmentRevision()),
		MatchID:            response.GetMatchId(),
		BattleID:           response.GetBattleId(),
		ServerHost:         response.GetServerHost(),
		ServerPort:         int(response.GetServerPort()),
		AllocationState:    "",
		Ready:              ready,
		ErrorCode:          response.GetErrorCode(),
		UserMessage:        response.GetUserMessage(),
	}
}

func fromPBGetBattleAssignmentStatus(response *gamev1.GetBattleAssignmentStatusResponse) GetBattleAssignmentStatusResult {
	if response == nil {
		return GetBattleAssignmentStatusResult{}
	}
	return GetBattleAssignmentStatusResult{
		OK:                 response.GetOk(),
		ErrorCode:          response.GetErrorCode(),
		UserMessage:        response.GetUserMessage(),
		RoomID:             response.GetRoomId(),
		AssignmentID:       response.GetAssignmentId(),
		AssignmentRevision: response.GetAssignmentRevision(),
		MatchID:            response.GetMatchId(),
		BattleID:           response.GetBattleId(),
		ServerHost:         response.GetServerHost(),
		ServerPort:         response.GetServerPort(),
		BattlePhase:        response.GetBattlePhase(),
		TerminalReason:     response.GetTerminalReason(),
		AllocationState:    response.GetAllocationState(),
		StatusText:         response.GetStatusText(),
		BattleEntryReady:   response.GetBattleEntryReady(),
		Finalized:          response.GetFinalized(),
	}
}

func fromPBCommitAssignmentReady(response *gamev1.CommitAssignmentReadyResponse) CommitAssignmentReadyResult {
	if response == nil {
		return CommitAssignmentReadyResult{}
	}
	return CommitAssignmentReadyResult{
		OK:             response.GetOk(),
		CommittedState: response.GetCommittedState(),
		ErrorCode:      response.GetErrorCode(),
		UserMessage:    response.GetUserMessage(),
	}
}
