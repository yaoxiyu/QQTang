extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")


func test_main() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.front_flow.enter_room()

	var entry_context := RoomEntryContextScript.new()
	entry_context.room_kind = "private_room"
	entry_context.topology = "dedicated_server"
	entry_context.target_room_id = "ROOM-RESET"
	runtime.current_room_entry_context = entry_context

	var snapshot := RoomSnapshotScript.new()
	snapshot.room_id = "ROOM-RESET"
	snapshot.room_kind = "private_room"
	snapshot.topology = "dedicated_server"
	snapshot.owner_peer_id = 1
	snapshot.max_players = 8
	snapshot.min_start_players = 2
	var member := RoomMemberStateScript.new()
	member.peer_id = 1
	member.player_name = "Tester"
	member.character_id = "char_default"
	snapshot.members.append(member)
	runtime.room_use_case.on_authoritative_snapshot(snapshot)

	_assert_true(String(runtime.front_settings_state.reconnect_room_id) == "ROOM-RESET", "authoritative room snapshot updates reconnect room id")
	_assert_true(int(runtime.front_settings_state.reconnect_port) == 9100, "authoritative room snapshot preserves reconnect server port")

	var result: Dictionary = runtime.room_use_case.leave_room()
	_assert_true(bool(result.get("ok", false)), "leave_room succeeds")
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.LOBBY), "leave_room returns to lobby")
	_assert_true(runtime.current_room_entry_context == null, "leave_room clears current room entry context")
	_assert_true(runtime.current_room_snapshot == null, "leave_room clears current room snapshot")
	_assert_true(runtime.room_session_controller.room_session.peers.is_empty(), "leave_room clears local room members")
	_assert_true(runtime.room_session_controller.member_profiles.is_empty(), "leave_room clears local member profiles")
	_assert_true(String(runtime.front_settings_state.reconnect_room_id) == "", "leave_room clears reconnect room id")
	_assert_true(String(runtime.front_settings_state.reconnect_member_id) == "", "leave_room clears reconnect member id")
	_assert_true(String(runtime.front_settings_state.reconnect_token) == "", "leave_room clears reconnect token")

	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	assert_true(condition, message)


