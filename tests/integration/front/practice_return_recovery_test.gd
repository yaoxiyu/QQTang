extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const ClientLaunchModeScript = preload("res://network/runtime/client_launch_mode.gd")
const RoomReturnRecoveryScript = preload("res://network/session/runtime/room_return_recovery.gd")


func test_main() -> void:
	_main_body()


func _main_body() -> void:
	_test_practice_return_keeps_local_player_startable()
	_test_network_return_restores_ready_capability()
	_test_dedicated_topology_return_restores_ready_capability_without_network_launch_mode()


func _test_practice_return_keeps_local_player_startable() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var practice_result: Dictionary = runtime.lobby_use_case.start_practice("", "", "")
	var entry_context = practice_result.get("entry_context", null)
	var enter_result: Dictionary = runtime.room_use_case.enter_room(entry_context)
	_assert_true(bool(enter_result.get("ok", false)), "practice room enters successfully")

	var recovery := RoomReturnRecoveryScript.new()
	recovery.recover(runtime, "return_to_room")

	var snapshot: RoomSnapshot = runtime.room_session_controller.build_room_snapshot()
	_assert_true(snapshot.member_count() == 1, "practice room still has single local member after recovery")
	_assert_true(snapshot.all_ready, "practice room keeps local member ready after recovery")

	var start_result: Dictionary = runtime.room_use_case.start_match()
	_assert_true(bool(start_result.get("ok", false)), "practice room can start second match after return recovery")

	runtime.queue_free()


func _test_network_return_restores_ready_capability() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.runtime_config.launch_mode = ClientLaunchModeScript.Value.NETWORK_CLIENT
	var controller = runtime.room_session_controller
	controller.create_room(runtime.local_peer_id)
	controller.room_session.room_kind = "casual_match_room"
	controller.room_session.room_phase = "in_battle"
	controller.room_session.queue_phase = "entry_ready"
	controller.room_session.can_toggle_ready = false
	controller.room_session.can_enter_queue = false
	controller.room_session.match_format_id = "1v1"
	controller.room_session.selected_match_mode_ids = ["box"]
	controller.set_member_ready(runtime.local_peer_id, true)

	var recovery := RoomReturnRecoveryScript.new()
	recovery.recover(runtime, "return_to_room")

	var snapshot: RoomSnapshot = controller.build_room_snapshot()
	assert_true(snapshot.room_phase == "idle", "network return restores idle room phase")
	assert_true(snapshot.can_toggle_ready, "network return restores ready capability")
	assert_true(not snapshot.all_ready, "network return clears stale ready state")
	runtime.queue_free()


func _test_dedicated_topology_return_restores_ready_capability_without_network_launch_mode() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.runtime_config.launch_mode = ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER
	var controller = runtime.room_session_controller
	controller.create_room(runtime.local_peer_id)
	controller.room_session.room_kind = "casual_match_room"
	controller.room_session.topology = "dedicated_server"
	controller.room_session.room_phase = "in_battle"
	controller.room_session.room_queue_state = "matched"
	controller.room_session.room_queue_entry_id = "queue-1"
	controller.room_session.queue_phase = "entry_ready"
	controller.room_session.can_toggle_ready = false
	controller.room_session.can_enter_queue = false
	controller.room_session.can_cancel_queue = true
	controller.room_session.match_format_id = "1v1"
	controller.room_session.selected_match_mode_ids = ["box"]
	controller.set_member_ready(runtime.local_peer_id, true)

	var recovery := RoomReturnRecoveryScript.new()
	recovery.recover(runtime, "return_to_room")

	var snapshot: RoomSnapshot = controller.build_room_snapshot()
	assert_eq(snapshot.room_phase, "idle", "dedicated topology return restores idle room phase")
	assert_eq(snapshot.room_queue_state, "idle", "dedicated topology return clears legacy queue state")
	assert_eq(snapshot.room_queue_entry_id, "", "dedicated topology return clears legacy queue entry")
	assert_true(snapshot.can_toggle_ready, "dedicated topology return restores ready capability")
	assert_false(snapshot.can_cancel_queue, "dedicated topology return disables cancel queue")
	assert_false(snapshot.all_ready, "dedicated topology return clears stale ready state")
	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
