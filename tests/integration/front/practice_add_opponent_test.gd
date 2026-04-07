extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_add_opponent_updates_room_and_battle_config()


func _test_add_opponent_updates_room_and_battle_config() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var practice_result: Dictionary = runtime.lobby_use_case.start_practice("", "", "")
	var entry_context = practice_result.get("entry_context", null)
	var enter_result: Dictionary = runtime.room_use_case.enter_room(entry_context)
	_assert_true(bool(enter_result.get("ok", false)), "practice room enters successfully")

	runtime.debug_tools.ensure_manual_local_loop_room(
		runtime.room_session_controller,
		int(runtime.local_peer_id),
		int(runtime.remote_peer_id)
	)

	var snapshot: RoomSnapshot = runtime.room_session_controller.build_room_snapshot()
	_assert_true(snapshot.member_count() == 2, "add opponent creates a second room member")
	_assert_true(snapshot.has_member(int(runtime.remote_peer_id)), "remote opponent exists in room snapshot")

	runtime.room_session_controller.set_member_ready(int(runtime.local_peer_id), true)
	var prepare_result: Dictionary = runtime.match_start_coordinator.prepare_start_config(snapshot)
	_assert_true(bool(prepare_result.get("ok", false)), "battle config can build after add opponent")
	var config: BattleStartConfig = prepare_result.get("config", null)
	_assert_true(config != null and config.player_slots.size() == 2, "battle start config carries both players")

	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
