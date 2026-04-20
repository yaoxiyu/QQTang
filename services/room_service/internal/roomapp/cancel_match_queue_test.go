package roomapp

import (
	"testing"

	gamev1 "qqtang/services/room_service/internal/gen/qqt/gamev1shim"
)

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

func TestCancelMatchQueueAcceptsQueuedState(t *testing.T) {
	fake := &fakeGameControlServer{
		enterResp: &gamev1.EnterPartyQueueResponse{
			Ok:           true,
			QueueEntryId: "queue-queued",
			QueueState:   "queued",
		},
		cancelResp: &gamev1.CancelPartyQueueResponse{
			Ok:         true,
			QueueState: "cancelled",
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
		t.Fatalf("toggle ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: guestMemberID}); err != nil {
		t.Fatalf("toggle guest ready failed: %v", err)
	}
	snapshot, err := svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("enter match queue failed: %v", err)
	}
	if snapshot.QueueState.QueueState != "queued" {
		t.Fatalf("expected queued queue state, got %s", snapshot.QueueState.QueueState)
	}

	cancelled, err := svc.CancelMatchQueue(CancelMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("cancel match queue failed: %v", err)
	}
	if cancelled.QueueState.QueueState != "cancelled" {
		t.Fatalf("expected cancelled queue state, got %s", cancelled.QueueState.QueueState)
	}
}
