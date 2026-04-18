extends "res://tests/gut/base/qqt_integration_test.gd"

const RoomViewModelBuilderScript = preload("res://app/front/room/room_view_model_builder.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")
const RoomRuntimeContextScript = preload("res://network/session/runtime/room_runtime_context.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")



func test_main() -> void:
	_main_body()


func _main_body() -> void:
	var builder := RoomViewModelBuilderScript.new()
	var context := RoomRuntimeContextScript.new()
	context.local_player_id = 1
	var profile := PlayerProfileStateScript.new()
	var entry_context := RoomEntryContextScript.new()
	var prefix := "match_room_ready_then_enter_queue_test"
	var ok := true

	var one_member := _build_snapshot(1, [true])
	var one_vm := builder.build_view_model(one_member, context, profile, entry_context)
	ok = qqt_check(not bool(one_vm.get("can_enter_queue", true)), "2v2 needs full party before queue", prefix) and ok

	var not_ready := _build_snapshot(2, [true, false])
	var not_ready_vm := builder.build_view_model(not_ready, context, profile, entry_context)
	ok = qqt_check(not bool(not_ready_vm.get("can_enter_queue", true)), "all party members must be ready", prefix) and ok

	var ready := _build_snapshot(2, [true, true])
	var ready_vm := builder.build_view_model(ready, context, profile, entry_context)
	ok = qqt_check(bool(ready_vm.get("can_enter_queue", false)), "full ready 2v2 party can enter queue", prefix) and ok
	ok = qqt_check(not bool(ready_vm.get("show_team_selector", true)), "match room should hide team selector", prefix) and ok
	ok = qqt_check(bool(ready_vm.get("show_match_mode_multi_select", false)), "match room should show mode pool", prefix) and ok
	assert_true(ok, "match room queue view model should enforce party readiness")



func _build_snapshot(member_count: int, ready_flags: Array) -> RoomSnapshot:
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_id = "ROOM-MATCH-VM"
	snapshot.room_kind = "ranked_match_room"
	snapshot.topology = "dedicated_server"
	snapshot.owner_peer_id = 1
	snapshot.queue_type = "ranked"
	snapshot.match_format_id = "2v2"
	snapshot.required_party_size = 2
	snapshot.selected_match_mode_ids = ["mode_classic"]
	snapshot.room_queue_state = "idle"
	snapshot.all_ready = true
	for index in range(member_count):
		var member := RoomMemberStateScript.new()
		member.peer_id = index + 1
		member.player_name = "Player%d" % (index + 1)
		member.ready = bool(ready_flags[index])
		member.slot_index = index
		member.is_owner = member.peer_id == 1
		member.is_local_player = member.peer_id == 1
		snapshot.members.append(member)
		snapshot.all_ready = snapshot.all_ready and member.ready
	return snapshot


