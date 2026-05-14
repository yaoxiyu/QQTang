package roomapp

import "testing"

func TestUpdateSelection(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   mustIssueCreateRoomTicket(t, "custom_room", "acc-owner", "pro-owner"),
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
		RoomTicket:   mustIssueCreateRoomTicket(t, "custom_room", "acc-owner", "pro-owner"),
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
		RoomTicket:   mustIssueJoinRoomTicket(t, created.RoomID, "acc-joiner", "pro-joiner"),
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

func TestUpdateSelectionUpdatesOpenSlots(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   mustIssueCreateRoomTicket(t, "custom_room", "acc-owner", "pro-owner"),
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
		RoomTicket:   mustIssueJoinRoomTicket(t, created.RoomID, "acc-joiner", "pro-joiner"),
		AccountID:    "acc-joiner",
		ProfileID:    "pro-joiner",
		PlayerName:   "joiner",
		ConnectionID: "conn-joiner",
		Loadout:      Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"},
	})
	if err != nil {
		t.Fatalf("join room failed: %v", err)
	}
	snapshot, err := svc.UpdateSelection(UpdateSelectionInput{
		RoomID:          created.RoomID,
		MemberID:        created.OwnerMemberID,
		Selection:       Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
		OpenSlotIndices: []int{0, 1, 3},
	})
	if err != nil {
		t.Fatalf("update open slots failed: %v", err)
	}
	if len(snapshot.OpenSlotIndices) != 3 || snapshot.OpenSlotIndices[2] != 3 {
		t.Fatalf("expected open slots [0 1 3], got %+v", snapshot.OpenSlotIndices)
	}
	shrunk, err := svc.UpdateSelection(UpdateSelectionInput{
		RoomID:          created.RoomID,
		MemberID:        created.OwnerMemberID,
		Selection:       Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
		OpenSlotIndices: []int{0, 1},
	})
	if err != nil {
		t.Fatalf("expected occupied two-player room to shrink to two slots, got %v", err)
	}
	if len(shrunk.OpenSlotIndices) != 2 || shrunk.OpenSlotIndices[0] != 0 || shrunk.OpenSlotIndices[1] != 1 {
		t.Fatalf("expected open slots [0 1], got %+v", shrunk.OpenSlotIndices)
	}
	preserved, err := svc.UpdateSelection(UpdateSelectionInput{
		RoomID:          created.RoomID,
		MemberID:        created.OwnerMemberID,
		Selection:       Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
		OpenSlotIndices: []int{0},
	})
	if err != nil {
		t.Fatalf("expected occupied slots to be preserved, got %v", err)
	}
	if len(preserved.OpenSlotIndices) != 2 || preserved.OpenSlotIndices[0] != 0 || preserved.OpenSlotIndices[1] != 1 {
		t.Fatalf("expected occupied slots [0 1] to be preserved, got %+v", preserved.OpenSlotIndices)
	}
	if _, err := svc.UpdateSelection(UpdateSelectionInput{
		RoomID:          created.RoomID,
		MemberID:        created.OwnerMemberID,
		Selection:       Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
		OpenSlotIndices: []int{0, 4},
	}); err != ErrInvalidSelection {
		t.Fatalf("expected ErrInvalidSelection for out-of-range slot, got %v", err)
	}
	if len(joined.OpenSlotIndices) == 0 {
		t.Fatalf("expected join snapshot to include open slots")
	}
}

func TestUpdateSelectionRejectsNonIdleRoomPhase(t *testing.T) {
	svc := newTestServiceWithFakeGame(t, nil)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "private_room",
		RoomTicket:   mustIssueCreateRoomTicket(t, "private_room", "acc-owner", "pro-owner"),
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
	guest := joinReadyManualBattleGuest(t, svc, created.RoomID)
	if _, err := svc.UpdateProfile(UpdateProfileInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID, TeamID: 1, Loadout: Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"}}); err != nil {
		t.Fatalf("update owner team failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guest}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
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
