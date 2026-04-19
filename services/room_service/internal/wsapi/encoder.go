package wsapi

import (
	"time"

	"google.golang.org/protobuf/encoding/protowire"

	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/roomapp"
)

func EncodeOperationAccepted(conn *Connection, requestID, operation string) []byte {
	msg := make([]byte, 0, 128)
	msg = appendString(msg, 1, "room.v1")
	msg = appendString(msg, 2, requestID)
	msg = appendVarint(msg, 3, uint64(conn.NextSequence()))
	msg = appendVarint(msg, 4, uint64(time.Now().UnixMilli()))

	accepted := make([]byte, 0, 64)
	accepted = appendString(accepted, 1, requestID)
	accepted = appendString(accepted, 2, operation)
	msg = appendBytes(msg, 10, accepted)
	return msg
}

func EncodeOperationRejected(conn *Connection, requestID, operation, code, userMessage string) []byte {
	msg := make([]byte, 0, 160)
	msg = appendString(msg, 1, "room.v1")
	msg = appendString(msg, 2, requestID)
	msg = appendVarint(msg, 3, uint64(conn.NextSequence()))
	msg = appendVarint(msg, 4, uint64(time.Now().UnixMilli()))

	rejected := make([]byte, 0, 96)
	rejected = appendString(rejected, 1, requestID)
	rejected = appendString(rejected, 2, operation)
	errMsg := make([]byte, 0, 48)
	errMsg = appendString(errMsg, 1, code)
	errMsg = appendString(errMsg, 2, userMessage)
	rejected = appendBytes(rejected, 3, errMsg)

	msg = appendBytes(msg, 11, rejected)
	return msg
}

func EncodeSnapshotPush(conn *Connection, requestID string, snapshot *roomapp.SnapshotProjection) []byte {
	msg := make([]byte, 0, 512)
	msg = appendString(msg, 1, "room.v1")
	msg = appendString(msg, 2, requestID)
	msg = appendVarint(msg, 3, uint64(conn.NextSequence()))
	msg = appendVarint(msg, 4, uint64(time.Now().UnixMilli()))

	push := make([]byte, 0, 400)
	push = appendBytes(push, 1, encodeSnapshot(snapshot))
	msg = appendBytes(msg, 12, push)
	return msg
}

func encodeSnapshot(snapshot *roomapp.SnapshotProjection) []byte {
	data := make([]byte, 0, 320)
	if snapshot == nil {
		return data
	}
	data = appendString(data, 1, snapshot.RoomID)
	data = appendString(data, 2, snapshot.RoomKind)
	data = appendString(data, 3, snapshot.RoomDisplayName)
	data = appendString(data, 4, snapshot.OwnerMemberID)
	data = appendVarint(data, 6, uint64(snapshot.SnapshotRevision))
	data = appendBytes(data, 7, encodeSelection(snapshot.Selection))
	for _, member := range snapshot.Members {
		data = appendBytes(data, 8, encodeMember(member))
	}
	return data
}

func encodeSelection(selection domain.RoomSelection) []byte {
	data := make([]byte, 0, 96)
	data = appendString(data, 1, selection.MapID)
	data = appendString(data, 2, selection.RuleSetID)
	data = appendString(data, 3, selection.ModeID)
	data = appendString(data, 4, selection.MatchFormatID)
	return data
}

func encodeMember(member domain.RoomMember) []byte {
	data := make([]byte, 0, 128)
	data = appendString(data, 1, member.MemberID)
	data = appendString(data, 2, member.AccountID)
	data = appendString(data, 3, member.ProfileID)
	data = appendString(data, 4, member.PlayerName)
	data = appendString(data, 7, member.ReconnectToken)
	if member.Ready {
		data = appendVarint(data, 6, 1)
	}
	return data
}

func appendString(dst []byte, fieldNumber protowire.Number, value string) []byte {
	if value == "" {
		return dst
	}
	dst = protowire.AppendTag(dst, fieldNumber, protowire.BytesType)
	return protowire.AppendString(dst, value)
}

func appendVarint(dst []byte, fieldNumber protowire.Number, value uint64) []byte {
	dst = protowire.AppendTag(dst, fieldNumber, protowire.VarintType)
	return protowire.AppendVarint(dst, value)
}

func appendBytes(dst []byte, fieldNumber protowire.Number, value []byte) []byte {
	dst = protowire.AppendTag(dst, fieldNumber, protowire.BytesType)
	return protowire.AppendBytes(dst, value)
}
