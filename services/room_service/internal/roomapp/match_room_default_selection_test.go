package roomapp

import "testing"

func TestCreateMatchRoomDefaultsToManifestMatchFormat(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "casual_match_room",
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{},
	})
	if err != nil {
		t.Fatalf("create match room failed: %v", err)
	}
	if created.Selection.MatchFormatID != "1v1" {
		t.Fatalf("expected default match_format_id=1v1, got %s", created.Selection.MatchFormatID)
	}
	if len(created.Selection.SelectedModeIDs) != 1 || created.Selection.SelectedModeIDs[0] != "mode_classic" {
		t.Fatalf("expected selected_mode_ids=[mode_classic], got %#v", created.Selection.SelectedModeIDs)
	}
	if created.Selection.MapID != "map_duel" {
		t.Fatalf("expected 1v1 default map from resolved pool, got %s", created.Selection.MapID)
	}
}
