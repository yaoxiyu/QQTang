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
		RoomTicket:   "ticket-create",
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
		RoomTicket:   "ticket-create",
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
		RoomTicket:   "ticket-join",
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
