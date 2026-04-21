package roomapp

import "testing"

func TestStartManualRoomBattleLifecycle(t *testing.T) {
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
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}

	snapshot, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("start manual room battle failed: %v", err)
	}
	if snapshot.BattleHandoff.AssignmentID == "" || snapshot.BattleHandoff.BattleID == "" {
		t.Fatalf("expected battle handoff ids, got %#v", snapshot.BattleHandoff)
	}
	if snapshot.LifecycleState != "battle_handoff" {
		t.Fatalf("expected battle_handoff lifecycle, got %s", snapshot.LifecycleState)
	}
	svc.mu.RLock()
	room := svc.roomsByID[created.RoomID]
	if room.RoomState.Phase != RoomPhaseBattleEntryReady {
		svc.mu.RUnlock()
		t.Fatalf("expected room phase battle_entry_ready, got %s", room.RoomState.Phase)
	}
	if room.BattleState.Phase != BattlePhaseReady {
		svc.mu.RUnlock()
		t.Fatalf("expected battle phase ready, got %s", room.BattleState.Phase)
	}
	if room.BattleState.TerminalReason != BattleReasonManualStart {
		svc.mu.RUnlock()
		t.Fatalf("expected battle reason manual_start, got %s", room.BattleState.TerminalReason)
	}
	for _, member := range room.Members {
		if member.MemberPhase != MemberPhaseQueueLocked {
			svc.mu.RUnlock()
			t.Fatalf("expected member phase queue_locked, got %s", member.MemberPhase)
		}
	}
	svc.mu.RUnlock()
}
