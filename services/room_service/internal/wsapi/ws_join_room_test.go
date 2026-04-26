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

func TestWSJoinRoomBroadcastsSnapshotToExistingMembers(t *testing.T) {
	server, owner := newTestServerAndSocket(t)
	joiner := newTestSocketForServer(t, server)
	defer owner.Close()
	defer joiner.Close()
	defer func() { _ = server.Shutdown(t.Context()) }()

	if err := owner.WriteBinary(encodeClientEnvelopeCreate("req-create")); err != nil {
		t.Fatalf("write create envelope: %v", err)
	}
	_ = owner.ReadBinary(t)
	createSnapshot := owner.ReadBinary(t)
	roomID, _, _ := decodeSnapshotMeta(createSnapshot)
	if roomID == "" {
		t.Fatalf("expected room id from create snapshot")
	}

	if err := joiner.WriteBinary(encodeClientEnvelopeJoin("req-join", roomID)); err != nil {
		t.Fatalf("write join envelope: %v", err)
	}
	_ = joiner.ReadBinary(t)
	joinerSnapshot := joiner.ReadBinary(t)
	if count := decodeSnapshotMemberCount(t, joinerSnapshot); count != 2 {
		t.Fatalf("expected joiner snapshot member count 2, got %d", count)
	}
	if localMemberID := decodeSnapshotLocalMemberID(t, joinerSnapshot); localMemberID == "" {
		t.Fatalf("expected joiner snapshot to include local member id")
	}

	ownerBroadcast := owner.ReadBinary(t)
	if broadcastRoomID, _, _ := decodeSnapshotMeta(ownerBroadcast); broadcastRoomID != roomID {
		t.Fatalf("expected owner broadcast room id %s, got %s", roomID, broadcastRoomID)
	}
	if count := decodeSnapshotMemberCount(t, ownerBroadcast); count != 2 {
		t.Fatalf("expected owner broadcast member count 2, got %d", count)
	}
	if localMemberID := decodeSnapshotLocalMemberID(t, ownerBroadcast); localMemberID == "" {
		t.Fatalf("expected owner broadcast to include local member id")
	}
}

func TestWSUpdateSelectionBroadcastsOpenSlotsToOtherMembers(t *testing.T) {
	server, owner := newTestServerAndSocket(t)
	joiner := newTestSocketForServer(t, server)
	defer owner.Close()
	defer joiner.Close()
	defer func() { _ = server.Shutdown(t.Context()) }()

	if err := owner.WriteBinary(encodeClientEnvelopeCreate("req-create")); err != nil {
		t.Fatalf("write create envelope: %v", err)
	}
	_ = owner.ReadBinary(t)
	createSnapshot := owner.ReadBinary(t)
	roomID, _, _ := decodeSnapshotMeta(createSnapshot)
	if roomID == "" {
		t.Fatalf("expected room id from create snapshot")
	}

	if err := joiner.WriteBinary(encodeClientEnvelopeJoin("req-join", roomID)); err != nil {
		t.Fatalf("write join envelope: %v", err)
	}
	_ = joiner.ReadBinary(t)
	_ = joiner.ReadBinary(t)
	_ = owner.ReadBinary(t)

	if err := owner.WriteBinary(encodeClientEnvelopeUpdateSelection("req-update-selection", []int32{0, 1})); err != nil {
		t.Fatalf("write update selection envelope: %v", err)
	}
	_ = owner.ReadBinary(t)
	ownerSnapshot := owner.ReadBinary(t)
	if slots := decodeSnapshotOpenSlotIndices(t, ownerSnapshot); len(slots) != 2 || slots[0] != 0 || slots[1] != 1 {
		t.Fatalf("expected owner update snapshot open slots [0 1], got %+v", slots)
	}

	joinerBroadcast := joiner.ReadBinary(t)
	if slots := decodeSnapshotOpenSlotIndices(t, joinerBroadcast); len(slots) != 2 || slots[0] != 0 || slots[1] != 1 {
		t.Fatalf("expected joiner broadcast open slots [0 1], got %+v", slots)
	}
}
