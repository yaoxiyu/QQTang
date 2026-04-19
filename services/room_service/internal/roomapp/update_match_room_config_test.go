package roomapp

import "testing"

func TestUpdateMatchRoomConfig(t *testing.T) {
	svc := newTestService(t)
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
	ownerID := created.OwnerMemberID

	updated, err := svc.UpdateMatchRoomConfig(UpdateMatchRoomConfigInput{
		RoomID:          created.RoomID,
		MemberID:        ownerID,
		MatchFormatID:   "2v2",
		SelectedModeIDs: []string{"mode_classic"},
	})
	if err != nil {
		t.Fatalf("update match room config failed: %v", err)
	}
	if updated.Selection.MatchFormatID != "2v2" {
		t.Fatalf("expected match_format_id=2v2, got %s", updated.Selection.MatchFormatID)
	}
	if len(updated.Selection.SelectedModeIDs) != 1 || updated.Selection.SelectedModeIDs[0] != "mode_classic" {
		t.Fatalf("selected_mode_ids not applied: %#v", updated.Selection.SelectedModeIDs)
	}
}
