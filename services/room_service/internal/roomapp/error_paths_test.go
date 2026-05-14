package roomapp

import (
	"errors"
	"testing"
)

func TestCreateRoom_InvalidTicket(t *testing.T) {
	svc := newTestService(t)
	_, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   "invalid",
		AccountID:    "acc-1",
		ProfileID:    "pro-1",
		PlayerName:   "owner",
		ConnectionID: "conn-1",
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
	if !errors.Is(err, ErrInvalidTicket) {
		t.Fatalf("expected ErrInvalidTicket, got %v", err)
	}
}

func TestCreateRoom_ForbiddenLoadout(t *testing.T) {
	svc := newTestService(t)
	_, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   mustIssueCreateRoomTicket(t, "custom_room", "acc-1", "pro-1"),
		AccountID:    "acc-1",
		ProfileID:    "pro-1",
		PlayerName:   "owner",
		ConnectionID: "conn-1",
		Loadout: Loadout{
			CharacterID:   "char_forbidden",
			BubbleStyleID: "bubble_default",
		},
		Selection: Selection{
			MapID:     "map_arcade",
			RuleSetID: "ruleset_classic",
			ModeID:    "mode_classic",
		},
	})
	if !errors.Is(err, ErrInvalidLoadout) {
		t.Fatalf("expected ErrInvalidLoadout, got %v", err)
	}
}

func TestCreateRoom_IllegalMatchModeSet(t *testing.T) {
	svc := newTestService(t)
	_, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "casual_match_room",
		RoomTicket:   mustIssueCreateRoomTicket(t, "casual_match_room", "acc-1", "pro-1"),
		AccountID:    "acc-1",
		ProfileID:    "pro-1",
		PlayerName:   "owner",
		ConnectionID: "conn-1",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic", MatchFormatID: "2v2", SelectedModeIDs: []string{"mode_illegal"}},
	})
	if !errors.Is(err, ErrInvalidSelection) {
		t.Fatalf("expected ErrInvalidSelection, got %v", err)
	}
}

func TestJoinRoom_StaleRoomID(t *testing.T) {
	svc := newTestService(t)
	_, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       "room-does-not-exist",
		RoomTicket:   mustIssueJoinRoomTicket(t, "room-does-not-exist", "acc-joiner", "pro-joiner"),
		AccountID:    "acc-joiner",
		ProfileID:    "pro-joiner",
		PlayerName:   "joiner",
		ConnectionID: "conn-joiner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
	})
	if !errors.Is(err, ErrRoomNotFound) {
		t.Fatalf("expected ErrRoomNotFound, got %v", err)
	}
}

func TestEnterMatchQueue_InvalidSelectedModes(t *testing.T) {
	svc := newTestServiceWithFakeGame(t, nil)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "casual_match_room",
		RoomTicket:   mustIssueCreateRoomTicket(t, "casual_match_room", "acc-owner", "pro-owner"),
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic", MatchFormatID: "2v2", SelectedModeIDs: []string{"mode_classic"}},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	if _, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   mustIssueJoinRoomTicket(t, created.RoomID, "acc-guest", "pro-guest"),
		AccountID:    "acc-guest",
		ProfileID:    "pro-guest",
		PlayerName:   "guest",
		ConnectionID: "conn-guest",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
	}); err != nil {
		t.Fatalf("join room failed: %v", err)
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

	svc.mu.Lock()
	room := svc.roomsByID[created.RoomID]
	room.Selection.SelectedModeIDs = []string{"mode_illegal"}
	svc.mu.Unlock()

	_, err = svc.EnterMatchQueue(EnterMatchQueueInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if !errors.Is(err, ErrInvalidSelection) {
		t.Fatalf("expected ErrInvalidSelection, got %v", err)
	}
}
