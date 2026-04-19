package wsapi

import (
	"net/url"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestWSDirectorySubscriptionBroadcast(t *testing.T) {
	server, dirSocket := newTestServerAndSocket(t)
	defer dirSocket.Close()
	defer func() { _ = server.Shutdown(t.Context()) }()

	wsURL := url.URL{Scheme: "ws", Host: server.Addr(), Path: "/ws"}
	rawConn, _, err := websocket.DefaultDialer.Dial(wsURL.String(), nil)
	if err != nil {
		t.Fatalf("dial second ws client: %v", err)
	}
	_ = rawConn.SetReadDeadline(time.Now().Add(2 * time.Second))
	createSocket := &testSocket{conn: rawConn}
	defer createSocket.Close()

	if err := dirSocket.WriteBinary(encodeClientEnvelopeSubscribeDirectory("req-sub")); err != nil {
		t.Fatalf("write subscribe envelope: %v", err)
	}
	accepted := dirSocket.ReadBinary(t)
	if operation := decodeServerOperationKind(accepted); operation != "SubscribeDirectory" {
		t.Fatalf("expected SubscribeDirectory accepted operation, got %s", operation)
	}
	initialSnapshotWire := dirSocket.ReadBinary(t)
	initialSnapshot := decodeDirectorySnapshot(initialSnapshotWire)
	if initialSnapshot == nil {
		t.Fatalf("expected initial directory snapshot")
	}
	initialRevision := initialSnapshot.Revision

	if err := createSocket.WriteBinary(encodeClientEnvelopeCreateWithRoomKind("req-create-public", "custom_room")); err != nil {
		t.Fatalf("write create envelope: %v", err)
	}
	_ = createSocket.ReadBinary(t) // accepted create
	createSnapshot := createSocket.ReadBinary(t)
	roomID, _, _ := decodeSnapshotMeta(createSnapshot)
	if roomID == "" {
		t.Fatalf("expected room id from create snapshot")
	}

	broadcastWire := dirSocket.ReadBinary(t)
	broadcast := decodeDirectorySnapshot(broadcastWire)
	if broadcast == nil {
		t.Fatalf("expected directory broadcast snapshot")
	}
	if broadcast.Revision <= initialRevision {
		t.Fatalf("expected revision increase, initial=%d current=%d", initialRevision, broadcast.Revision)
	}
	if len(broadcast.Entries) == 0 {
		t.Fatalf("expected at least one directory entry")
	}
	if broadcast.Entries[0].GetRoomId() != roomID {
		t.Fatalf("expected room id %s, got %s", roomID, broadcast.Entries[0].GetRoomId())
	}
}
