package wsapi

import (
	"fmt"

	"google.golang.org/protobuf/proto"

	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
)

type PayloadType int

const (
	PayloadUnknown PayloadType = iota
	PayloadCreateRoom
	PayloadJoinRoom
	PayloadResumeRoom
	PayloadUpdateProfile
	PayloadUpdateSelection
	PayloadUpdateMatchRoomConfig
	PayloadToggleReady
	PayloadLeaveRoom
	PayloadSubscribeDirectory
	PayloadUnsubscribeDirectory
	PayloadStartManualRoomBattle
	PayloadEnterMatchQueue
	PayloadCancelMatchQueue
	PayloadAckBattleEntry
)

type ClientEnvelope struct {
	ProtocolVersion       string
	RequestID             string
	Sequence              int64
	SentAtUnixMS          int64
	PayloadType           PayloadType
	CreateRoom            *CreateRoomPayload
	JoinRoom              *JoinRoomPayload
	ResumeRoom            *ResumeRoomPayload
	UpdateProfile         *UpdateProfilePayload
	UpdateSelection       *UpdateSelectionPayload
	UpdateMatchRoomConfig *UpdateMatchRoomConfigPayload
	ToggleReady           *ToggleReadyPayload
	LeaveRoom             *LeaveRoomPayload
	SubscribeDirectory    *SubscribeDirectoryPayload
	UnsubscribeDirectory  *UnsubscribeDirectoryPayload
	StartManualRoomBattle *StartManualRoomBattlePayload
	EnterMatchQueue       *EnterMatchQueuePayload
	CancelMatchQueue      *CancelMatchQueuePayload
	AckBattleEntry        *AckBattleEntryPayload
}

type CreateRoomPayload struct {
	RoomKind        string
	RoomDisplayName string
	RoomTicket      string
	AccountID       string
	ProfileID       string
	PlayerName      string
	Loadout         LoadoutPayload
	Selection       SelectionPayload
}

type JoinRoomPayload struct {
	RoomID     string
	RoomTicket string
	AccountID  string
	ProfileID  string
	PlayerName string
	Loadout    LoadoutPayload
}

type ResumeRoomPayload struct {
	RoomID         string
	MemberID       string
	ReconnectToken string
	RoomTicket     string
}

type LoadoutPayload struct {
	CharacterID     string
	CharacterSkinID string
	BubbleStyleID   string
	BubbleSkinID    string
}

type SelectionPayload struct {
	MapID           string
	RuleSetID       string
	ModeID          string
	MatchFormatID   string
	SelectedModeIDs []string
}

type UpdateProfilePayload struct {
	PlayerName string
	TeamID     int
	Loadout    LoadoutPayload
}

type UpdateSelectionPayload struct {
	Selection       SelectionPayload
	OpenSlotIndices []int
}

type UpdateMatchRoomConfigPayload struct {
	MatchFormatID   string
	SelectedModeIDs []string
}

type ToggleReadyPayload struct {
	ExpectedReady bool
}

type LeaveRoomPayload struct{}

type SubscribeDirectoryPayload struct{}

type UnsubscribeDirectoryPayload struct{}

type StartManualRoomBattlePayload struct{}

type EnterMatchQueuePayload struct {
	QueueType     string
	MatchFormatID string
}

type CancelMatchQueuePayload struct{}

type AckBattleEntryPayload struct {
	AssignmentID string
	BattleID     string
}

func DecodeClientEnvelope(payload []byte) (*ClientEnvelope, error) {
	var pbEnv roomv1.ClientEnvelope
	if err := proto.Unmarshal(payload, &pbEnv); err != nil {
		return nil, fmt.Errorf("decode client envelope failed: %w", err)
	}
	if pbEnv.GetRequestId() == "" {
		return nil, fmt.Errorf("request_id is required")
	}
	if !isSupportedProtocolVersion(pbEnv.GetProtocolVersion()) {
		return nil, fmt.Errorf("unsupported protocol_version: %s", pbEnv.GetProtocolVersion())
	}
	env := &ClientEnvelope{
		ProtocolVersion: pbEnv.GetProtocolVersion(),
		RequestID:       pbEnv.GetRequestId(),
		Sequence:        pbEnv.GetSequence(),
		SentAtUnixMS:    pbEnv.GetSentAtUnixMs(),
	}
	switch pbEnv.Payload.(type) {
	case *roomv1.ClientEnvelope_CreateRoom:
		create := pbEnv.GetCreateRoom()
		env.PayloadType = PayloadCreateRoom
		env.CreateRoom = &CreateRoomPayload{
			RoomKind:        create.GetRoomKind(),
			RoomDisplayName: create.GetRoomDisplayName(),
			RoomTicket:      create.GetRoomTicket(),
			AccountID:       create.GetAccountId(),
			ProfileID:       create.GetProfileId(),
			PlayerName:      create.GetPlayerName(),
			Loadout:         decodeLoadout(create.GetLoadout()),
			Selection:       decodeSelection(create.GetSelection()),
		}
	case *roomv1.ClientEnvelope_JoinRoom:
		join := pbEnv.GetJoinRoom()
		env.PayloadType = PayloadJoinRoom
		env.JoinRoom = &JoinRoomPayload{
			RoomID:     join.GetRoomId(),
			RoomTicket: join.GetRoomTicket(),
			AccountID:  join.GetAccountId(),
			ProfileID:  join.GetProfileId(),
			PlayerName: join.GetPlayerName(),
			Loadout:    decodeLoadout(join.GetLoadout()),
		}
	case *roomv1.ClientEnvelope_ResumeRoom:
		resume := pbEnv.GetResumeRoom()
		env.PayloadType = PayloadResumeRoom
		env.ResumeRoom = &ResumeRoomPayload{
			RoomID:         resume.GetRoomId(),
			MemberID:       resume.GetMemberId(),
			ReconnectToken: resume.GetReconnectToken(),
			RoomTicket:     resume.GetRoomTicket(),
		}
	case *roomv1.ClientEnvelope_UpdateProfile:
		update := pbEnv.GetUpdateProfile()
		env.PayloadType = PayloadUpdateProfile
		env.UpdateProfile = &UpdateProfilePayload{
			PlayerName: update.GetPlayerName(),
			TeamID:     int(update.GetTeamId()),
			Loadout:    decodeLoadout(update.GetLoadout()),
		}
	case *roomv1.ClientEnvelope_UpdateSelection:
		update := pbEnv.GetUpdateSelection()
		env.PayloadType = PayloadUpdateSelection
		env.UpdateSelection = &UpdateSelectionPayload{
			Selection:       decodeSelection(update.GetSelection()),
			OpenSlotIndices: decodeInt32List(update.GetOpenSlotIndices()),
		}
	case *roomv1.ClientEnvelope_UpdateMatchRoomConfig:
		update := pbEnv.GetUpdateMatchRoomConfig()
		env.PayloadType = PayloadUpdateMatchRoomConfig
		env.UpdateMatchRoomConfig = &UpdateMatchRoomConfigPayload{
			MatchFormatID:   update.GetMatchFormatId(),
			SelectedModeIDs: append([]string{}, update.GetSelectedModeIds()...),
		}
	case *roomv1.ClientEnvelope_ToggleReady:
		update := pbEnv.GetToggleReady()
		env.PayloadType = PayloadToggleReady
		env.ToggleReady = &ToggleReadyPayload{
			ExpectedReady: update.GetExpectedReady(),
		}
	case *roomv1.ClientEnvelope_LeaveRoom:
		env.PayloadType = PayloadLeaveRoom
		env.LeaveRoom = &LeaveRoomPayload{}
	case *roomv1.ClientEnvelope_SubscribeDirectory:
		env.PayloadType = PayloadSubscribeDirectory
		env.SubscribeDirectory = &SubscribeDirectoryPayload{}
	case *roomv1.ClientEnvelope_UnsubscribeDirectory:
		env.PayloadType = PayloadUnsubscribeDirectory
		env.UnsubscribeDirectory = &UnsubscribeDirectoryPayload{}
	case *roomv1.ClientEnvelope_StartManualRoomBattle:
		env.PayloadType = PayloadStartManualRoomBattle
		env.StartManualRoomBattle = &StartManualRoomBattlePayload{}
	case *roomv1.ClientEnvelope_EnterMatchQueue:
		update := pbEnv.GetEnterMatchQueue()
		env.PayloadType = PayloadEnterMatchQueue
		env.EnterMatchQueue = &EnterMatchQueuePayload{
			QueueType:     update.GetQueueType(),
			MatchFormatID: update.GetMatchFormatId(),
		}
	case *roomv1.ClientEnvelope_CancelMatchQueue:
		env.PayloadType = PayloadCancelMatchQueue
		env.CancelMatchQueue = &CancelMatchQueuePayload{}
	case *roomv1.ClientEnvelope_AckBattleEntry:
		update := pbEnv.GetAckBattleEntry()
		env.PayloadType = PayloadAckBattleEntry
		env.AckBattleEntry = &AckBattleEntryPayload{
			AssignmentID: update.GetAssignmentId(),
			BattleID:     update.GetBattleId(),
		}
	default:
		env.PayloadType = PayloadUnknown
	}
	if env.PayloadType == PayloadUnknown {
		return nil, fmt.Errorf("envelope payload is empty")
	}
	return env, nil
}

func decodeInt32List(values []int32) []int {
	result := make([]int, 0, len(values))
	for _, value := range values {
		result = append(result, int(value))
	}
	return result
}

func isSupportedProtocolVersion(version string) bool {
	return version == "room.v1" || version == "1"
}

func decodeLoadout(loadout *roomv1.RoomLoadout) LoadoutPayload {
	if loadout == nil {
		return LoadoutPayload{}
	}
	return LoadoutPayload{
		CharacterID:     loadout.GetCharacterId(),
		CharacterSkinID: loadout.GetCharacterSkinId(),
		BubbleStyleID:   loadout.GetBubbleStyleId(),
		BubbleSkinID:    loadout.GetBubbleSkinId(),
	}
}

func decodeSelection(selection *roomv1.RoomSelection) SelectionPayload {
	if selection == nil {
		return SelectionPayload{}
	}
	return SelectionPayload{
		MapID:           selection.GetMapId(),
		RuleSetID:       selection.GetRuleSetId(),
		ModeID:          selection.GetModeId(),
		MatchFormatID:   selection.GetMatchFormatId(),
		SelectedModeIDs: append([]string{}, selection.GetSelectedModeIds()...),
	}
}
