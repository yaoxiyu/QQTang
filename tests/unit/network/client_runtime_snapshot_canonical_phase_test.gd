extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")


func test_room_snapshot_from_dict_maps_canonical_phase_and_capability_fields() -> void:
	var snapshot := RoomSnapshotScript.from_dict({
		"room_id": "ROOM_CANONICAL",
		"room_kind": "ranked_match_room",
		"room_phase": "battle_entry_ready",
		"room_phase_reason": "manual_battle_started",
		"queue_phase": "entry_ready",
		"queue_terminal_reason": "none",
		"battle_phase": "ready",
		"battle_terminal_reason": "manual_start",
		"battle_status_text": "Battle ready",
		"can_toggle_ready": false,
		"can_start_manual_battle": false,
		"can_update_selection": false,
		"can_update_match_room_config": true,
		"can_enter_queue": false,
		"can_cancel_queue": true,
		"can_leave_room": true,
		"members": [
			{
				"peer_id": 1,
				"player_name": "owner",
				"member_phase": "queue_locked",
			},
		],
	})

	assert_eq(snapshot.room_phase, "battle_entry_ready", "room_phase should map from canonical field")
	assert_eq(snapshot.room_phase_reason, "manual_battle_started", "room_phase_reason should map from canonical field")
	assert_eq(snapshot.queue_phase, "entry_ready", "queue_phase should map from canonical field")
	assert_eq(snapshot.battle_phase, "ready", "battle_phase should map from canonical field")
	assert_true(snapshot.can_cancel_queue, "canonical capability should map")
	assert_eq(snapshot.members.size(), 1, "member list should parse")
	assert_eq(snapshot.members[0].member_phase, "queue_locked", "member_phase should map from canonical snapshot member field")


func test_room_snapshot_duplicate_deep_preserves_canonical_fields() -> void:
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_phase = "idle"
	snapshot.queue_phase = "completed"
	snapshot.queue_terminal_reason = "match_finalized"
	snapshot.can_enter_queue = true
	var member := RoomMemberState.new()
	member.peer_id = 7
	member.member_phase = "ready"
	snapshot.members.append(member)

	var copied := snapshot.duplicate_deep()
	assert_eq(copied.room_phase, "idle", "duplicate should preserve room_phase")
	assert_eq(copied.queue_phase, "completed", "duplicate should preserve queue_phase")
	assert_eq(copied.queue_terminal_reason, "match_finalized", "duplicate should preserve queue terminal reason")
	assert_true(copied.can_enter_queue, "duplicate should preserve capabilities")
	assert_eq(copied.members[0].member_phase, "ready", "duplicate should preserve member phase")
