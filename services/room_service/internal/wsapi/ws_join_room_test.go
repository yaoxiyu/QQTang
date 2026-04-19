package wsapi

import "testing"

func TestWSJoinRoom(t *testing.T) {
	server, socket := newTestServerAndSocket(t)
	defer socket.Close()
	defer func() { _ = server.Shutdown(t.Context()) }()

	if err := socket.WriteBinary(encodeClientEnvelopeCreate("req-create")); err != nil {
		t.Fatalf("write create envelope: %v", err)
	}
	_ = socket.ReadBinary(t) // accepted create
	createSnapshot := socket.ReadBinary(t)
	roomID, _, _ := decodeSnapshotMeta(createSnapshot)
	if roomID == "" {
		t.Fatalf("expected room id from create snapshot")
	}

	if err := socket.WriteBinary(encodeClientEnvelopeJoin("req-join", roomID)); err != nil {
		t.Fatalf("write join envelope: %v", err)
	}
	accepted := socket.ReadBinary(t)
	if operation := decodeServerOperationKind(accepted); operation != "JoinRoom" {
		t.Fatalf("expected JoinRoom accepted operation, got %s", operation)
	}
	snapshotPush := socket.ReadBinary(t)
	joinedRoomID, _, _ := decodeSnapshotMeta(snapshotPush)
	if joinedRoomID != roomID {
		t.Fatalf("expected joined room id %s, got %s", roomID, joinedRoomID)
	}
}
