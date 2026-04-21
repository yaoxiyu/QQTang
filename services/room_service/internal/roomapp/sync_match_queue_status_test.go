package roomapp

import (
	"testing"

	gamev1 "qqtang/services/room_service/internal/gen/qqt/gamev1shim"
)

func TestSyncMatchQueueStatus_BattleReadyUpdatesSnapshot(t *testing.T) {
	fake := &fakeGameControlServer{
		enterResp: &gamev1.EnterPartyQueueResponse{
			Ok:           true,
			QueueEntryId: "queue-1",
			QueueState:   "queueing",
		},
		statusResp: &gamev1.GetPartyQueueStatusResponse{
			Ok:           true,
			QueueState:   "battle_ready",
			AssignmentId: "assign-1",
			MatchId:      "match-1",
			BattleId:     "battle-1",
			ServerHost:   "127.0.0.1",
			ServerPort:   19010,
		},
	}
	svc := newTestServiceWithFakeGame(t, fake)
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
		t.Fatalf("toggle owner ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guestMemberID}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	if _, err := svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("enter queue failed: %v", err)
	}

	updates := svc.SyncMatchQueueStatus()
	if len(updates) != 1 {
		t.Fatalf("expected one sync update, got %d", len(updates))
	}
	snapshot := updates[0].Snapshot
	if snapshot == nil {
		t.Fatalf("expected snapshot in sync update")
	}
	if snapshot.QueueState.QueueState != "battle_ready" {
		t.Fatalf("expected battle_ready queue state, got %s", snapshot.QueueState.QueueState)
	}
	if snapshot.BattleHandoff.AssignmentID != "assign-1" {
		t.Fatalf("expected assignment assign-1, got %s", snapshot.BattleHandoff.AssignmentID)
	}
	if snapshot.BattleHandoff.BattleID != "battle-1" {
		t.Fatalf("expected battle battle-1, got %s", snapshot.BattleHandoff.BattleID)
	}
	if snapshot.BattleHandoff.ServerPort != 19010 {
		t.Fatalf("expected server port 19010, got %d", snapshot.BattleHandoff.ServerPort)
	}
	if !snapshot.BattleHandoff.Ready {
		t.Fatalf("expected battle handoff ready")
	}
	if snapshot.LifecycleState != "battle_handoff" {
		t.Fatalf("expected lifecycle battle_handoff, got %s", snapshot.LifecycleState)
	}
}

func TestSyncMatchQueueStatus_MatchedStateTerminalClearsBattleHandoff(t *testing.T) {
	fake := &fakeGameControlServer{
		enterResp: &gamev1.EnterPartyQueueResponse{
			Ok:           true,
			QueueEntryId: "queue-1",
			QueueState:   "queueing",
		},
		statusResp: &gamev1.GetPartyQueueStatusResponse{
			Ok:          false,
			ErrorCode:   "GET_PARTY_QUEUE_STATUS_FAILED",
			UserMessage: "assignment expired",
		},
	}
	svc := newTestServiceWithFakeGame(t, fake)
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
		t.Fatalf("toggle owner ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guestMemberID}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	if _, err := svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("enter queue failed: %v", err)
	}

	svc.mu.Lock()
	room := svc.roomsByID[created.RoomID]
	room.Queue.QueueState = "matched"
	room.Queue.StatusText = "battle_entry_acknowledged"
	room.LifecycleState = "battle_entry_acknowledged"
	room.BattleHandoffState.AssignmentID = "assign-stale"
	room.BattleHandoffState.MatchID = "match-stale"
	room.BattleHandoffState.BattleID = "battle-stale"
	room.BattleHandoffState.ServerHost = "127.0.0.1"
	room.BattleHandoffState.ServerPort = 19010
	room.BattleHandoffState.Ready = true
	room.BattleHandoffState.AllocationState = "battle_ready"
	svc.mu.Unlock()

	updates := svc.SyncMatchQueueStatus()
	if len(updates) != 1 {
		t.Fatalf("expected one sync update, got %d", len(updates))
	}
	snapshot := updates[0].Snapshot
	if snapshot == nil {
		t.Fatalf("expected snapshot in sync update")
	}
	if snapshot.QueueState.QueueState != "failed" {
		t.Fatalf("expected failed queue state, got %s", snapshot.QueueState.QueueState)
	}
	if snapshot.LifecycleState != "idle" {
		t.Fatalf("expected lifecycle idle, got %s", snapshot.LifecycleState)
	}
	if snapshot.BattleHandoff.AssignmentID != "" || snapshot.BattleHandoff.BattleID != "" || snapshot.BattleHandoff.MatchID != "" {
		t.Fatalf("expected battle handoff ids cleared, got %+v", snapshot.BattleHandoff)
	}
	if snapshot.BattleHandoff.ServerHost != "" || snapshot.BattleHandoff.ServerPort != 0 {
		t.Fatalf("expected battle endpoint cleared, got %s:%d", snapshot.BattleHandoff.ServerHost, snapshot.BattleHandoff.ServerPort)
	}
	if snapshot.BattleHandoff.Ready {
		t.Fatalf("expected battle handoff ready cleared")
	}
}
