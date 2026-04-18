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

func TestResolveAssignmentServerEndpointUsesAllocationState(t *testing.T) {
	assignment := storage.Assignment{
		ServerHost:       "127.0.0.1",
		ServerPort:       9000,
		BattleServerHost: "10.9.0.3",
		BattleServerPort: 9200,
	}

	assignment.AllocationState = "allocating"
	host, port := resolveAssignmentServerEndpoint(assignment)
	if host != "" || port != 0 {
		t.Fatalf("allocating state should hide endpoint, got %s:%d", host, port)
	}

	assignment.AllocationState = "alloc_failed"
	host, port = resolveAssignmentServerEndpoint(assignment)
	if host != "" || port != 0 {
		t.Fatalf("alloc_failed state should hide endpoint, got %s:%d", host, port)
	}

	assignment.AllocationState = "allocated"
	host, port = resolveAssignmentServerEndpoint(assignment)
	if host != "10.9.0.3" || port != 9200 {
		t.Fatalf("allocated state should expose battle endpoint, got %s:%d", host, port)
	}
}

func TestResolveAssignmentStatusTextUsesAllocationState(t *testing.T) {
	assignment := storage.Assignment{AllocationState: "allocating"}
	if got := resolveAssignmentStatusText(assignment, "default"); got != "Battle allocation in progress" {
		t.Fatalf("unexpected allocating status text: %s", got)
	}

	assignment.AllocationState = "alloc_failed"
	if got := resolveAssignmentStatusText(assignment, "default"); got != "Battle allocation failed" {
		t.Fatalf("unexpected alloc_failed status text: %s", got)
	}

	assignment.AllocationState = "allocated"
	if got := resolveAssignmentStatusText(assignment, "default"); got != "default" {
		t.Fatalf("allocated state should fallback to default text, got %s", got)
	}
}
