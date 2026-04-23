package roomapp

import (
	"os"
	"path/filepath"
	"testing"

	"qqtang/services/room_service/internal/auth"
	"qqtang/services/room_service/internal/manifest"
	"qqtang/services/room_service/internal/registry"
)

func TestCreateMatchRoomUsesManifestDefaultMatchFormat(t *testing.T) {
	manifestPath := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [
			{
				"map_id": "map_placeholder",
				"display_name": "Placeholder",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": [],
				"required_team_count": 2,
				"max_player_count": 2,
				"custom_room_enabled": false,
				"casual_enabled": true,
				"ranked_enabled": true
			},
			{
				"map_id": "map_ranked_duel",
				"display_name": "Ranked Duel",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": ["1v1"],
				"required_team_count": 2,
				"max_player_count": 2,
				"custom_room_enabled": false,
				"casual_enabled": true,
				"ranked_enabled": true
			}
		],
		"modes": [
			{
				"mode_id": "mode_classic",
				"display_name": "Classic",
				"match_format_ids": ["1v1"],
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
	loader, err := manifest.LoadFromFile(manifestPath)
	if err != nil {
		t.Fatalf("load manifest: %v", err)
	}
	service := NewService(
		registry.New("test-instance", "test-shard"),
		loader,
		auth.NewTicketVerifier("test-secret"),
		nil,
	)

	snapshot, err := service.CreateRoom(CreateRoomInput{
		RoomKind:        "casual_match_room",
		RoomDisplayName: "match-room",
		RoomTicket:      "test-secret",
		AccountID:       "acc_1",
		ProfileID:       "pro_1",
		PlayerName:      "p1",
		ConnectionID:    "conn_1",
		Loadout: Loadout{
			CharacterID:     "char_default",
			CharacterSkinID: "skin_1",
			BubbleStyleID:   "bubble_default",
			BubbleSkinID:    "bubble_skin_1",
		},
	})
	if err != nil {
		t.Fatalf("CreateRoom returned error: %v", err)
	}
	if snapshot.Selection.MatchFormatID != "1v1" {
		t.Fatalf("expected manifest default match format 1v1, got %s", snapshot.Selection.MatchFormatID)
	}
	if snapshot.Selection.MapID != "map_ranked_duel" {
		t.Fatalf("expected resolved map from manifest pool, got %s", snapshot.Selection.MapID)
	}
}
