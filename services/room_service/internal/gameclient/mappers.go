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
			AccountId: member.AccountID,
			ProfileId: member.ProfileID,
			TeamId:    int32(member.TeamID),
		})
	}
	return result
}

func fromPBEnterPartyQueue(response *gamev1.EnterPartyQueueResponse) EnterPartyQueueResult {
	if response == nil {
		return EnterPartyQueueResult{}
	}
	return EnterPartyQueueResult{
		OK:           response.GetOk(),
		QueueEntryID: response.GetQueueEntryId(),
		QueueState:   response.GetQueueState(),
		StatusText:   response.GetQueueState(),
		ErrorCode:    response.GetErrorCode(),
		UserMessage:  response.GetUserMessage(),
	}
}

func fromPBCancelPartyQueue(response *gamev1.CancelPartyQueueResponse) CancelPartyQueueResult {
	if response == nil {
		return CancelPartyQueueResult{}
	}
	return CancelPartyQueueResult{
		OK:          response.GetOk(),
		QueueState:  response.GetQueueState(),
		StatusText:  response.GetQueueState(),
		ErrorCode:   response.GetErrorCode(),
		UserMessage: response.GetUserMessage(),
	}
}

func fromPBGetPartyQueueStatus(response *gamev1.GetPartyQueueStatusResponse) GetPartyQueueStatusResult {
	if response == nil {
		return GetPartyQueueStatusResult{}
	}
	return GetPartyQueueStatusResult{
		OK:           response.GetOk(),
		QueueState:   response.GetQueueState(),
		AssignmentID: response.GetAssignmentId(),
		MatchID:      response.GetMatchId(),
		BattleID:     response.GetBattleId(),
		ServerHost:   response.GetServerHost(),
		ServerPort:   int(response.GetServerPort()),
		ErrorCode:    response.GetErrorCode(),
		UserMessage:  response.GetUserMessage(),
	}
}

func fromPBCreateManualRoomBattle(response *gamev1.CreateManualRoomBattleResponse) CreateManualRoomBattleResult {
	if response == nil {
		return CreateManualRoomBattleResult{}
	}
	return CreateManualRoomBattleResult{
		OK:              response.GetOk(),
		AssignmentID:    response.GetAssignmentId(),
		MatchID:         response.GetMatchId(),
		BattleID:        response.GetBattleId(),
		ServerHost:      response.GetServerHost(),
		ServerPort:      int(response.GetServerPort()),
		AllocationState: "",
		Ready:           response.GetOk(),
		ErrorCode:       response.GetErrorCode(),
		UserMessage:     response.GetUserMessage(),
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
