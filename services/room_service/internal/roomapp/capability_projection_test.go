package roomapp

import (
	"os"
	"path/filepath"
	"testing"

	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/manifest"
)

func newCapabilityTestQuery(t *testing.T) *manifest.Query {
	t.Helper()
	manifestPath := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [
			{
				"map_id": "map_duel",
				"display_name": "Duel",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": ["1v1"],
				"required_team_count": 2,
				"max_player_count": 2,
				"custom_room_enabled": true,
				"casual_enabled": true,
				"ranked_enabled": false
			},
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
			"legal_character_skin_ids": [],
			"legal_bubble_style_ids": ["bubble_default"],
			"legal_bubble_skin_ids": []
		}
	}`
	if err := os.WriteFile(manifestPath, []byte(content), 0o600); err != nil {
		t.Fatalf("write manifest: %v", err)
	}
	loader, err := manifest.LoadFromFile(manifestPath)
	if err != nil {
		t.Fatalf("load manifest: %v", err)
	}
	return manifest.NewQuery(loader)
}

func TestRebuildRoomCapabilities_IdleMatchRoomReadyMembers(t *testing.T) {
	query := newCapabilityTestQuery(t)
	room := &domain.RoomAggregate{
		RoomKind: "casual_match_room",
		Selection: domain.RoomSelection{
			MatchFormatID:   "2v2",
			SelectedModeIDs: []string{"mode_classic"},
		},
		RoomState: domain.RoomFSMState{
			Phase: RoomPhaseIdle,
		},
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseReady, Ready: true},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseReady, Ready: true},
		},
	}

	rebuildRoomCapabilities(room, "owner", query)

	if !room.Capabilities.CanToggleReady {
		t.Fatalf("expected can_toggle_ready in idle")
	}
	if !room.Capabilities.CanEnterQueue {
		t.Fatalf("expected can_enter_queue in idle when all members ready")
	}
	if room.Capabilities.CanCancelQueue {
		t.Fatalf("expected can_cancel_queue false in idle")
	}
	if !room.Capabilities.CanUpdateMatchRoomConfig {
		t.Fatalf("expected can_update_match_room_config for owner in match room idle")
	}
}

func TestRebuildRoomCapabilities_IdleDuelRoomAllowsSoloQueue(t *testing.T) {
	query := newCapabilityTestQuery(t)
	room := &domain.RoomAggregate{
		RoomKind: "casual_match_room",
		Selection: domain.RoomSelection{
			MatchFormatID:   "1v1",
			SelectedModeIDs: []string{"mode_classic"},
		},
		RoomState: domain.RoomFSMState{
			Phase: RoomPhaseIdle,
		},
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseReady, Ready: true},
		},
	}

	rebuildRoomCapabilities(room, "owner", query)

	if !room.Capabilities.CanEnterQueue {
		t.Fatalf("expected can_enter_queue for solo ready 1v1 room")
	}
}

func TestRebuildRoomCapabilities_QueueAndBattlePhases(t *testing.T) {
	query := newCapabilityTestQuery(t)
	room := &domain.RoomAggregate{
		RoomKind: "casual_match_room",
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseQueueLocked, Ready: true},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseQueueLocked, Ready: true},
		},
	}

	room.RoomState.Phase = RoomPhaseQueueActive
	rebuildRoomCapabilities(room, "owner", query)
	if room.Capabilities.CanToggleReady {
		t.Fatalf("expected can_toggle_ready false in queue_active")
	}
	if room.Capabilities.CanEnterQueue {
		t.Fatalf("expected can_enter_queue false in queue_active")
	}
	if !room.Capabilities.CanCancelQueue {
		t.Fatalf("expected can_cancel_queue true in queue_active")
	}

	room.RoomState.Phase = RoomPhaseBattleEntryReady
	rebuildRoomCapabilities(room, "owner", query)
	if !room.Capabilities.CanCancelQueue {
		t.Fatalf("expected can_cancel_queue true in battle_entry_ready")
	}
}

func TestRebuildRoomCapabilities_ManualRoomRules(t *testing.T) {
	room := &domain.RoomAggregate{
		RoomKind: "private_room",
		Selection: domain.RoomSelection{
			MapID:     "map_classic_square",
			RuleSetID: "ruleset_classic",
			ModeID:    "mode_classic",
		},
		RoomState: domain.RoomFSMState{
			Phase: RoomPhaseIdle,
		},
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseReady, Ready: true},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseReady, Ready: true},
		},
	}

	rebuildRoomCapabilities(room, "owner", nil)

	if !room.Capabilities.CanStartManualBattle {
		t.Fatalf("expected can_start_manual_battle true for manual room idle all-ready")
	}
	if room.Capabilities.CanEnterQueue {
		t.Fatalf("expected can_enter_queue false for manual room")
	}
	if !room.Capabilities.CanUpdateSelection {
		t.Fatalf("expected can_update_selection true for owner in manual room idle")
	}
}
