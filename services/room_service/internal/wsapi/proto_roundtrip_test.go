package wsapi

import (
	"testing"

	"google.golang.org/protobuf/encoding/protowire"

	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/roomapp"
)

func TestDecodeClientEnvelope_CreateRoomRoundtrip(t *testing.T) {
	wire := encodeClientEnvelopeCreate("req-create-1")
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

func TestEncodeSnapshotPush_ContainsSnapshotRevision(t *testing.T) {
	conn := newConnection("conn-test", nil)
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
				MemberID:       "member-1",
				AccountID:      "acc-1",
				ProfileID:      "pro-1",
				PlayerName:     "owner",
				ReconnectToken: "reconnect-1",
			},
		},
	}

	wire := EncodeSnapshotPush(conn, "req-snap-1", snapshot)
	revision := decodeSnapshotRevisionFromServerEnvelope(wire)
	if revision != 42 {
		t.Fatalf("expected snapshot revision 42, got %d", revision)
	}
}

func TestEncodeOperationAcceptedAndRejected(t *testing.T) {
	conn := newConnection("conn-test", nil)

	accepted := EncodeOperationAccepted(conn, "req-1", "CreateRoom")
	if op := decodeAcceptedOperationFromServerEnvelope(accepted); op != "CreateRoom" {
		t.Fatalf("unexpected accepted operation: %s", op)
	}

	rejected := EncodeOperationRejected(conn, "req-2", "JoinRoom", "ROOM_JOIN_REJECTED", "join failed")
	code := decodeRejectedCodeFromServerEnvelope(rejected)
	if code != "ROOM_JOIN_REJECTED" {
		t.Fatalf("unexpected rejected code: %s", code)
	}
}

func decodeSnapshotRevisionFromServerEnvelope(payload []byte) int64 {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return 0
		}
		payload = payload[n:]
		if num == 12 && typ == protowire.BytesType {
			push, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return 0
			}
			return decodeSnapshotRevisionFromPush(push)
		}
		m := protowire.ConsumeFieldValue(num, typ, payload)
		if m < 0 {
			return 0
		}
		payload = payload[m:]
	}
	return 0
}

func decodeSnapshotRevisionFromPush(payload []byte) int64 {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return 0
		}
		payload = payload[n:]
		if num == 1 && typ == protowire.BytesType {
			snapshot, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return 0
			}
			return decodeSnapshotRevision(snapshot)
		}
		m := protowire.ConsumeFieldValue(num, typ, payload)
		if m < 0 {
			return 0
		}
		payload = payload[m:]
	}
	return 0
}

func decodeSnapshotRevision(payload []byte) int64 {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return 0
		}
		payload = payload[n:]
		if num == 6 && typ == protowire.VarintType {
			v, m := protowire.ConsumeVarint(payload)
			if m < 0 {
				return 0
			}
			return int64(v)
		}
		m := protowire.ConsumeFieldValue(num, typ, payload)
		if m < 0 {
			return 0
		}
		payload = payload[m:]
	}
	return 0
}

func decodeAcceptedOperationFromServerEnvelope(payload []byte) string {
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
			for len(accepted) > 0 {
				an, at, ax := protowire.ConsumeTag(accepted)
				if ax < 0 {
					return ""
				}
				accepted = accepted[ax:]
				if an == 2 && at == protowire.BytesType {
					op, om := protowire.ConsumeString(accepted)
					if om < 0 {
						return ""
					}
					return op
				}
				om := protowire.ConsumeFieldValue(an, at, accepted)
				if om < 0 {
					return ""
				}
				accepted = accepted[om:]
			}
		}
		m := protowire.ConsumeFieldValue(num, typ, payload)
		if m < 0 {
			return ""
		}
		payload = payload[m:]
	}
	return ""
}

func decodeRejectedCodeFromServerEnvelope(payload []byte) string {
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return ""
		}
		payload = payload[n:]
		if num == 11 && typ == protowire.BytesType {
			rejected, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return ""
			}
			for len(rejected) > 0 {
				rn, rt, rx := protowire.ConsumeTag(rejected)
				if rx < 0 {
					return ""
				}
				rejected = rejected[rx:]
				if rn == 3 && rt == protowire.BytesType {
					opErr, em := protowire.ConsumeBytes(rejected)
					if em < 0 {
						return ""
					}
					for len(opErr) > 0 {
						en, et, ex := protowire.ConsumeTag(opErr)
						if ex < 0 {
							return ""
						}
						opErr = opErr[ex:]
						if en == 1 && et == protowire.BytesType {
							code, cm := protowire.ConsumeString(opErr)
							if cm < 0 {
								return ""
							}
							return code
						}
						cm := protowire.ConsumeFieldValue(en, et, opErr)
						if cm < 0 {
							return ""
						}
						opErr = opErr[cm:]
					}
				}
				rm := protowire.ConsumeFieldValue(rn, rt, rejected)
				if rm < 0 {
					return ""
				}
				rejected = rejected[rm:]
			}
		}
		m := protowire.ConsumeFieldValue(num, typ, payload)
		if m < 0 {
			return ""
		}
		payload = payload[m:]
	}
	return ""
}
