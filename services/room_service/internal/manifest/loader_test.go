package manifest

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadFromFile_Success(t *testing.T) {
	path := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [
			{
				"map_id": "map_arcade",
				"display_name": "Arcade",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": ["2v2"],
				"required_team_count": 2,
				"max_player_count": 4,
				"custom_room_enabled": true,
				"casual_enabled": true,
				"ranked_enabled": false
			}
		],
		"modes": [],
		"rules": [],
		"match_formats": [],
		"assets": {
			"default_character_id": "char_default",
			"default_bubble_style_id": "bubble_default",
			"legal_character_ids": ["char_default"],
			"legal_character_skin_ids": ["skin_1"],
			"legal_bubble_style_ids": ["bubble_default"],
			"legal_bubble_skin_ids": ["bubble_skin_1"]
		}
	}`
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("write manifest: %v", err)
	}

	loader, err := LoadFromFile(path)
	if err != nil {
		t.Fatalf("load manifest: %v", err)
	}
	if !loader.Ready() {
		t.Fatalf("loader should be ready")
	}
	if loader.Path() != path {
		t.Fatalf("unexpected loader path: %s", loader.Path())
	}
	if loader.FindMap("map_arcade") == nil {
		t.Fatalf("map_arcade should exist")
	}
	if loader.FirstMap() == nil || loader.FirstMap().MapID != "map_arcade" {
		t.Fatalf("first map should be map_arcade")
	}
}

func TestLoadFromFile_InvalidSchemaVersion(t *testing.T) {
	path := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{"schema_version":0}`
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("write manifest: %v", err)
	}

	if _, err := LoadFromFile(path); err == nil {
		t.Fatalf("expected invalid schema_version error")
	}
}
