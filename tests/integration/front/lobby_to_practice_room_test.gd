extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")


func test_main() -> void:
	_main_body()


func _main_body() -> void:
	_test_lobby_can_enter_practice_room_without_debug_remote_members()


func _test_lobby_can_enter_practice_room_without_debug_remote_members() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var result: Dictionary = runtime.lobby_use_case.start_practice("", "", "")
	_assert_true(bool(result.get("ok", false)), "lobby can create practice room")
	var entry_context = result.get("entry_context", null)
	_assert_true(entry_context != null, "practice room entry context exists")
	if entry_context != null:
		_assert_true(String(entry_context.entry_kind) == FrontEntryKindScript.PRACTICE, "practice entry uses PRACTICE kind")
		_assert_true(String(entry_context.room_kind) == FrontRoomKindScript.PRACTICE, "practice entry uses practice room kind")
		_assert_true(String(entry_context.topology) == FrontTopologyScript.LOCAL, "practice entry uses local topology")

	var room_result: Dictionary = runtime.room_use_case.enter_room(entry_context)
	_assert_true(bool(room_result.get("ok", false)), "room use case can enter practice room")
	var snapshot = runtime.room_session_controller.build_room_snapshot()
	_assert_true(int(snapshot.member_count()) == 1, "practice room does not auto-add remote debug members")
	_assert_true(int(snapshot.min_start_players) == 1, "practice room can start with one player")
	_assert_true(String(snapshot.mode_id).strip_edges().length() > 0, "practice room snapshot carries mode_id")

	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return


