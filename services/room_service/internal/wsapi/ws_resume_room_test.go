package wsapi

import "testing"

func TestWSResumeRoom(t *testing.T) {
	server, socket := newTestServerAndSocket(t)
	defer socket.Close()
	defer func() { _ = server.Shutdown(t.Context()) }()

	if err := socket.WriteBinary(encodeClientEnvelopeCreate("req-create")); err != nil {
		t.Fatalf("write create envelope: %v", err)
	}
	_ = socket.ReadBinary(t) // accepted create
	createSnapshot := socket.ReadBinary(t)
	roomID, memberID, reconnectToken := decodeSnapshotMeta(createSnapshot)
	if roomID == "" || memberID == "" || reconnectToken == "" {
		t.Fatalf("expected room/member/reconnect token from create snapshot")
	}

	if err := socket.WriteBinary(encodeClientEnvelopeResume("req-resume", roomID, memberID, reconnectToken)); err != nil {
		t.Fatalf("write resume envelope: %v", err)
	}
	accepted := socket.ReadBinary(t)
	if operation := decodeServerOperationKind(accepted); operation != "ResumeRoom" {
		t.Fatalf("expected ResumeRoom accepted operation, got %s", operation)
	}
	snapshotPush := socket.ReadBinary(t)
	resumeRoomID, _, _ := decodeSnapshotMeta(snapshotPush)
	if resumeRoomID != roomID {
		t.Fatalf("expected resume room id %s, got %s", roomID, resumeRoomID)
	}
}
