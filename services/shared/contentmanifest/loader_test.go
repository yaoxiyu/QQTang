package contentmanifest

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadFromFileBuildsReadyLoader(t *testing.T) {
	manifestPath := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [
			{
				"map_id": "map_classic_square",
				"display_name": "Classic Square",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": ["1v1", "2v2"],
				"required_team_count": 2,
				"max_player_count": 2,
				"custom_room_enabled": true,
				"casual_enabled": true,
				"ranked_enabled": true
			}
		],
		"modes": [
			{
				"mode_id": "mode_classic",
				"display_name": "Classic",
				"match_format_ids": ["1v1", "2v2"],
				"selectable_in_match_room": true
			}
		],
		"rules": [
			{
				"rule_set_id": "ruleset_classic",
				"display_name": "Classic Rule"
			}
		],
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
			"legal_character_skin_ids": ["skin_1"],
			"legal_bubble_style_ids": ["bubble_default"],
			"legal_bubble_skin_ids": ["bubble_skin_1"]
		}
	}`
	if err := os.WriteFile(manifestPath, []byte(content), 0o600); err != nil {
		t.Fatalf("write manifest: %v", err)
	}

	loader, err := LoadFromFile(manifestPath)
	if err != nil {
		t.Fatalf("LoadFromFile returned error: %v", err)
	}
	if !loader.Ready() {
		t.Fatal("expected loader to be ready")
	}
	if loader.Path() != manifestPath {
		t.Fatalf("expected path %s, got %s", manifestPath, loader.Path())
	}

	firstMap := loader.FirstMap()
	if firstMap == nil || firstMap.MapID != "map_classic_square" {
		t.Fatalf("expected first map map_classic_square, got %#v", firstMap)
	}
	firstFormat := loader.FirstMatchFormat()
	if firstFormat == nil || firstFormat.MatchFormatID != "1v1" {
		t.Fatalf("expected first match format 1v1, got %#v", firstFormat)
	}
}
