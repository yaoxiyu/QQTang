package registry

import "testing"

func TestRegistryUpsertRoomEntryAddsAndUpdates(t *testing.T) {
	r := New("instance-a", "shard-a")

	r.UpsertRoomEntry(DirectoryEntry{
		RoomID:         "room-a",
		ModeID:         "mode-1",
		MapID:          "map-1",
		MemberCount:    1,
		MaxPlayerCount: 4,
		Joinable:       true,
	})

	first := r.DirectorySnapshot()
	if first.Revision != 1 {
		t.Fatalf("expected revision 1 after first upsert, got %d", first.Revision)
	}
	if len(first.Entries) != 1 {
		t.Fatalf("expected 1 directory entry after first upsert, got %d", len(first.Entries))
	}
	if first.Entries[0].MemberCount != 1 {
		t.Fatalf("expected first upsert member count 1, got %d", first.Entries[0].MemberCount)
	}

	r.UpsertRoomEntry(DirectoryEntry{
		RoomID:         "room-a",
		ModeID:         "mode-1",
		MapID:          "map-1",
		MemberCount:    2,
		MaxPlayerCount: 4,
		Joinable:       true,
	})

	second := r.DirectorySnapshot()
	if second.Revision != 2 {
		t.Fatalf("expected revision 2 after update upsert, got %d", second.Revision)
	}
	if len(second.Entries) != 1 {
		t.Fatalf("expected 1 directory entry after update upsert, got %d", len(second.Entries))
	}
	if second.Entries[0].MemberCount != 2 {
		t.Fatalf("expected updated member count 2, got %d", second.Entries[0].MemberCount)
	}
}

func TestRegistryRemoveRoomEntryDeletesAndBumpsRevision(t *testing.T) {
	r := New("instance-a", "shard-a")
	r.UpsertRoomEntry(DirectoryEntry{RoomID: "room-a"})
	r.UpsertRoomEntry(DirectoryEntry{RoomID: "room-b"})

	beforeRemove := r.DirectorySnapshot()
	if beforeRemove.Revision != 2 {
		t.Fatalf("expected revision 2 before remove, got %d", beforeRemove.Revision)
	}

	r.RemoveRoomEntry("room-a")

	afterRemove := r.DirectorySnapshot()
	if afterRemove.Revision != 3 {
		t.Fatalf("expected revision 3 after remove, got %d", afterRemove.Revision)
	}
	if len(afterRemove.Entries) != 1 {
		t.Fatalf("expected 1 entry after remove, got %d", len(afterRemove.Entries))
	}
	if afterRemove.Entries[0].RoomID != "room-b" {
		t.Fatalf("expected remaining room to be room-b, got %s", afterRemove.Entries[0].RoomID)
	}
}

func TestRegistryDirectorySnapshotSortedByRoomID(t *testing.T) {
	r := New("instance-a", "shard-a")
	r.UpsertRoomEntry(DirectoryEntry{RoomID: "room-c"})
	r.UpsertRoomEntry(DirectoryEntry{RoomID: "room-a"})
	r.UpsertRoomEntry(DirectoryEntry{RoomID: "room-b"})

	snapshot := r.DirectorySnapshot()
	if len(snapshot.Entries) != 3 {
		t.Fatalf("expected 3 entries, got %d", len(snapshot.Entries))
	}

	expected := []string{"room-a", "room-b", "room-c"}
	for i, roomID := range expected {
		if snapshot.Entries[i].RoomID != roomID {
			t.Fatalf("expected sorted room id %s at index %d, got %s", roomID, i, snapshot.Entries[i].RoomID)
		}
	}
}

func TestRegistryDirectorySubscribersSetAndGet(t *testing.T) {
	r := New("instance-a", "shard-a")
	r.SetDirectorySubscribed("conn-b", true)
	r.SetDirectorySubscribed("conn-a", true)

	ids := r.DirectorySubscriberIDs()
	if len(ids) != 2 {
		t.Fatalf("expected 2 subscribers, got %d", len(ids))
	}
	if ids[0] != "conn-a" || ids[1] != "conn-b" {
		t.Fatalf("expected sorted subscribers [conn-a conn-b], got %v", ids)
	}

	r.SetDirectorySubscribed("conn-b", false)
	ids = r.DirectorySubscriberIDs()
	if len(ids) != 1 || ids[0] != "conn-a" {
		t.Fatalf("expected subscribers [conn-a] after unsubscribe, got %v", ids)
	}
}

func TestRegistryReadyAfterClose(t *testing.T) {
	r := New("instance-a", "shard-a")
	if !r.Ready() {
		t.Fatalf("expected registry to be ready before close")
	}

	r.Close()
	if r.Ready() {
		t.Fatalf("expected registry to be not ready after close")
	}
}
