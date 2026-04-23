package contentmanifest

import (
	"os"
	"path/filepath"
	"testing"
)

func TestQueryUsesManifestDefaultsAndPartySizes(t *testing.T) {
	manifestPath := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [
			{
				"map_id": "map_ranked_duel",
				"display_name": "Ranked Duel",
				"mode_id": "mode_ranked",
				"rule_set_id": "rule_standard",
				"match_format_ids": ["1v1"],
				"required_team_count": 2,
				"max_player_count": 2,
				"custom_room_enabled": false,
				"casual_enabled": true,
				"ranked_enabled": true
			},
			{
				"map_id": "map_ranked_team",
				"display_name": "Ranked Team",
				"mode_id": "mode_ranked",
				"rule_set_id": "rule_standard",
				"match_format_ids": ["2v2"],
				"required_team_count": 2,
				"max_player_count": 4,
				"custom_room_enabled": true,
				"casual_enabled": true,
				"ranked_enabled": true
			}
		],
		"modes": [
			{
				"mode_id": "mode_ranked",
				"display_name": "Ranked",
				"match_format_ids": ["1v1", "2v2"],
				"selectable_in_match_room": true
			}
		],
		"rules": [
			{
				"rule_set_id": "rule_standard",
				"display_name": "Standard Rule"
			}
		],
		"match_formats": [
			{
				"match_format_id": "1v1",
				"required_party_size": 1,
				"expected_total_player_count": 2,
				"legal_mode_ids": ["mode_ranked"],
				"map_pool_resolution_policy": "union_by_selected_modes"
			},
			{
				"match_format_id": "2v2",
				"required_party_size": 2,
				"expected_total_player_count": 4,
				"legal_mode_ids": ["mode_ranked"],
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
	query := NewQuery(loader)

	if got := query.DefaultMatchFormatID(); got != "1v1" {
		t.Fatalf("expected default match format 1v1, got %s", got)
	}
	if got := query.RequiredPartySize(""); got != 1 {
		t.Fatalf("expected empty match format to resolve to party size 1, got %d", got)
	}
	if got := query.RequiredPartySize("2v2"); got != 2 {
		t.Fatalf("expected 2v2 party size 2, got %d", got)
	}

	pool, err := query.ResolveMapPool(query.ResolveMatchFormatID(""), []string{"mode_ranked"}, "ranked")
	if err != nil {
		t.Fatalf("ResolveMapPool returned error: %v", err)
	}
	if len(pool) != 1 || pool[0].MapID != "map_ranked_duel" {
		t.Fatalf("expected default 1v1 pool to resolve to duel map, got %#v", pool)
	}
}
