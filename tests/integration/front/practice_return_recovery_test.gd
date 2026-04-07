extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const RoomReturnRecoveryScript = preload("res://network/session/runtime/room_return_recovery.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_practice_return_keeps_local_player_startable()


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


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
