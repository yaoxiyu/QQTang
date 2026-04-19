package roomapp

import "testing"

func TestUpdateSelection(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
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
	memberID := created.Members[0].MemberID

	snapshot, err := svc.UpdateSelection(UpdateSelectionInput{
		RoomID:   created.RoomID,
		MemberID: memberID,
		Selection: Selection{
			MapID:     "map_arcade",
			RuleSetID: "ruleset_classic",
			ModeID:    "mode_classic",
		},
	})
	if err != nil {
		t.Fatalf("update selection failed: %v", err)
	}
	if snapshot.Selection.MapID != "map_arcade" || snapshot.Selection.ModeID != "mode_classic" {
		t.Fatalf("selection not updated as expected: %+v", snapshot.Selection)
	}
}
