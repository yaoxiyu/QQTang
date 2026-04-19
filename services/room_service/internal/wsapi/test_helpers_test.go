package wsapi

import (
	"log/slog"
	"net/url"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/encoding/protowire"
	"google.golang.org/protobuf/proto"

	"qqtang/services/room_service/internal/auth"
	"qqtang/services/room_service/internal/gameclient"
	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
	"qqtang/services/room_service/internal/manifest"
	"qqtang/services/room_service/internal/registry"
	"qqtang/services/room_service/internal/roomapp"
)

type testSocket struct {
	conn *websocket.Conn
}

func newTestServerAndSocket(t *testing.T) (*Server, *testSocket) {
	t.Helper()
	app := newTestRoomApp(t)
	server := NewServer("127.0.0.1:0", app, slog.Default())
	if err := server.Start(); err != nil {
		t.Fatalf("start ws server: %v", err)
	}

	wsURL := url.URL{Scheme: "ws", Host: server.Addr(), Path: "/ws"}
	conn, _, err := websocket.DefaultDialer.Dial(wsURL.String(), nil)
	if err != nil {
		_ = server.Shutdown(t.Context())
		t.Fatalf("dial ws server: %v", err)
	}
	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	return server, &testSocket{conn: conn}
}

func newTestRoomApp(t *testing.T) *roomapp.Service {
	t.Helper()
	manifestPath := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [
			{
				"map_id": "map_arcade",
				"display_name": "Arcade",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": ["2v2"],
				"required_team_count": 2,
				"max_player_count": 4,
				"custom_room_enabled": true,
				"casual_enabled": true,
				"ranked_enabled": false
			}
		],
		"modes": [
			{
				"mode_id": "mode_classic",
				"display_name": "Classic",
				"match_format_ids": ["2v2"],
				"selectable_in_match_room": true
			}
		],
		"rules": [
			{
				"rule_set_id": "ruleset_classic",
				"display_name": "Classic Rule"
			}
		],
		"match_formats": [
			{
				"match_format_id": "2v2",
				"required_party_size": 2,
				"expected_total_player_count": 4,
				"legal_mode_ids": ["mode_classic"],
				"map_pool_resolution_policy": "union_by_selected_modes"
			}
		],
		"assets": {
			"default_character_id": "char_default",
			"default_bubble_style_id": "bubble_default",
			"legal_character_ids": ["char_default", "char_2"],
			"legal_character_skin_ids": ["skin_1"],
			"legal_bubble_style_ids": ["bubble_default", "bubble_2"],
			"legal_bubble_skin_ids": ["bubble_skin_1"]
		}
	}`
	if err := os.WriteFile(manifestPath, []byte(content), 0o600); err != nil {
		t.Fatalf("write test manifest: %v", err)
	}
	loader, err := manifest.LoadFromFile(manifestPath)
	if err != nil {
		t.Fatalf("load test manifest: %v", err)
	}
	return roomapp.NewService(
		registry.New("test-instance", "test-shard"),
		loader,
		auth.NewTicketVerifier("test-secret"),
		gameclient.New("127.0.0.1:19081"),
	)
}

func (s *testSocket) Close() {
	if s == nil || s.conn == nil {
		return
	}
	_ = s.conn.Close()
}

func (s *testSocket) WriteBinary(payload []byte) error {
	return s.conn.WriteMessage(websocket.BinaryMessage, payload)
}

func (s *testSocket) ReadBinary(t *testing.T) []byte {
	t.Helper()
	msgType, payload, err := s.conn.ReadMessage()
	if err != nil {
		t.Fatalf("read ws message: %v", err)
	}
	if msgType != websocket.BinaryMessage {
		t.Fatalf("expected binary ws message, got %d", msgType)
	}
	return payload
}

func encodeClientEnvelopeCreate(requestID string) []byte {
	return encodeClientEnvelopeCreateWithRoomKind(requestID, "private_room")
}

func encodeClientEnvelopeCreateWithRoomKind(requestID, roomKind string) []byte {
	create := make([]byte, 0, 128)
	create = appendPBString(create, 2, roomKind)
	create = appendPBString(create, 3, "Room Alpha")
	create = appendPBString(create, 4, "ticket-create")
	create = appendPBString(create, 6, "acc-owner")
	create = appendPBString(create, 7, "pro-owner")
	create = appendPBString(create, 9, "owner")
	create = appendPBBytes(create, 10, encodeLoadout("char_default", "skin_1", "bubble_default", "bubble_skin_1"))
	create = appendPBBytes(create, 11, encodeSelectionMessage("map_arcade", "ruleset_classic", "mode_classic", "2v2"))

	env := make([]byte, 0, 160)
	env = appendPBString(env, 1, "room.v1")
	env = appendPBString(env, 2, requestID)
	env = appendPBVarint(env, 3, 1)
	env = appendPBVarint(env, 4, 1)
	env = appendPBBytes(env, 10, create)
	return env
}

func decodeDirectorySnapshot(payload []byte) *roomv1.RoomDirectorySnapshot {
	env := &roomv1.ServerEnvelope{}
	if err := proto.Unmarshal(payload, env); err != nil {
		return nil
	}
	push := env.GetRoomDirectorySnapshotPush()
	if push == nil {
		return nil
	}
	return push.Snapshot
}

func encodeClientEnvelopeJoin(requestID, roomID string) []byte {
	join := make([]byte, 0, 128)
	join = appendPBString(join, 1, roomID)
	join = appendPBString(join, 2, "ticket-join")
	join = appendPBString(join, 4, "acc-joiner")
	join = appendPBString(join, 5, "pro-joiner")
	join = appendPBString(join, 7, "joiner")
	join = appendPBBytes(join, 8, encodeLoadout("char_2", "", "bubble_2", ""))

	env := make([]byte, 0, 160)
	env = appendPBString(env, 1, "room.v1")
	env = appendPBString(env, 2, requestID)
	env = appendPBVarint(env, 3, 1)
	env = appendPBVarint(env, 4, 1)
	env = appendPBBytes(env, 11, join)
	return env
}

func encodeClientEnvelopeResume(requestID, roomID, memberID, reconnectToken string) []byte {
	resume := make([]byte, 0, 96)
	resume = appendPBString(resume, 1, roomID)
	resume = appendPBString(resume, 2, memberID)
	resume = appendPBString(resume, 3, reconnectToken)
	resume = appendPBString(resume, 5, "ticket-resume")

	env := make([]byte, 0, 128)
	env = appendPBString(env, 1, "room.v1")
	env = appendPBString(env, 2, requestID)
	env = appendPBVarint(env, 3, 1)
	env = appendPBVarint(env, 4, 1)
	env = appendPBBytes(env, 12, resume)
	return env
}

func encodeClientEnvelopeSubscribeDirectory(requestID string) []byte {
	env := make([]byte, 0, 32)
	env = appendPBString(env, 1, "room.v1")
	env = appendPBString(env, 2, requestID)
	env = appendPBVarint(env, 3, 1)
	env = appendPBVarint(env, 4, 1)
	env = appendPBBytes(env, 21, []byte{})
	return env
}

func encodeLoadout(characterID, skinID, bubbleStyleID, bubbleSkinID string) []byte {
	loadout := make([]byte, 0, 64)
	loadout = appendPBString(loadout, 1, characterID)
	loadout = appendPBString(loadout, 2, skinID)
	loadout = appendPBString(loadout, 3, bubbleStyleID)
	loadout = appendPBString(loadout, 4, bubbleSkinID)
	return loadout
}

func encodeSelectionMessage(mapID, ruleSetID, modeID, matchFormatID string) []byte {
	selection := make([]byte, 0, 64)
	selection = appendPBString(selection, 1, mapID)
	selection = appendPBString(selection, 2, ruleSetID)
	selection = appendPBString(selection, 3, modeID)
	selection = appendPBString(selection, 4, matchFormatID)
	return selection
}

func decodeServerOperationKind(payload []byte) string {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return ""
		}
		payload = payload[n:]
		if num == 10 && typ == protowire.BytesType {
			accepted, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return ""
			}
			return decodeAcceptedOperation(accepted)
		}
		if num == 11 && typ == protowire.BytesType {
			return "rejected"
		}
		m := protowire.ConsumeFieldValue(num, typ, payload)
		if m < 0 {
			return ""
		}
		payload = payload[m:]
	}
	return ""
}

func decodeAcceptedOperation(payload []byte) string {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return ""
		}
		payload = payload[n:]
		if num == 2 && typ == protowire.BytesType {
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return ""
			}
			return value
		}
		m := protowire.ConsumeFieldValue(num, typ, payload)
		if m < 0 {
			return ""
		}
		payload = payload[m:]
	}
	return ""
}

func decodeSnapshotMeta(payload []byte) (roomID string, memberID string, reconnectToken string) {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return "", "", ""
		}
		payload = payload[n:]
		if num == 12 && typ == protowire.BytesType {
			push, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return "", "", ""
			}
			return decodeSnapshotPush(push)
		}
		m := protowire.ConsumeFieldValue(num, typ, payload)
		if m < 0 {
			return "", "", ""
		}
		payload = payload[m:]
	}
	return "", "", ""
}

func decodeSnapshotPush(payload []byte) (roomID string, memberID string, reconnectToken string) {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return "", "", ""
		}
		payload = payload[n:]
		if num == 1 && typ == protowire.BytesType {
			snapshot, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return "", "", ""
			}
			return decodeSnapshot(snapshot)
		}
		m := protowire.ConsumeFieldValue(num, typ, payload)
		if m < 0 {
			return "", "", ""
		}
		payload = payload[m:]
	}
	return "", "", ""
}

func decodeSnapshot(payload []byte) (roomID string, memberID string, reconnectToken string) {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return roomID, memberID, reconnectToken
		}
		payload = payload[n:]
		switch num {
		case 1:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return roomID, memberID, reconnectToken
			}
			roomID = value
			payload = payload[m:]
		case 8:
			member, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return roomID, memberID, reconnectToken
			}
			mid, rtoken := decodeMember(member)
			if memberID == "" {
				memberID = mid
				reconnectToken = rtoken
			}
			payload = payload[m:]
		default:
			m := protowire.ConsumeFieldValue(num, typ, payload)
			if m < 0 {
				return roomID, memberID, reconnectToken
			}
			payload = payload[m:]
		}
	}
	return roomID, memberID, reconnectToken
}

func decodeMember(payload []byte) (memberID string, reconnectToken string) {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return memberID, reconnectToken
		}
		payload = payload[n:]
		switch num {
		case 1:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return memberID, reconnectToken
			}
			memberID = value
			payload = payload[m:]
		default:
			m := protowire.ConsumeFieldValue(num, typ, payload)
			if m < 0 {
				return memberID, reconnectToken
			}
			payload = payload[m:]
		}
	}
	return memberID, reconnectToken
}

func appendPBString(dst []byte, field protowire.Number, value string) []byte {
	if value == "" {
		return dst
	}
	dst = protowire.AppendTag(dst, field, protowire.BytesType)
	return protowire.AppendString(dst, value)
}

func appendPBVarint(dst []byte, field protowire.Number, value uint64) []byte {
	dst = protowire.AppendTag(dst, field, protowire.VarintType)
	return protowire.AppendVarint(dst, value)
}

func appendPBBytes(dst []byte, field protowire.Number, value []byte) []byte {
	dst = protowire.AppendTag(dst, field, protowire.BytesType)
	return protowire.AppendBytes(dst, value)
}
