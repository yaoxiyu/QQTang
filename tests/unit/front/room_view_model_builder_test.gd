extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomViewModelBuilderScript = preload("res://app/front/room/room_view_model_builder.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")
const RoomRuntimeContextScript = preload("res://network/session/runtime/room_runtime_context.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


func test_view_model_uses_snapshot_capabilities_directly() -> void:
	var builder := RoomViewModelBuilderScript.new()
	var snapshot := _build_match_snapshot()
	snapshot.can_toggle_ready = true
	snapshot.can_start_manual_battle = false
	snapshot.can_update_selection = false
	snapshot.can_update_match_room_config = true
	snapshot.can_enter_queue = true
	snapshot.can_cancel_queue = false

	var vm := builder.build_view_model(snapshot, RoomRuntimeContextScript.new(), PlayerProfileStateScript.new(), RoomEntryContextScript.new())

	assert_true(bool(vm.get("can_ready", false)), "can_ready should come from can_toggle_ready")
	assert_false(bool(vm.get("can_start", true)), "can_start should come from can_start_manual_battle")
	assert_false(bool(vm.get("can_edit_selection", true)), "can_edit_selection should come from can_update_selection")
	assert_true(bool(vm.get("can_edit_match_room_config", false)), "can_edit_match_room_config should come from can_update_match_room_config")
	assert_true(bool(vm.get("can_enter_queue", false)), "can_enter_queue should come from capability")
	assert_false(bool(vm.get("can_cancel_queue", true)), "can_cancel_queue should come from capability")


func test_queue_status_text_uses_canonical_phase_and_reason() -> void:
	var builder := RoomViewModelBuilderScript.new()
	var snapshot := _build_match_snapshot()
	snapshot.queue_phase = "completed"
	snapshot.queue_terminal_reason = "allocation_failed"

	var vm := builder.build_view_model(snapshot, RoomRuntimeContextScript.new(), PlayerProfileStateScript.new(), RoomEntryContextScript.new())

	assert_eq(String(vm.get("queue_status_text", "")), "分配失败", "canonical completed+allocation_failed should map to expected text")


func _build_match_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_kind = "ranked_match_room"
	snapshot.topology = "dedicated_server"
	snapshot.owner_peer_id = 1
	snapshot.room_phase = "idle"
	snapshot.room_lifecycle_state = "idle"
	snapshot.queue_phase = "queued"
	snapshot.queue_terminal_reason = "none"
	snapshot.room_queue_state = "queued"
	snapshot.match_format_id = "2v2"
	snapshot.required_party_size = 2
	snapshot.selected_match_mode_ids = ["mode_classic"]
	snapshot.selected_map_id = "map_arcade"
	snapshot.rule_set_id = "ruleset_classic"
	snapshot.mode_id = "mode_classic"
	snapshot.all_ready = true
	for index in range(2):
		var member := RoomMemberStateScript.new()
		member.peer_id = index + 1
		member.player_name = "Player%d" % (index + 1)
		member.ready = true
		member.slot_index = index
		member.is_owner = member.peer_id == 1
		member.is_local_player = member.peer_id == 1
		snapshot.members.append(member)
	return snapshot
