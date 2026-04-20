package wsapi

import (
	"errors"
	"net"
	"net/url"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/proto"

	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
)

func TestWSDirectoryVisibilityPublicAndPrivate(t *testing.T) {
	server, dirSocket := newTestServerAndSocket(t)
	defer dirSocket.Close()
	defer func() { _ = server.Shutdown(t.Context()) }()

	creator := newAdditionalSocket(t, server.Addr())
	defer creator.Close()

	subscribeDirectory(t, dirSocket)
	_ = readDirectorySnapshot(t, dirSocket) // initial

	if err := creator.WriteBinary(encodeClientEnvelopeCreateWithRoomKind("req-create-public", "custom_room")); err != nil {
		t.Fatalf("write create public envelope: %v", err)
	}
	_ = creator.ReadBinary(t) // accepted
	publicCreateSnapshot := creator.ReadBinary(t)
	publicRoomID, _, _ := decodeSnapshotMeta(publicCreateSnapshot)
	if publicRoomID == "" {
		t.Fatalf("expected room id in public room create snapshot")
	}

	publicDirSnapshot := readDirectorySnapshot(t, dirSocket)
	if len(publicDirSnapshot.GetEntries()) != 1 {
		t.Fatalf("expected 1 directory entry after public create, got %d", len(publicDirSnapshot.GetEntries()))
	}
	if publicDirSnapshot.GetEntries()[0].GetRoomId() != publicRoomID {
		t.Fatalf("expected public room id %s in directory, got %s", publicRoomID, publicDirSnapshot.GetEntries()[0].GetRoomId())
	}

	if err := creator.WriteBinary(encodeClientEnvelopeCreateWithRoomKind("req-create-private", "private_room")); err != nil {
		t.Fatalf("write create private envelope: %v", err)
	}
	_ = creator.ReadBinary(t) // accepted
	_ = creator.ReadBinary(t) // room snapshot

	privateDirSnapshot := readDirectorySnapshot(t, dirSocket)
	if len(privateDirSnapshot.GetEntries()) != 1 {
		t.Fatalf("expected private room hidden from directory, got %d entries", len(privateDirSnapshot.GetEntries()))
	}
	if privateDirSnapshot.GetEntries()[0].GetRoomId() != publicRoomID {
		t.Fatalf("expected directory to keep only public room %s, got %s", publicRoomID, privateDirSnapshot.GetEntries()[0].GetRoomId())
	}
}

func TestWSDirectoryProjectionAndNonJoinableState(t *testing.T) {
	server, dirSocket := newTestServerAndSocket(t)
	defer dirSocket.Close()
	defer func() { _ = server.Shutdown(t.Context()) }()

	owner := newAdditionalSocket(t, server.Addr())
	defer owner.Close()

	subscribeDirectory(t, dirSocket)
	_ = readDirectorySnapshot(t, dirSocket) // initial

	if err := owner.WriteBinary(encodeClientEnvelopeCreateWithRoomKind("req-create-public", "custom_room")); err != nil {
		t.Fatalf("write create public envelope: %v", err)
	}
	_ = owner.ReadBinary(t) // accepted
	createSnapshot := owner.ReadBinary(t)
	roomID, _, _ := decodeSnapshotMeta(createSnapshot)
	if roomID == "" {
		t.Fatalf("expected room id from create snapshot")
	}
	_ = readDirectorySnapshot(t, dirSocket) // create broadcast

	joiners := []*testSocket{
		newAdditionalSocket(t, server.Addr()),
		newAdditionalSocket(t, server.Addr()),
		newAdditionalSocket(t, server.Addr()),
	}
	for _, joiner := range joiners {
		defer joiner.Close()
	}

	var lastDirSnapshot *roomv1.RoomDirectorySnapshot
	for i, joiner := range joiners {
		reqID := "req-join-" + string(rune('1'+i))
		if err := joiner.WriteBinary(encodeClientEnvelopeJoin(reqID, roomID)); err != nil {
			t.Fatalf("write join envelope %d: %v", i+1, err)
		}
		_ = joiner.ReadBinary(t) // accepted
		_ = joiner.ReadBinary(t) // room snapshot
		lastDirSnapshot = readDirectorySnapshot(t, dirSocket)
	}

	if lastDirSnapshot == nil || len(lastDirSnapshot.GetEntries()) != 1 {
		t.Fatalf("expected one directory entry after joins, got %+v", lastDirSnapshot)
	}
	entry := lastDirSnapshot.GetEntries()[0]
	if entry.GetRoomId() != roomID {
		t.Fatalf("expected room id %s, got %s", roomID, entry.GetRoomId())
	}
	if entry.GetRoomKind() != "custom_room" {
		t.Fatalf("expected room kind custom_room, got %s", entry.GetRoomKind())
	}
	if entry.GetMemberCount() != 4 {
		t.Fatalf("expected member count 4, got %d", entry.GetMemberCount())
	}
	if entry.GetMaxPlayerCount() != 4 {
		t.Fatalf("expected max player count 4, got %d", entry.GetMaxPlayerCount())
	}
	if entry.GetModeId() == "" || entry.GetMapId() == "" {
		t.Fatalf("expected non-empty mode/map projection, mode=%s map=%s", entry.GetModeId(), entry.GetMapId())
	}
	if entry.GetJoinable() {
		t.Fatalf("expected room to become non-joinable when full")
	}
}

func TestWSDirectorySubscriberNoUnrelatedNoise(t *testing.T) {
	server, dirSocket := newTestServerAndSocket(t)
	defer dirSocket.Close()
	defer func() { _ = server.Shutdown(t.Context()) }()

	actor := newAdditionalSocket(t, server.Addr())
	defer actor.Close()

	subscribeDirectory(t, dirSocket)
	_ = readDirectorySnapshot(t, dirSocket) // initial

	if err := actor.WriteBinary(encodeClientEnvelopeCreateWithRoomKind("req-create-public", "custom_room")); err != nil {
		t.Fatalf("write create public envelope: %v", err)
	}
	_ = actor.ReadBinary(t) // accepted
	createSnapshot := actor.ReadBinary(t)
	_, memberID, _ := decodeSnapshotMeta(createSnapshot)
	if memberID == "" {
		t.Fatalf("expected member id from create snapshot")
	}
	dirPush := dirSocket.ReadBinary(t)
	if decodeDirectorySnapshot(dirPush) == nil {
		t.Fatalf("expected directory snapshot push after create")
	}

	if err := actor.WriteBinary(encodeClientEnvelopeToggleReady("req-toggle-ready", true)); err != nil {
		t.Fatalf("write toggle ready envelope: %v", err)
	}
	_ = actor.ReadBinary(t) // accepted
	_ = actor.ReadBinary(t) // room snapshot

	_ = dirSocket.conn.SetReadDeadline(time.Now().Add(250 * time.Millisecond))
	_, _, err := dirSocket.conn.ReadMessage()
	if err == nil {
		t.Fatalf("expected no unrelated directory noise after toggle ready")
	}
	var netErr net.Error
	if !errors.As(err, &netErr) || !netErr.Timeout() {
		t.Fatalf("expected read timeout when asserting no noise, got %v", err)
	}
	_ = dirSocket.conn.SetReadDeadline(time.Now().Add(2 * time.Second))

	_ = memberID // keep explicit use from create snapshot validation path
}

func newAdditionalSocket(t *testing.T, addr string) *testSocket {
	t.Helper()
	wsURL := url.URL{Scheme: "ws", Host: addr, Path: "/ws"}
	conn, _, err := websocket.DefaultDialer.Dial(wsURL.String(), nil)
	if err != nil {
		t.Fatalf("dial extra ws client: %v", err)
	}
	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	return &testSocket{conn: conn}
}

func subscribeDirectory(t *testing.T, socket *testSocket) {
	t.Helper()
	if err := socket.WriteBinary(encodeClientEnvelopeSubscribeDirectory("req-subscribe-directory")); err != nil {
		t.Fatalf("write subscribe directory envelope: %v", err)
	}
	accepted := socket.ReadBinary(t)
	if operation := decodeServerOperationKind(accepted); operation != "SubscribeDirectory" {
		t.Fatalf("expected SubscribeDirectory accepted operation, got %s", operation)
	}
}

func readDirectorySnapshot(t *testing.T, socket *testSocket) *roomv1.RoomDirectorySnapshot {
	t.Helper()
	payload := socket.ReadBinary(t)
	snapshot := decodeDirectorySnapshot(payload)
	if snapshot == nil {
		t.Fatalf("expected room directory snapshot push")
	}
	return snapshot
}

func encodeClientEnvelopeToggleReady(requestID string, expectedReady bool) []byte {
	wire, err := proto.Marshal(&roomv1.ClientEnvelope{
		ProtocolVersion: "room.v1",
		RequestId:       requestID,
		Sequence:        1,
		SentAtUnixMs:    1,
		Payload: &roomv1.ClientEnvelope_ToggleReady{
			ToggleReady: &roomv1.ToggleReadyRequest{
				ExpectedReady: expectedReady,
			},
		},
	})
	if err != nil {
		return nil
	}
	return wire
}
