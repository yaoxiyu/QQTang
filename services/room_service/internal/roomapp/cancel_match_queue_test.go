package roomapp

import "testing"

func TestCancelMatchQueueLifecycle(t *testing.T) {
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
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("toggle ready failed: %v", err)
	}
	if _, err := svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID}); err != nil {
		t.Fatalf("enter match queue failed: %v", err)
	}

	snapshot, err := svc.CancelMatchQueue(CancelMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("cancel match queue failed: %v", err)
	}
	if snapshot.QueueState.QueueState != "cancelled" {
		t.Fatalf("expected cancelled queue state, got %s", snapshot.QueueState.QueueState)
	}
	if snapshot.LifecycleState != "idle" {
		t.Fatalf("expected lifecycle idle, got %s", snapshot.LifecycleState)
	}
}
