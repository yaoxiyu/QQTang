package roomapp

import (
	"testing"

	gamev1 "qqtang/services/room_service/internal/gen/qqt/gamev1shim"
	"qqtang/services/room_service/internal/domain"
)

func TestRoomTransitionEngine_QueueProjectionDoesNotOverrideInBattlePhase(t *testing.T) {
	engine := RoomTransitionEngine{}
	room := domainRoomAggregateForBattleProjectionTest()
	engine.ApplyCreateRoom(room, "owner")
	engine.ApplyBattleHandoffUpdated(room, "owner", BattleHandoffUpdate{
		AssignmentID: "assign-1",
		MatchID:      "match-1",
		BattleID:     "battle-1",
		ServerHost:   "127.0.0.1",
		ServerPort:   19010,
		Phase:        BattlePhaseReady,
		Ready:        true,
	})
	engine.ApplyBattleStarted(room, "owner")

	engine.ApplyQueueProjection(room, "owner", QueueProjectionUpdate{
		QueuePhase:          QueuePhaseCompleted,
		QueueTerminalReason: QueueReasonMatchFinalized,
		QueueStatusText:     "stale_idle_snapshot",
		QueueEntryID:        "queue-1",
		BattlePhase:         BattlePhaseCompleted,
	})

	if room.RoomState.Phase != RoomPhaseInBattle {
		t.Fatalf("expected room phase to remain in_battle, got %s", room.RoomState.Phase)
	}
	if room.BattleState.Phase != BattlePhaseActive {
		t.Fatalf("expected battle phase to remain active, got %s", room.BattleState.Phase)
	}
}

func TestSyncMatchQueueStatus_DoesNotRegressInBattleRoomToIdle(t *testing.T) {
	fake := &fakeGameControlServer{
		enterResp: &gamev1.EnterPartyQueueResponse{
			Ok:                 true,
			QueueEntryId:       "queue-1",
			QueueState:         "queueing",
			QueuePhase:         QueuePhaseQueued,
			QueueStatusText:    "queueing",
			QueueTerminalReason: QueueReasonNone,
		},
		statusResp: &gamev1.GetPartyQueueStatusResponse{
			Ok:                   true,
			QueueState:           "battle_ready",
			QueuePhase:           QueuePhaseEntryReady,
			AssignmentId:         "assign-1",
			MatchId:              "match-1",
			BattleId:             "battle-1",
			ServerHost:           "127.0.0.1",
			ServerPort:           19010,
			BattleEntryReady:     true,
			AssignmentStatusText: "battle_ready",
		},
	}
	svc := newTestServiceWithFakeGame(t, fake)
	created, ownerID, guestID := createReadyMatchRoomForBattleProjectionTest(t, svc)

	if _, err := svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: ownerID}); err != nil {
		t.Fatalf("enter queue failed: %v", err)
	}
	updates := svc.SyncMatchQueueStatus()
	if len(updates) != 1 {
		t.Fatalf("expected one sync update, got %d", len(updates))
	}
	if _, err := svc.AckBattleEntry(AckBattleEntryInput{
		RoomID:       created.RoomID,
		MemberID:     ownerID,
		AssignmentID: "assign-1",
		BattleID:     "battle-1",
		MatchID:      "match-1",
	}); err != nil {
		t.Fatalf("ack battle entry failed: %v", err)
	}

	fake.statusResp = &gamev1.GetPartyQueueStatusResponse{
		Ok:                 true,
		QueueState:         "finalized",
		QueuePhase:         QueuePhaseCompleted,
		QueueTerminalReason: QueueReasonMatchFinalized,
		QueueStatusText:    "stale_idle_snapshot",
	}

	updates = svc.SyncMatchQueueStatus()
	if len(updates) != 0 {
		t.Fatalf("expected no queue sync update while room is in_battle, got %d", len(updates))
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
	if room.QueueState.Phase != QueuePhaseEntryReady {
		svc.mu.RUnlock()
		t.Fatalf("expected queue phase entry_ready to remain until explicit battle/return transition, got %s", room.QueueState.Phase)
	}
	_ = guestID
	svc.mu.RUnlock()
}

func createReadyMatchRoomForBattleProjectionTest(t *testing.T, svc *Service) (*SnapshotProjection, string, string) {
	t.Helper()

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
	_, guestID, err := svc.ResolveRoomMemberByConnection("conn-guest")
	if err != nil {
		t.Fatalf("resolve guest member failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle owner ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guestID}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	return created, created.OwnerMemberID, guestID
}

func domainRoomAggregateForBattleProjectionTest() *domain.RoomAggregate {
	return &domain.RoomAggregate{
		RoomKind: "casual_match_room",
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseReady, Ready: true},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseReady, Ready: true},
		},
		QueueState: domain.QueueFSMProjection{
			Phase:          QueuePhaseEntryReady,
			TerminalReason: QueueReasonNone,
			QueueEntryID:   "queue-1",
		},
		BattleState: domain.BattleHandoffFSMProjection{
			Phase:          BattlePhaseReady,
			TerminalReason: BattleReasonNone,
			AssignmentID:   "assign-1",
			BattleID:       "battle-1",
			MatchID:        "match-1",
			ServerHost:     "127.0.0.1",
			ServerPort:     19010,
			Ready:          true,
		},
	}
}
