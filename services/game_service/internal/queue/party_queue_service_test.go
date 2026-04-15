package queue

import (
	"reflect"
	"testing"

	"qqtang/services/game_service/internal/storage"
)

func TestPartyQueueInputDoesNotConsumeSelectedMapIDs(t *testing.T) {
	inputType := reflect.TypeOf(EnterPartyQueueInput{})
	if _, ok := inputType.FieldByName("SelectedMapIDs"); ok {
		t.Fatalf("EnterPartyQueueInput must not accept selected map ids")
	}
	if key := BuildPartyQueueKey("ranked", "2v2"); key != "ranked:2v2" {
		t.Fatalf("unexpected party queue key: %s", key)
	}
}

func TestSelectCompatiblePartiesRequiresModeIntersection(t *testing.T) {
	entries := []storage.PartyQueueEntry{
		{
			PartyQueueEntryID: "party_a",
			PartySize:         2,
			SelectedModeIDs:   []string{"mode_classic"},
		},
		{
			PartyQueueEntryID: "party_b",
			PartySize:         2,
			SelectedModeIDs:   []string{"mode_score_team"},
		},
		{
			PartyQueueEntryID: "party_c",
			PartySize:         2,
			SelectedModeIDs:   []string{"mode_classic"},
		},
	}
	selected := selectCompatibleParties(entries, 2)
	if len(selected) != 2 {
		t.Fatalf("expected two compatible parties, got %d", len(selected))
	}
	if selected[0].PartyQueueEntryID != "party_a" || selected[1].PartyQueueEntryID != "party_c" {
		t.Fatalf("unexpected compatible party pair: %#v", selected)
	}
}
