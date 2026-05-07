extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomViewModelBuilderScript = preload("res://app/front/room/room_view_model_builder.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")
const RoomRuntimeContextScript = preload("res://network/session/runtime/room_runtime_context.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


func test_completed_match_finalized_reenter_depends_on_capability_and_idle_phase() -> void:
	var builder := RoomViewModelBuilderScript.new()
	var snapshot := _build_match_snapshot()
	snapshot.room_phase = "idle"
	snapshot.queue_phase = "completed"
	snapshot.queue_terminal_reason = "match_finalized"
	snapshot.can_enter_queue = true

	var vm := builder.build_view_model(snapshot, RoomRuntimeContextScript.new(), PlayerProfileStateScript.new(), RoomEntryContextScript.new())

	assert_true(bool(vm.get("can_enter_queue", false)), "re-enter queue should come from capability when room phase is idle")
	assert_eq(String(vm.get("queue_status_text", "")), "对局已完成", "queue text should follow canonical completed+match_finalized")


func test_match_room_blocker_uses_canonical_room_phase() -> void:
	var builder := RoomViewModelBuilderScript.new()
	var snapshot := _build_match_snapshot()
	snapshot.room_phase = "battle_allocating"
	snapshot.can_enter_queue = false

	var vm := builder.build_view_model(snapshot, RoomRuntimeContextScript.new(), PlayerProfileStateScript.new(), RoomEntryContextScript.new())

	assert_eq(String(vm.get("blocker_text", "")), "当前阶段不可开始匹配", "blocker should be based on canonical room phase")


func _build_match_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_kind = "ranked_match_room"
	snapshot.topology = "dedicated_server"
	snapshot.owner_peer_id = 1
	snapshot.match_format_id = "2v2"
	snapshot.required_party_size = 2
	snapshot.selected_match_mode_ids = ["box"]
	snapshot.room_phase = "idle"
	snapshot.queue_phase = "idle"
	snapshot.queue_terminal_reason = "none"
	snapshot.all_ready = true
	for index in range(2):
		var member := RoomMemberStateScript.new()
		member.peer_id = index + 1
		member.player_name = "Player%d" % (index + 1)
		member.ready = true
		member.member_phase = "ready"
		member.slot_index = index
		member.is_owner = member.peer_id == 1
		member.is_local_player = member.peer_id == 1
		snapshot.members.append(member)
	return snapshot
