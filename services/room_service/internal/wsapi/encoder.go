package wsapi

import (
	"time"

	"google.golang.org/protobuf/proto"

	"qqtang/services/room_service/internal/domain"
	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
	"qqtang/services/room_service/internal/roomapp"
)

func EncodeOperationAccepted(conn *Connection, requestID, operation string) []byte {
	return mustMarshalServerEnvelope(conn, requestID, &roomv1.ServerEnvelope{
		Payload: &roomv1.ServerEnvelope_OperationAccepted{
			OperationAccepted: &roomv1.OperationAccepted{
				RequestId: requestID,
				Operation: operation,
			},
		},
	})
}

func EncodeOperationRejected(conn *Connection, requestID, operation, code, userMessage string) []byte {
	return mustMarshalServerEnvelope(conn, requestID, &roomv1.ServerEnvelope{
		Payload: &roomv1.ServerEnvelope_OperationRejected{
			OperationRejected: &roomv1.OperationRejected{
				RequestId: requestID,
				Operation: operation,
				Error: &roomv1.OperationError{
					Code:        code,
					UserMessage: userMessage,
				},
			},
		},
	})
}

func EncodeSnapshotPush(conn *Connection, requestID string, snapshot *roomapp.SnapshotProjection) []byte {
	encodedSnapshot := encodeSnapshot(snapshot)
	if conn != nil {
		encodedSnapshot.LocalMemberId = conn.BoundMemberID()
	}
	return mustMarshalServerEnvelope(conn, requestID, &roomv1.ServerEnvelope{
		Payload: &roomv1.ServerEnvelope_RoomSnapshotPush{
			RoomSnapshotPush: &roomv1.RoomSnapshotPush{
				Snapshot: encodedSnapshot,
			},
		},
	})
}

func EncodeDirectorySnapshotPush(conn *Connection, requestID string, snapshot *roomv1.RoomDirectorySnapshot) []byte {
	if snapshot == nil {
		snapshot = &roomv1.RoomDirectorySnapshot{}
	}
	return mustMarshalServerEnvelope(conn, requestID, &roomv1.ServerEnvelope{
		Payload: &roomv1.ServerEnvelope_RoomDirectorySnapshotPush{
			RoomDirectorySnapshotPush: &roomv1.RoomDirectorySnapshotPush{
				Snapshot: snapshot,
			},
		},
	})
}

func EncodeBattleEntryReadyPush(conn *Connection, requestID string, handoff domain.BattleHandoff) []byte {
	return mustMarshalServerEnvelope(conn, requestID, &roomv1.ServerEnvelope{
		Payload: &roomv1.ServerEnvelope_BattleEntryReadyPush{
			BattleEntryReadyPush: &roomv1.BattleEntryReadyPush{
				BattleEntry: encodeBattleEntry(handoff),
			},
		},
	})
}

func EncodeBattleEntryReadyPushFromSnapshot(conn *Connection, requestID string, snapshot *roomapp.SnapshotProjection) []byte {
	return mustMarshalServerEnvelope(conn, requestID, &roomv1.ServerEnvelope{
		Payload: &roomv1.ServerEnvelope_BattleEntryReadyPush{
			BattleEntryReadyPush: &roomv1.BattleEntryReadyPush{
				BattleEntry: encodeBattleEntryFromSnapshot(snapshot),
			},
		},
	})
}

func EncodeServerNotice(conn *Connection, requestID, level, code, message string) []byte {
	return mustMarshalServerEnvelope(conn, requestID, &roomv1.ServerEnvelope{
		Payload: &roomv1.ServerEnvelope_ServerNotice{
			ServerNotice: &roomv1.ServerNotice{
				Level:   level,
				Code:    code,
				Message: message,
			},
		},
	})
}

func mustMarshalServerEnvelope(conn *Connection, requestID string, env *roomv1.ServerEnvelope) []byte {
	if env == nil {
		env = &roomv1.ServerEnvelope{}
	}
	env.ProtocolVersion = "room.v1"
	env.RequestId = requestID
	env.Sequence = conn.NextSequence()
	env.SentAtUnixMs = time.Now().UnixMilli()
	data, err := proto.Marshal(env)
	if err != nil {
		return []byte{}
	}
	return data
}

func encodeSnapshot(snapshot *roomapp.SnapshotProjection) *roomv1.RoomSnapshot {
	if snapshot == nil {
		return &roomv1.RoomSnapshot{}
	}
	result := &roomv1.RoomSnapshot{
		RoomId:                   snapshot.RoomID,
		RoomKind:                 snapshot.RoomKind,
		RoomDisplayName:          snapshot.RoomDisplayName,
		OwnerMemberId:            snapshot.OwnerMemberID,
		LifecycleState:           snapshot.LifecycleState,
		SnapshotRevision:         snapshot.SnapshotRevision,
		Selection:                encodeSelection(snapshot.Selection),
		QueueState:               snapshot.QueueState.QueueState,
		RoomPhase:                snapshot.RoomPhase,
		RoomPhaseReason:          snapshot.RoomPhaseReason,
		QueuePhase:               snapshot.QueuePhase,
		QueueTerminalReason:      snapshot.QueueTerminalReason,
		QueueStatusText:          snapshot.QueueStatusText,
		QueueErrorCode:           snapshot.QueueErrorCode,
		QueueUserMessage:         snapshot.QueueUserMessage,
		QueueEntryId:             snapshot.QueueEntryID,
		CanToggleReady:           snapshot.Capabilities.CanToggleReady,
		CanStartManualBattle:     snapshot.Capabilities.CanStartManualBattle,
		CanUpdateSelection:       snapshot.Capabilities.CanUpdateSelection,
		CanUpdateMatchRoomConfig: snapshot.Capabilities.CanUpdateMatchRoomConfig,
		CanEnterQueue:            snapshot.Capabilities.CanEnterQueue,
		CanCancelQueue:           snapshot.Capabilities.CanCancelQueue,
		CanLeaveRoom:             snapshot.Capabilities.CanLeaveRoom,
		BattleEntry:              encodeBattleEntryFromSnapshot(snapshot),
		MaxPlayerCount:           int32(snapshot.MaxPlayerCount),
	}
	for _, slotIndex := range snapshot.OpenSlotIndices {
		result.OpenSlotIndices = append(result.OpenSlotIndices, int32(slotIndex))
	}
	result.Members = make([]*roomv1.RoomMember, 0, len(snapshot.Members))
	for _, member := range snapshot.Members {
		result.Members = append(result.Members, encodeMember(member))
	}
	return result
}

func encodeSelection(selection domain.RoomSelection) *roomv1.RoomSelection {
	return &roomv1.RoomSelection{
		MapId:           selection.MapID,
		RuleSetId:       selection.RuleSetID,
		ModeId:          selection.ModeID,
		MatchFormatId:   selection.MatchFormatID,
		SelectedModeIds: append([]string{}, selection.SelectedModeIDs...),
	}
}

func encodeMember(member domain.RoomMember) *roomv1.RoomMember {
	return &roomv1.RoomMember{
		MemberId:        member.MemberID,
		AccountId:       member.AccountID,
		ProfileId:       member.ProfileID,
		PlayerName:      member.PlayerName,
		TeamId:          int32(member.TeamID),
		Ready:           member.Ready,
		Loadout:         mapLoadout(member.Loadout),
		ConnectionState: member.ConnectionState,
		MemberPhase:     member.MemberPhase,
		SlotIndex:       int32(member.SlotIndex),
	}
}

func mapLoadout(loadout domain.RoomLoadout) *roomv1.RoomLoadout {
	return &roomv1.RoomLoadout{
		CharacterId:     loadout.CharacterID,
		BubbleStyleId:   loadout.BubbleStyleID,
	}
}

func encodeBattleEntry(h domain.BattleHandoff) *roomv1.BattleEntryState {
	return &roomv1.BattleEntryState{
		AssignmentId:     h.AssignmentID,
		BattleId:         h.BattleID,
		MatchId:          h.MatchID,
		ServerHost:       h.ServerHost,
		ServerPort:       int32(h.ServerPort),
		BattleEntryReady: h.Ready,
	}
}

func encodeBattleEntryFromSnapshot(snapshot *roomapp.SnapshotProjection) *roomv1.BattleEntryState {
	if snapshot == nil {
		return &roomv1.BattleEntryState{}
	}
	entry := encodeBattleEntry(snapshot.BattleHandoff)
	entry.Phase = snapshot.BattlePhase
	entry.TerminalReason = snapshot.BattleTerminalReason
	entry.StatusText = snapshot.BattleStatusText
	return entry
}
