package roomapp

import "testing"

func TestEnterMatchQueueLifecycle(t *testing.T) {
	svc := newTestServiceWithFakeGame(t, nil)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "casual_match_room",
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic", MatchFormatID: "2v2", SelectedModeIDs: []string{"mode_classic"}},
	})
	if err != nil {
		t.Fatalf("create match room failed: %v", err)
	}
	_, err = svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   "ticket-join",
		AccountID:    "acc-guest",
		ProfileID:    "pro-guest",
		PlayerName:   "guest",
		ConnectionID: "conn-guest",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
	})
	if err != nil {
		t.Fatalf("join match room failed: %v", err)
	}
	_, guestMemberID, err := svc.ResolveRoomMemberByConnection("conn-guest")
	if err != nil {
		t.Fatalf("resolve guest member failed: %v", err)
	}

	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guestMemberID}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	snapshot, err := svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("enter match queue failed: %v", err)
	}
	if snapshot.QueueState.QueueState != "queueing" {
		t.Fatalf("expected queueing state, got %s", snapshot.QueueState.QueueState)
	}
	if snapshot.LifecycleState != "queueing" {
		t.Fatalf("expected lifecycle queueing, got %s", snapshot.LifecycleState)
	}
	svc.mu.RLock()
	room := svc.roomsByID[created.RoomID]
	if room.RoomState.Phase != RoomPhaseQueueActive {
		svc.mu.RUnlock()
		t.Fatalf("expected canonical room phase queue_active, got %s", room.RoomState.Phase)
	}
	for _, member := range room.Members {
		if member.MemberPhase != MemberPhaseQueueLocked {
			svc.mu.RUnlock()
			t.Fatalf("expected member phase queue_locked, got %s", member.MemberPhase)
		}
	}
	svc.mu.RUnlock()
}

func TestEnterMatchQueueRejectsNonIdleRoomPhase(t *testing.T) {
	svc := newTestServiceWithFakeGame(t, nil)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "casual_match_room",
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic", MatchFormatID: "2v2", SelectedModeIDs: []string{"mode_classic"}},
	})
	if err != nil {
		t.Fatalf("create match room failed: %v", err)
	}
	if _, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   "ticket-join",
		AccountID:    "acc-guest",
		ProfileID:    "pro-guest",
		PlayerName:   "guest",
		ConnectionID: "conn-guest",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
	}); err != nil {
		t.Fatalf("join match room failed: %v", err)
	}
	_, guestMemberID, err := svc.ResolveRoomMemberByConnection("conn-guest")
	if err != nil {
		t.Fatalf("resolve guest member failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guestMemberID}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	if _, err := svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("first enter match queue failed: %v", err)
	}

	_, err = svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != ErrRoomPhaseInvalid {
		t.Fatalf("expected ErrRoomPhaseInvalid, got %v", err)
	}
}

func TestEnterMatchQueueSendsMemberLoadoutToGameService(t *testing.T) {
	fakeGame := &fakeGameControlServer{}
	svc := newTestServiceWithFakeGame(t, fakeGame)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "casual_match_room",
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout: Loadout{
			CharacterID:     "char_default",
			BubbleStyleID:   "bubble_default",
		},
		Selection: Selection{MapID: "map_duel", RuleSetID: "ruleset_classic", ModeID: "mode_classic", MatchFormatID: "1v1", SelectedModeIDs: []string{"mode_classic"}},
	})
	if err != nil {
		t.Fatalf("create match room failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}
	if _, err := svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("enter match queue failed: %v", err)
	}
	if fakeGame.lastEnterReq == nil || len(fakeGame.lastEnterReq.GetMembers()) != 1 {
		t.Fatalf("expected captured enter request with one member, got %+v", fakeGame.lastEnterReq)
	}
	member := fakeGame.lastEnterReq.GetMembers()[0]
	if member.GetCharacterId() != "char_default" || member.GetCharacterSkinId() != "skin_1" {
		t.Fatalf("expected character loadout in enter request, got %+v", member)
	}
	if member.GetBubbleStyleId() != "bubble_default" || member.GetBubbleSkinId() != "bubble_skin_1" {
		t.Fatalf("expected bubble loadout in enter request, got %+v", member)
	}
}
