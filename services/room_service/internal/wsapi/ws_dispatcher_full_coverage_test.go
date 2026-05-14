package wsapi

import (
	"testing"

	"google.golang.org/protobuf/proto"

	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
	"qqtang/services/room_service/internal/roomapp"
)

func TestDispatcherFullOperationCoverage(t *testing.T) {
	app := newTestRoomApp(t)
	dispatcher := NewDispatcher(app)
	conn := newConnection("conn-dispatcher", nil)

	createOutbound, err := dispatcher.Dispatch(conn, &ClientEnvelope{
		RequestID:   "req-create",
		PayloadType: PayloadCreateRoom,
		CreateRoom: &CreateRoomPayload{
			RoomKind:        "private_room",
			RoomDisplayName: "alpha",
			RoomTicket:      mustIssueWsCreateRoomTicket("private_room", "acc_1", "pro_1"),
			AccountID:       "acc_1",
			ProfileID:       "pro_1",
			PlayerName:      "p1",
			Loadout: LoadoutPayload{
				CharacterID:   "char_default",
				BubbleStyleID: "bubble_default",
			},
			Selection: SelectionPayload{
				MapID:         "map_arcade",
				RuleSetID:     "ruleset_classic",
				ModeID:        "mode_classic",
				MatchFormatID: "2v2",
			},
		},
	})
	if err != nil {
		t.Fatalf("dispatch create: %v", err)
	}
	assertAcceptedOperation(t, createOutbound, "CreateRoom")
	roomID, memberID := resolveCallerByConnection(t, app, conn.ID())

	assertAcceptedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:   "req-update-profile",
		PayloadType: PayloadUpdateProfile,
		UpdateProfile: &UpdateProfilePayload{
			PlayerName: "p1-new",
			Loadout: LoadoutPayload{
				CharacterID:   "char_default",
				BubbleStyleID: "bubble_default",
			},
		},
	}), "UpdateProfile")

	assertAcceptedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:   "req-update-selection",
		PayloadType: PayloadUpdateSelection,
		UpdateSelection: &UpdateSelectionPayload{
			Selection: SelectionPayload{
				MapID:         "map_arcade",
				RuleSetID:     "ruleset_classic",
				ModeID:        "mode_classic",
				MatchFormatID: "2v2",
			},
		},
	}), "UpdateSelection")

	assertAcceptedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:   "req-toggle-ready",
		PayloadType: PayloadToggleReady,
		ToggleReady: &ToggleReadyPayload{ExpectedReady: true},
	}), "ToggleReady")

	assertAcceptedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:          "req-subscribe-directory",
		PayloadType:        PayloadSubscribeDirectory,
		SubscribeDirectory: &SubscribeDirectoryPayload{},
	}), "SubscribeDirectory")

	assertAcceptedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:            "req-unsubscribe-directory",
		PayloadType:          PayloadUnsubscribeDirectory,
		UnsubscribeDirectory: &UnsubscribeDirectoryPayload{},
	}), "UnsubscribeDirectory")

	assertRejectedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:             "req-update-match-room-config",
		PayloadType:           PayloadUpdateMatchRoomConfig,
		UpdateMatchRoomConfig: &UpdateMatchRoomConfigPayload{MatchFormatID: "2v2", SelectedModeIDs: []string{"mode_classic"}},
	}), "UpdateMatchRoomConfig")

	assertRejectedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:       "req-enter-queue",
		PayloadType:     PayloadEnterMatchQueue,
		EnterMatchQueue: &EnterMatchQueuePayload{QueueType: "casual", MatchFormatID: "2v2"},
	}), "EnterMatchQueue")

	assertRejectedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:             "req-start-manual",
		PayloadType:           PayloadStartManualRoomBattle,
		StartManualRoomBattle: &StartManualRoomBattlePayload{},
	}), "StartManualRoomBattle")

	assertRejectedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:        "req-cancel-queue",
		PayloadType:      PayloadCancelMatchQueue,
		CancelMatchQueue: &CancelMatchQueuePayload{},
	}), "CancelMatchQueue")

	assertRejectedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:      "req-ack-battle",
		PayloadType:    PayloadAckBattleEntry,
		AckBattleEntry: &AckBattleEntryPayload{AssignmentID: "assign_1", BattleID: "battle_1"},
	}), "AckBattleEntry")

	assertAcceptedOperation(t, dispatchOrFail(t, dispatcher, conn, &ClientEnvelope{
		RequestID:   "req-leave",
		PayloadType: PayloadLeaveRoom,
		LeaveRoom:   &LeaveRoomPayload{},
	}), "LeaveRoom")

	if _, _, err := app.ResolveRoomMemberByConnection(conn.ID()); err == nil {
		t.Fatalf("expected room member binding cleared after leave")
	}
	if _, err := app.SnapshotProjection(roomID); err == nil && memberID != "" {
		t.Fatalf("expected room removed after last member leave")
	}
}

func dispatchOrFail(t *testing.T, dispatcher *Dispatcher, conn *Connection, env *ClientEnvelope) [][]byte {
	t.Helper()
	outbound, err := dispatcher.Dispatch(conn, env)
	if err != nil {
		t.Fatalf("dispatch %s failed: %v", env.RequestID, err)
	}
	return outbound
}

func assertAcceptedOperation(t *testing.T, outbound [][]byte, operation string) {
	t.Helper()
	env := decodeServerEnvelopeOrFail(t, outbound[0])
	accepted := env.GetOperationAccepted()
	if accepted == nil {
		t.Fatalf("expected operation accepted for %s", operation)
	}
	if accepted.GetOperation() != operation {
		t.Fatalf("expected accepted operation %s, got %s", operation, accepted.GetOperation())
	}
}

func assertRejectedOperation(t *testing.T, outbound [][]byte, operation string) {
	t.Helper()
	env := decodeServerEnvelopeOrFail(t, outbound[0])
	rejected := env.GetOperationRejected()
	if rejected == nil {
		t.Fatalf("expected operation rejected for %s", operation)
	}
	if rejected.GetOperation() != operation {
		t.Fatalf("expected rejected operation %s, got %s", operation, rejected.GetOperation())
	}
}

func decodeServerEnvelopeOrFail(t *testing.T, wire []byte) *roomv1.ServerEnvelope {
	t.Helper()
	var env roomv1.ServerEnvelope
	if err := proto.Unmarshal(wire, &env); err != nil {
		t.Fatalf("unmarshal server envelope: %v", err)
	}
	return &env
}

func resolveCallerByConnection(t *testing.T, app *roomapp.Service, connectionID string) (string, string) {
	t.Helper()
	roomID, memberID, err := app.ResolveRoomMemberByConnection(connectionID)
	if err != nil {
		t.Fatalf("resolve caller by connection: %v", err)
	}
	return roomID, memberID
}
