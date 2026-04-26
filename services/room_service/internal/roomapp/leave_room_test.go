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

func TestLeaveRoomTransfersOwnerToLowestOccupiedSlot(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	joined, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   "ticket-join",
		AccountID:    "acc-joiner",
		ProfileID:    "pro-joiner",
		PlayerName:   "joiner",
		ConnectionID: "conn-joiner",
		Loadout:      Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"},
	})
	if err != nil {
		t.Fatalf("join room failed: %v", err)
	}
	nextOwnerID := ""
	for _, member := range joined.Members {
		if member.MemberID != created.OwnerMemberID {
			nextOwnerID = member.MemberID
			break
		}
	}
	if nextOwnerID == "" {
		t.Fatalf("expected joined member")
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: nextOwnerID}); err != nil {
		t.Fatalf("toggle joiner ready failed: %v", err)
	}

	snapshot, err := svc.LeaveRoom(LeaveRoomInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("owner leave failed: %v", err)
	}
	if snapshot == nil {
		t.Fatalf("expected remaining room snapshot")
	}
	if snapshot.OwnerMemberID != nextOwnerID {
		t.Fatalf("expected owner transfer to %s, got %s", nextOwnerID, snapshot.OwnerMemberID)
	}
	if !snapshot.Capabilities.CanUpdateSelection {
		t.Fatalf("expected transferred owner to edit custom room selection")
	}
	if snapshot.Capabilities.CanStartManualBattle {
		t.Fatalf("expected single remaining member cannot start")
	}
}
