package roomapp

import "testing"

func TestToggleReady(t *testing.T) {
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

	snapshot1, err := svc.ToggleReady(ToggleReadyInput{
		RoomID:   created.RoomID,
		MemberID: memberID,
	})
	if err != nil {
		t.Fatalf("toggle ready #1 failed: %v", err)
	}
	if len(snapshot1.Members) != 1 || !snapshot1.Members[0].Ready {
		t.Fatalf("member should be ready after first toggle")
	}

	snapshot2, err := svc.ToggleReady(ToggleReadyInput{
		RoomID:   created.RoomID,
		MemberID: memberID,
	})
	if err != nil {
		t.Fatalf("toggle ready #2 failed: %v", err)
	}
	if len(snapshot2.Members) != 1 || snapshot2.Members[0].Ready {
		t.Fatalf("member should be not ready after second toggle")
	}
}

func TestToggleReadyRejectsNonIdleRoomPhase(t *testing.T) {
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
	memberID := created.OwnerMemberID
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: memberID}); err != nil {
		t.Fatalf("toggle ready initial failed: %v", err)
	}
	svc.mu.Lock()
	room := svc.roomsByID[created.RoomID]
	room.RoomState.Phase = RoomPhaseQueueActive
	svc.touchRoomSnapshotLocked(room)
	svc.mu.Unlock()

	_, err = svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: memberID})
	if err != ErrRoomPhaseInvalid {
		t.Fatalf("expected ErrRoomPhaseInvalid, got %v", err)
	}
}

func TestToggleReady_MatchRoomSoloReadyProjectsCanEnterQueue(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "casual_match_room",
		RoomTicket:   mustIssueCreateRoomTicket(t, "casual_match_room", "acc-owner", "pro-owner"),
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout: Loadout{
			CharacterID:   "char_default",
			BubbleStyleID: "bubble_default",
		},
		Selection: Selection{
			MatchFormatID:   "1v1",
			SelectedModeIDs: []string{"mode_classic"},
		},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}

	snapshot, err := svc.ToggleReady(ToggleReadyInput{
		RoomID:   created.RoomID,
		MemberID: created.OwnerMemberID,
	})
	if err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}
	if !snapshot.Capabilities.CanEnterQueue {
		t.Fatalf("expected can_enter_queue true for solo ready 1v1 room")
	}
}
