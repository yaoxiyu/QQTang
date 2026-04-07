extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_room_snapshot_carries_authoritative_mode_and_topology()
	_test_battle_start_config_prefers_room_snapshot_mode()


func _test_room_snapshot_carries_authoritative_mode_and_topology() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var practice_result: Dictionary = runtime.lobby_use_case.start_practice("", "", "")
	_assert_true(bool(practice_result.get("ok", false)), "practice room can be created through lobby use case")
	var snapshot = runtime.room_session_controller.build_room_snapshot()
	_assert_true(String(snapshot.room_kind) == FrontRoomKindScript.PRACTICE, "practice snapshot carries room_kind")
	_assert_true(String(snapshot.topology) == FrontTopologyScript.LOCAL, "practice snapshot carries local topology")
	_assert_true(not String(snapshot.mode_id).is_empty(), "practice snapshot carries authoritative mode_id")
	_assert_true(int(snapshot.min_start_players) == 1, "practice snapshot carries authoritative min_start_players")

	runtime.queue_free()


func _test_battle_start_config_prefers_room_snapshot_mode() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var practice_result: Dictionary = runtime.lobby_use_case.start_practice("", "", "")
	_assert_true(bool(practice_result.get("ok", false)), "practice room setup succeeds before building config")
	var snapshot = runtime.room_session_controller.build_room_snapshot()
	var authoritative_mode_id := String(snapshot.mode_id)
	runtime.player_profile_state.preferred_mode_id = "profile_mode_should_not_override_room"

	var config = runtime.build_and_store_start_config(snapshot)
	_assert_true(config != null, "battle start config can be built from room snapshot")
	if config != null:
		_assert_true(String(config.mode_id) == authoritative_mode_id, "battle start config uses RoomSnapshot.mode_id as authority")
		_assert_true(String(config.topology) == FrontTopologyScript.LOCAL, "practice battle config uses local topology")
		_assert_true(String(config.session_mode) == "singleplayer_local", "practice battle config uses local session_mode")

	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
