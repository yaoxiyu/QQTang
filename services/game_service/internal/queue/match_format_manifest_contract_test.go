package queue

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"qqtang/services/game_service/internal/storage"
	"qqtang/services/shared/contentmanifest"
)

func TestNormalizeMatchFormatIDUsesManifestDefault(t *testing.T) {
	manifestPath := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [],
		"modes": [],
		"rules": [],
		"match_formats": [
			{
				"match_format_id": "1v1",
				"required_party_size": 1,
				"expected_total_player_count": 2,
				"legal_mode_ids": ["mode_classic"],
				"map_pool_resolution_policy": "union_by_selected_modes"
			},
			{
				"match_format_id": "2v2",
				"required_party_size": 2,
				"expected_total_player_count": 4,
				"legal_mode_ids": ["mode_classic"],
				"map_pool_resolution_policy": "union_by_selected_modes"
			}
		],
		"assets": {
			"default_character_id": "char_default",
			"default_bubble_style_id": "bubble_default",
			"legal_character_ids": ["char_default"],
			"legal_character_skin_ids": [],
			"legal_bubble_style_ids": ["bubble_default"],
			"legal_bubble_skin_ids": []
		}
	}`
	if err := os.WriteFile(manifestPath, []byte(content), 0o600); err != nil {
		t.Fatalf("write manifest: %v", err)
	}
	loader, err := contentmanifest.LoadFromFile(manifestPath)
	if err != nil {
		t.Fatalf("load manifest: %v", err)
	}
	ConfigureContentManifestQuery(contentmanifest.NewQuery(loader))
	t.Cleanup(func() { ConfigureContentManifestQuery(nil) })

	if got := normalizeMatchFormatID(""); got != "1v1" {
		t.Fatalf("expected default match format 1v1, got %s", got)
	}
}

func TestEnterPartyQueuePartySizeComesFromManifest(t *testing.T) {
	manifestPath := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [],
		"modes": [],
		"rules": [],
		"match_formats": [
			{
				"match_format_id": "1v1",
				"required_party_size": 1,
				"expected_total_player_count": 2,
				"legal_mode_ids": ["mode_classic"],
				"map_pool_resolution_policy": "union_by_selected_modes"
			}
		],
		"assets": {
			"default_character_id": "char_default",
			"default_bubble_style_id": "bubble_default",
			"legal_character_ids": ["char_default"],
			"legal_character_skin_ids": [],
			"legal_bubble_style_ids": ["bubble_default"],
			"legal_bubble_skin_ids": []
		}
	}`
	if err := os.WriteFile(manifestPath, []byte(content), 0o600); err != nil {
		t.Fatalf("write manifest: %v", err)
	}
	loader, err := contentmanifest.LoadFromFile(manifestPath)
	if err != nil {
		t.Fatalf("load manifest: %v", err)
	}

	db := newFakeQueueDB()
	service := NewService(storage.NewQueueRepository(db), storage.NewAssignmentRepository(db), nil, 30*time.Second)
	service.ConfigureContentManifest(loader)
	t.Cleanup(func() { service.ConfigureContentManifest(nil) })
	service.ConfigurePartyQueueRepositories(storage.NewPartyQueueRepository(db), storage.NewPartyQueueMemberRepository(db))

	_, err = service.EnterPartyQueue(t.Context(), EnterPartyQueueInput{
		PartyRoomID:     "room_1",
		QueueType:       "casual",
		MatchFormatID:   "",
		SelectedModeIDs: []string{"mode_classic"},
		Members: []PartyQueueMemberInput{
			{AccountID: "a1", ProfileID: "p1"},
			{AccountID: "a2", ProfileID: "p2"},
		},
	})
	if err != ErrPartySizeMismatch {
		t.Fatalf("expected ErrPartySizeMismatch from manifest-driven default 1v1, got %v", err)
	}
}
