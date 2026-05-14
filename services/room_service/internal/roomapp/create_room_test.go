package roomapp

import "testing"

func TestCreateRoom(t *testing.T) {
	svc := newTestService(t)

	snapshot, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:        "private_room",
		RoomDisplayName: "Test Room",
		RoomTicket:      mustIssueCreateRoomTicket(t, "private_room", "acc-1", "pro-1"),
		AccountID:       "acc-1",
		ProfileID:       "pro-1",
		PlayerName:      "owner",
		ConnectionID:    "conn-1",
		Loadout: Loadout{
			CharacterID:   "char_default",
			BubbleStyleID: "bubble_default",
		},
		Selection: Selection{
			MapID:     "map_arcade",
			RuleSetID: "ruleset_classic",
			ModeID:    "mode_classic",
		},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	if snapshot == nil || snapshot.RoomID == "" {
		t.Fatalf("create room should return a room snapshot with room id")
	}
	if len(snapshot.Members) != 1 {
		t.Fatalf("expected 1 member after create, got %d", len(snapshot.Members))
	}
	if snapshot.Selection.MapID != "map_arcade" {
		t.Fatalf("expected map_arcade selection, got %s", snapshot.Selection.MapID)
	}
}
