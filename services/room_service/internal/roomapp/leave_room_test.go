package roomapp

import "testing"

func TestLeaveRoom(t *testing.T) {
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

	snapshot, err := svc.LeaveRoom(LeaveRoomInput{
		RoomID:   created.RoomID,
		MemberID: memberID,
	})
	if err != nil {
		t.Fatalf("leave room failed: %v", err)
	}
	if snapshot != nil {
		t.Fatalf("last member leave should remove room and return nil snapshot")
	}
	if _, err := svc.SnapshotProjection(created.RoomID); err == nil {
		t.Fatalf("room should not exist after last member leaves")
	}
}
