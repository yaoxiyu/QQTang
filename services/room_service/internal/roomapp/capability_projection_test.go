package roomapp

import (
	"testing"

	"qqtang/services/room_service/internal/domain"
)

func TestRebuildRoomCapabilities_IdleMatchRoomReadyMembers(t *testing.T) {
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

	rebuildRoomCapabilities(room, "owner")

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

func TestRebuildRoomCapabilities_QueueAndBattlePhases(t *testing.T) {
	room := &domain.RoomAggregate{
		RoomKind: "casual_match_room",
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseQueueLocked, Ready: true},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseQueueLocked, Ready: true},
		},
	}

	room.RoomState.Phase = RoomPhaseQueueActive
	rebuildRoomCapabilities(room, "owner")
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
	rebuildRoomCapabilities(room, "owner")
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

	rebuildRoomCapabilities(room, "owner")

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
