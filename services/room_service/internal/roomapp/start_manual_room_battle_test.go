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

func TestDirectorySnapshotHidesManualRoomAfterBattleStart(t *testing.T) {
	fakeGame := &fakeGameControlServer{}
	svc := newTestServiceWithFakeGame(t, fakeGame)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "custom_room",
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
	if got := len(svc.DirectorySnapshot("127.0.0.1", 9100).GetEntries()); got != 1 {
		t.Fatalf("expected room visible before battle start, got %d entries", got)
	}
	guest := joinReadyManualBattleGuest(t, svc, created.RoomID)
	if _, err := svc.UpdateProfile(UpdateProfileInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID, TeamID: 1, Loadout: Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"}}); err != nil {
		t.Fatalf("update owner team failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle owner ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guest}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	if _, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("start manual room battle failed: %v", err)
	}
	if got := len(svc.DirectorySnapshot("127.0.0.1", 9100).GetEntries()); got != 0 {
		t.Fatalf("expected room hidden after battle start, got %d entries", got)
	}
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
	fakeGame.battleAssignResp = &gamev1.GetBattleAssignmentStatusResponse{
		Ok:                 true,
		BattlePhase:        "completed",
		TerminalReason:     QueueReasonMatchFinalized,
		StatusText:         "Match finalized",
		AssignmentId:       started.BattleHandoff.AssignmentID,
		AssignmentRevision: int64(started.BattleHandoff.AssignmentRevision),
		MatchId:            started.BattleHandoff.MatchID,
		BattleId:           started.BattleHandoff.BattleID,
		Finalized:          true,
	}

	updates := svc.SyncBattleAssignmentStatus()
	if len(updates) != 1 {
		t.Fatalf("expected finalized sync update, got %d", len(updates))
	}
	if updates[0].Snapshot.RoomPhase != RoomPhaseIdle {
		t.Fatalf("expected room phase idle, got %s", updates[0].Snapshot.RoomPhase)
	}
	if !updates[0].Snapshot.Capabilities.CanToggleReady {
		t.Fatalf("expected ready capability restored")
	}
	for _, member := range updates[0].Snapshot.Members {
		if member.MemberPhase != MemberPhaseIdle || member.Ready {
			t.Fatalf("expected member released to idle after finalized sync, got %+v", member)
		}
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guest}); err != nil {
		t.Fatalf("guest should be able to ready after finalized sync: %v", err)
	}
	restarted, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("owner should be able to restart after guest readies: %v", err)
	}
	if restarted.RoomPhase != RoomPhaseBattleEntryReady {
		t.Fatalf("expected restarted room phase battle_entry_ready, got %s", restarted.RoomPhase)
	}
	if fakeGame.lastBattleAssignReq == nil {
		t.Fatalf("expected battle assignment status request")
	}
	if fakeGame.lastBattleAssignReq.GetKnownRevision() != int64(started.BattleHandoff.AssignmentRevision) {
		t.Fatalf("expected known revision %d, got %d", started.BattleHandoff.AssignmentRevision, fakeGame.lastBattleAssignReq.GetKnownRevision())
	}
	metrics := svc.GetControlPlaneMetrics()
	if metrics["manual_battle_assignment_sync_count"] != 1 {
		t.Fatalf("expected one manual battle assignment sync, got metrics %+v", metrics)
	}
	if metrics["manual_battle_queue_status_call_count"] != 0 || metrics["queue_state_manual_room_write_count"] != 0 {
		t.Fatalf("manual battle queue metrics must stay zero, got %+v", metrics)
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

func TestManualRoomNotInQueueSyncTargets(t *testing.T) {
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
	guestID := joinReadyManualBattleGuest(t, svc, created.RoomID)
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle owner ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guestID}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}

	_, err = svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("start manual battle failed: %v", err)
	}

	targets := svc.collectQueueSyncTargets()
	if len(targets) != 0 {
		t.Fatalf("manual room must not appear in queue sync targets, got %d", len(targets))
	}

	battleTargets := svc.collectBattleSyncTargets()
	if len(battleTargets) != 1 {
		t.Fatalf("manual room must appear in battle sync targets, got %d", len(battleTargets))
	}
}

func TestManualRoomQueueStateCleanFullLifecycle(t *testing.T) {
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
	guestID := joinReadyManualBattleGuest(t, svc, created.RoomID)
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle owner ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guestID}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}

	// Phase 1: StartManualRoomBattle
	started, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("start manual battle failed: %v", err)
	}
	if started.QueueEntryID != "" {
		t.Fatalf("QueueEntryID must be empty after start, got %s", started.QueueEntryID)
	}

	// Phase 2: AckBattleEntry
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
	if acked.QueueEntryID != "" {
		t.Fatalf("QueueEntryID must be empty after ack, got %s", acked.QueueEntryID)
	}

	// Phase 3: collectQueueSyncTargets must skip manual rooms
	queueTargets := svc.collectQueueSyncTargets()
	if len(queueTargets) != 0 {
		t.Fatalf("queue sync targets must be empty for manual room, got %d", len(queueTargets))
	}

	// Phase 4: collectBattleSyncTargets must include manual rooms
	battleTargets := svc.collectBattleSyncTargets()
	if len(battleTargets) != 1 {
		t.Fatalf("battle sync targets must include manual room, got %d", len(battleTargets))
	}
}

func TestBattleAssignmentSyncDropsStaleRevision(t *testing.T) {
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
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	guestID := joinReadyManualBattleGuest(t, svc, created.RoomID)
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle owner ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guestID}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	started, err := svc.StartManualRoomBattle(StartManualRoomBattleInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("start manual battle failed: %v", err)
	}

	svc.mu.Lock()
	svc.roomsByID[created.RoomID].BattleState.AssignmentRevision = 3
	svc.mu.Unlock()
	fakeGame.battleAssignResp = &gamev1.GetBattleAssignmentStatusResponse{
		Ok:                 true,
		AssignmentId:       started.BattleHandoff.AssignmentID,
		AssignmentRevision: 2,
		BattlePhase:        "completed",
		Finalized:          true,
	}

	if updates := svc.SyncBattleAssignmentStatus(); len(updates) != 0 {
		t.Fatalf("expected stale revision sync to be dropped, got %d updates", len(updates))
	}
	metrics := svc.GetControlPlaneMetrics()
	if metrics["battle_assignment_revision_stale_drop_count"] != 1 {
		t.Fatalf("expected stale revision drop metric, got %+v", metrics)
	}
}
