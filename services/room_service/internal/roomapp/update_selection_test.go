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

func TestUpdateSelectionRejectsNonOwner(t *testing.T) {
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
	joinerID := ""
	for _, member := range joined.Members {
		if member.MemberID != created.OwnerMemberID {
			joinerID = member.MemberID
			break
		}
	}

	_, err = svc.UpdateSelection(UpdateSelectionInput{
		RoomID:    created.RoomID,
		MemberID:  joinerID,
		Selection: Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
	})
	if err != ErrNotRoomOwner {
		t.Fatalf("expected ErrNotRoomOwner, got %v", err)
	}
}

func TestUpdateSelectionRejectsNonIdleRoomPhase(t *testing.T) {
	svc := newTestServiceWithFakeGame(t, nil)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "private_room",
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
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}
	if _, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("start manual room battle failed: %v", err)
	}

	_, err = svc.UpdateSelection(UpdateSelectionInput{
		RoomID:    created.RoomID,
		MemberID:  created.OwnerMemberID,
		Selection: Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
	})
	if err != ErrRoomPhaseInvalid {
		t.Fatalf("expected ErrRoomPhaseInvalid, got %v", err)
	}
}
