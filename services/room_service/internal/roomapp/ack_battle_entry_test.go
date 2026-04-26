package roomapp

import "testing"

func TestAckBattleEntryLifecycle(t *testing.T) {
	fakeGame := &fakeGameControlServer{}
	svc := newTestServiceWithFakeGame(t, fakeGame)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "private_room",
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic", MatchFormatID: "2v2"},
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
	started, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("start manual room battle failed: %v", err)
	}

	acked, err := svc.AckBattleEntry(AckBattleEntryInput{
		RoomID:       created.RoomID,
		MemberID:     created.OwnerMemberID,
		AssignmentID: started.BattleHandoff.AssignmentID,
		BattleID:     started.BattleHandoff.BattleID,
		MatchID:      started.BattleHandoff.MatchID,
	})
	if err != nil {
		t.Fatalf("ack battle entry failed: %v", err)
	}
	if fakeGame.lastCommitReq == nil {
		t.Fatalf("expected commit assignment ready request")
	}
	if fakeGame.lastCommitReq.GetAccountId() != "acc-owner" || fakeGame.lastCommitReq.GetProfileId() != "pro-owner" {
		t.Fatalf("expected commit identity from room member, got %#v", fakeGame.lastCommitReq)
	}
	if fakeGame.lastCommitReq.GetAssignmentRevision() != 1 {
		t.Fatalf("expected commit assignment revision 1, got %d", fakeGame.lastCommitReq.GetAssignmentRevision())
	}
	if !acked.BattleHandoff.Ready {
		t.Fatalf("expected battle handoff ready true")
	}
	if acked.LifecycleState != "battle_entry_acknowledged" {
		t.Fatalf("expected lifecycle battle_entry_acknowledged, got %s", acked.LifecycleState)
	}
	svc.mu.RLock()
	room := svc.roomsByID[created.RoomID]
	if room.RoomState.Phase != RoomPhaseInBattle {
		svc.mu.RUnlock()
		t.Fatalf("expected room phase in_battle, got %s", room.RoomState.Phase)
	}
	if room.BattleState.Phase != BattlePhaseActive {
		svc.mu.RUnlock()
		t.Fatalf("expected battle phase active, got %s", room.BattleState.Phase)
	}
	if room.BattleState.TerminalReason != BattleReasonEntryAcknowledged {
		svc.mu.RUnlock()
		t.Fatalf("expected battle reason entry_acknowledged, got %s", room.BattleState.TerminalReason)
	}
	for _, member := range room.Members {
		if member.MemberPhase != MemberPhaseInBattle {
			svc.mu.RUnlock()
			t.Fatalf("expected member phase in_battle, got %s", member.MemberPhase)
		}
	}
	svc.mu.RUnlock()
}

func TestAckBattleEntryRejectsNonBattleEntryReadyPhase(t *testing.T) {
	svc := newTestServiceWithFakeGame(t, nil)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "private_room",
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic", MatchFormatID: "2v2"},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	_, err = svc.AckBattleEntry(AckBattleEntryInput{
		RoomID:       created.RoomID,
		MemberID:     created.OwnerMemberID,
		AssignmentID: "assign-x",
		BattleID:     "battle-x",
		MatchID:      "match-x",
	})
	if err != ErrRoomPhaseInvalid {
		t.Fatalf("expected ErrRoomPhaseInvalid, got %v", err)
	}
}
