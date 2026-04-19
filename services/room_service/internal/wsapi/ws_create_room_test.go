package wsapi

import "testing"

func TestWSCreateRoom(t *testing.T) {
	server, socket := newTestServerAndSocket(t)
	defer socket.Close()
	defer func() { _ = server.Shutdown(t.Context()) }()

	if err := socket.WriteBinary(encodeClientEnvelopeCreate("req-create")); err != nil {
		t.Fatalf("write create envelope: %v", err)
	}

	accepted := socket.ReadBinary(t)
	if operation := decodeServerOperationKind(accepted); operation != "CreateRoom" {
		t.Fatalf("expected CreateRoom accepted operation, got %s", operation)
	}

	snapshotPush := socket.ReadBinary(t)
	roomID, _, _ := decodeSnapshotMeta(snapshotPush)
	if roomID == "" {
		t.Fatalf("expected snapshot push with room id")
	}
}
