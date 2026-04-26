package roomapp

import (
	"testing"

	gamev1 "qqtang/services/room_service/internal/gen/qqt/gamev1shim"
)

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
	guest := joinReadyManualBattleGuest(t, svc, created.RoomID)
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}
	if _, err := svc.UpdateProfile(UpdateProfileInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID, TeamID: 1, Loadout: Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"}}); err != nil {
		t.Fatalf("update owner team failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guest}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
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

func TestStartManualRoomBattleDoesNotRequireOwnerReady(t *testing.T) {
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
	guest := joinReadyManualBattleGuest(t, svc, created.RoomID)
	if _, err := svc.UpdateProfile(UpdateProfileInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID, TeamID: 1, Loadout: Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"}}); err != nil {
		t.Fatalf("update owner team failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guest}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}

	snapshot, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("start manual room battle without owner ready failed: %v", err)
	}
	if snapshot.BattleHandoff.AssignmentID == "" {
		t.Fatalf("expected battle assignment")
	}
}

func TestStartManualRoomBattleSendsMemberLoadoutToGameService(t *testing.T) {
	fakeGame := &fakeGameControlServer{}
	svc := newTestServiceWithFakeGame(t, fakeGame)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "private_room",
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout: Loadout{
			CharacterID:     "char_2",
			CharacterSkinID: "skin_1",
			BubbleStyleID:   "bubble_2",
			BubbleSkinID:    "bubble_skin_1",
		},
		Selection: Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic", MatchFormatID: "2v2"},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	guest := joinReadyManualBattleGuest(t, svc, created.RoomID)
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}
	if _, err := svc.UpdateProfile(UpdateProfileInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID, TeamID: 1, Loadout: Loadout{CharacterID: "char_2", CharacterSkinID: "skin_1", BubbleStyleID: "bubble_2", BubbleSkinID: "bubble_skin_1"}}); err != nil {
		t.Fatalf("update owner team failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guest}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	if _, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("start manual room battle failed: %v", err)
	}
	if fakeGame.lastCreateReq == nil || len(fakeGame.lastCreateReq.GetMembers()) != 2 {
		t.Fatalf("expected captured manual battle request with two members, got %+v", fakeGame.lastCreateReq)
	}
	member := fakeGame.lastCreateReq.GetMembers()[0]
	if member.GetCharacterId() != "char_2" || member.GetBubbleStyleId() != "bubble_2" {
		t.Fatalf("expected member loadout to propagate into manual battle request, got %+v", member)
	}
}

func TestManualRoomFinalizedSyncReturnsRoomToIdle(t *testing.T) {
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
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guest}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	started, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("start manual room battle failed: %v", err)
	}
	if _, err := svc.AckBattleEntry(AckBattleEntryInput{
		RoomID:       created.RoomID,
		MemberID:     created.OwnerMemberID,
		AssignmentID: started.BattleHandoff.AssignmentID,
		BattleID:     started.BattleHandoff.BattleID,
		MatchID:      started.BattleHandoff.MatchID,
	}); err != nil {
		t.Fatalf("owner ack failed: %v", err)
	}
	fakeGame.statusResp = &gamev1.GetPartyQueueStatusResponse{
		Ok:                  true,
		QueueState:          "finalized",
		QueuePhase:          QueuePhaseCompleted,
		QueueTerminalReason: QueueReasonMatchFinalized,
		QueueStatusText:     "Match finalized",
		AssignmentId:        started.BattleHandoff.AssignmentID,
		MatchId:             started.BattleHandoff.MatchID,
		BattleId:            started.BattleHandoff.BattleID,
	}

	updates := svc.SyncMatchQueueStatus()
	if len(updates) != 1 {
		t.Fatalf("expected finalized sync update, got %d", len(updates))
	}
	if updates[0].Snapshot.RoomPhase != RoomPhaseIdle {
		t.Fatalf("expected room phase idle, got %s", updates[0].Snapshot.RoomPhase)
	}
	if !updates[0].Snapshot.Capabilities.CanToggleReady {
		t.Fatalf("expected ready capability restored")
	}
}

func joinReadyManualBattleGuest(t *testing.T, svc *Service, roomID string) string {
	t.Helper()
	snapshot, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       roomID,
		RoomTicket:   "ticket-join",
		AccountID:    "acc-guest",
		ProfileID:    "pro-guest",
		PlayerName:   "guest",
		ConnectionID: "conn-guest",
		Loadout:      Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"},
	})
	if err != nil {
		t.Fatalf("join guest failed: %v", err)
	}
	guestID := ""
	for _, member := range snapshot.Members {
		if member.MemberID != snapshot.OwnerMemberID {
			guestID = member.MemberID
			break
		}
	}
	if guestID == "" {
		t.Fatalf("expected guest member id")
	}
	if _, err := svc.UpdateProfile(UpdateProfileInput{RoomID: roomID, MemberID: guestID, TeamID: 2, Loadout: Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"}}); err != nil {
		t.Fatalf("update guest team failed: %v", err)
	}
	return guestID
}
