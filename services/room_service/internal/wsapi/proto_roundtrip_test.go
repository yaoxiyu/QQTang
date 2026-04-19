package wsapi

import (
	"bytes"
	"testing"

	"google.golang.org/protobuf/proto"

	"qqtang/services/room_service/internal/domain"
	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
	"qqtang/services/room_service/internal/roomapp"
)

func TestDecodeClientEnvelope_CreateRoomRoundtrip(t *testing.T) {
	wire, err := proto.Marshal(&roomv1.ClientEnvelope{
		ProtocolVersion: "room.v1",
		RequestId:       "req-create-1",
		Sequence:        1,
		SentAtUnixMs:    1,
		Payload: &roomv1.ClientEnvelope_CreateRoom{
			CreateRoom: &roomv1.CreateRoomRequest{
				RoomKind:        "private_room",
				RoomDisplayName: "Room Alpha",
				RoomTicket:      "ticket-create",
				AccountId:       "acc-owner",
				ProfileId:       "pro-owner",
				PlayerName:      "owner",
				Loadout: &roomv1.RoomLoadout{
					CharacterId:     "char_default",
					CharacterSkinId: "skin_1",
					BubbleStyleId:   "bubble_default",
					BubbleSkinId:    "bubble_skin_1",
				},
				Selection: &roomv1.RoomSelection{
					MapId:         "map_arcade",
					RuleSetId:     "ruleset_classic",
					ModeId:        "mode_classic",
					MatchFormatId: "2v2",
				},
			},
		},
	})
	if err != nil {
		t.Fatalf("marshal client envelope: %v", err)
	}

	env, err := DecodeClientEnvelope(wire)
	if err != nil {
		t.Fatalf("decode envelope failed: %v", err)
	}
	if env.RequestID != "req-create-1" {
		t.Fatalf("unexpected request_id: %s", env.RequestID)
	}
	if env.PayloadType != PayloadCreateRoom || env.CreateRoom == nil {
		t.Fatalf("expected create_room payload")
	}
	if env.CreateRoom.PlayerName != "owner" {
		t.Fatalf("unexpected player_name: %s", env.CreateRoom.PlayerName)
	}
	if env.CreateRoom.Selection.MapID != "map_arcade" {
		t.Fatalf("unexpected map_id: %s", env.CreateRoom.Selection.MapID)
	}
}

func TestEncodeSnapshotPush_ContainsFieldsAndNoReconnectTokenLeak(t *testing.T) {
	conn := newConnection("conn-test", nil)
	uniqueReconnectToken := "reconnect-token-should-never-leak"
	snapshot := &roomapp.SnapshotProjection{
		RoomID:           "room-1",
		RoomKind:         "private_room",
		RoomDisplayName:  "Room 1",
		SnapshotRevision: 42,
		OwnerMemberID:    "member-1",
		Selection: domain.RoomSelection{
			MapID:         "map_arcade",
			RuleSetID:     "ruleset_classic",
			ModeID:        "mode_classic",
			MatchFormatID: "2v2",
		},
		Members: []domain.RoomMember{
			{
				MemberID:        "member-1",
				AccountID:       "acc-1",
				ProfileID:       "pro-1",
				PlayerName:      "owner",
				ConnectionState: "connected",
				ReconnectToken:  uniqueReconnectToken,
				Loadout: domain.RoomLoadout{
					CharacterID:     "char_default",
					CharacterSkinID: "skin_1",
					BubbleStyleID:   "bubble_default",
					BubbleSkinID:    "bubble_skin_1",
				},
			},
		},
	}

	wire := EncodeSnapshotPush(conn, "req-snap-1", snapshot)
	if bytes.Contains(wire, []byte(uniqueReconnectToken)) {
		t.Fatalf("snapshot push leaked reconnect token")
	}

	var env roomv1.ServerEnvelope
	if err := proto.Unmarshal(wire, &env); err != nil {
		t.Fatalf("unmarshal snapshot envelope: %v", err)
	}
	push := env.GetRoomSnapshotPush()
	if push == nil || push.GetSnapshot() == nil {
		t.Fatalf("expected room_snapshot_push payload")
	}
	mappedSnapshot := push.GetSnapshot()
	if mappedSnapshot.GetSnapshotRevision() != 42 {
		t.Fatalf("expected snapshot revision 42, got %d", mappedSnapshot.GetSnapshotRevision())
	}
	if mappedSnapshot.GetSelection().GetMapId() != "map_arcade" {
		t.Fatalf("expected map_arcade, got %s", mappedSnapshot.GetSelection().GetMapId())
	}
	if len(mappedSnapshot.GetMembers()) != 1 {
		t.Fatalf("expected one member, got %d", len(mappedSnapshot.GetMembers()))
	}
	member := mappedSnapshot.GetMembers()[0]
	if member.GetLoadout().GetCharacterId() != "char_default" {
		t.Fatalf("expected loadout character_id char_default, got %s", member.GetLoadout().GetCharacterId())
	}
}

func TestEncodeOperationAcceptedAndRejected(t *testing.T) {
	conn := newConnection("conn-test", nil)

	acceptedWire := EncodeOperationAccepted(conn, "req-1", "CreateRoom")
	var accepted roomv1.ServerEnvelope
	if err := proto.Unmarshal(acceptedWire, &accepted); err != nil {
		t.Fatalf("unmarshal accepted envelope: %v", err)
	}
	if accepted.GetOperationAccepted().GetOperation() != "CreateRoom" {
		t.Fatalf("unexpected accepted operation: %s", accepted.GetOperationAccepted().GetOperation())
	}

	rejectedWire := EncodeOperationRejected(conn, "req-2", "JoinRoom", "ROOM_JOIN_REJECTED", "join failed")
	var rejected roomv1.ServerEnvelope
	if err := proto.Unmarshal(rejectedWire, &rejected); err != nil {
		t.Fatalf("unmarshal rejected envelope: %v", err)
	}
	if rejected.GetOperationRejected().GetError().GetCode() != "ROOM_JOIN_REJECTED" {
		t.Fatalf("unexpected rejected code: %s", rejected.GetOperationRejected().GetError().GetCode())
	}
}

func TestEncodeDirectoryBattleNoticePushes(t *testing.T) {
	conn := newConnection("conn-test", nil)

	directoryWire := EncodeDirectorySnapshotPush(conn, "req-dir-1", &roomv1.RoomDirectorySnapshot{
		Revision:   7,
		ServerHost: "127.0.0.1",
		ServerPort: 9100,
	})
	var dirEnv roomv1.ServerEnvelope
	if err := proto.Unmarshal(directoryWire, &dirEnv); err != nil {
		t.Fatalf("unmarshal directory envelope: %v", err)
	}
	if dirEnv.GetRoomDirectorySnapshotPush() == nil {
		t.Fatalf("expected room_directory_snapshot_push payload")
	}

	battleWire := EncodeBattleEntryReadyPush(conn, "req-battle-1", domain.BattleHandoff{
		AssignmentID: "assignment-1",
		BattleID:     "battle-1",
		MatchID:      "match-1",
		ServerHost:   "127.0.0.1",
		ServerPort:   9200,
		Ready:        true,
	})
	var battleEnv roomv1.ServerEnvelope
	if err := proto.Unmarshal(battleWire, &battleEnv); err != nil {
		t.Fatalf("unmarshal battle envelope: %v", err)
	}
	if battleEnv.GetBattleEntryReadyPush() == nil {
		t.Fatalf("expected battle_entry_ready_push payload")
	}

	noticeWire := EncodeServerNotice(conn, "req-notice-1", "info", "ROOM_NOTICE", "ok")
	var noticeEnv roomv1.ServerEnvelope
	if err := proto.Unmarshal(noticeWire, &noticeEnv); err != nil {
		t.Fatalf("unmarshal notice envelope: %v", err)
	}
	if noticeEnv.GetServerNotice() == nil {
		t.Fatalf("expected server_notice payload")
	}
}
