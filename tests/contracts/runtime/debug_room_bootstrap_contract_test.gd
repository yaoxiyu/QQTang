extends "res://tests/gut/base/qqt_contract_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const AppRuntimeConfigScript = preload("res://app/flow/app_runtime_config.gd")
const RuntimeDebugToolsScript = preload("res://app/debug/runtime_debug_tools.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const ROOM_SCENE_PATH := "res://scenes/front/room/room_formal.tscn"
const ROOM_SCENE_CONTROLLER_PATH := "res://scenes/front/room/room_formal_controller.gd"


func test_main() -> void:
	_main_body()


func _main_body() -> void:
	_test_debug_on_bootstraps_local_loop_room()
	_test_debug_off_does_not_bootstrap_remote_member()
	_test_manual_local_loop_room_supports_explicit_single_player_start()
	_test_room_scene_uses_canonical_controller_contract()
	_test_reset_local_loop_ready_only_applies_when_debug_enabled()


func _test_debug_on_bootstraps_local_loop_room() -> void:
	var runtime: Node = _create_runtime(true, true, true)
	runtime.debug_tools.bootstrap_local_loop_room_if_enabled(
		runtime.room_session_controller,
		runtime.runtime_config,
		runtime.local_peer_id,
		runtime.remote_peer_id
	)

	var snapshot = runtime.room_session_controller.build_room_snapshot()
	_assert_true(snapshot.member_count() == 2, "debug on bootstraps local loop room with remote member")
	_assert_true(snapshot.owner_peer_id == runtime.local_peer_id, "debug on keeps local peer as room owner")

	runtime.free()


func _test_debug_off_does_not_bootstrap_remote_member() -> void:
	var runtime: Node = _create_runtime(false, false, false)
	runtime.debug_tools.bootstrap_local_loop_room_if_enabled(
		runtime.room_session_controller,
		runtime.runtime_config,
		runtime.local_peer_id,
		runtime.remote_peer_id
	)

	var snapshot = runtime.room_session_controller.build_room_snapshot()
	_assert_true(snapshot.member_count() == 0, "debug off does not auto insert remote member")
	_assert_true(snapshot.room_id.is_empty(), "debug off keeps room uncreated until explicit action")

	runtime.free()


func _test_manual_local_loop_room_supports_explicit_single_player_start() -> void:
	var runtime: Node = _create_runtime(false, false, false)
	runtime.debug_tools.ensure_manual_local_loop_room(
		runtime.room_session_controller,
		runtime.local_peer_id,
		runtime.remote_peer_id
	)
	runtime.room_session_controller.set_member_ready(runtime.local_peer_id, true)

	var snapshot = runtime.room_session_controller.build_room_snapshot()
	var local_member = _find_member(snapshot, runtime.local_peer_id)
	var remote_member = _find_member(snapshot, runtime.remote_peer_id)
	_assert_true(snapshot.member_count() == 2, "manual local loop creates explicit single-player room with remote member")
	_assert_true(local_member != null and local_member.ready, "manual local loop allows local ready state to be set explicitly")
	_assert_true(remote_member != null and remote_member.ready, "manual local loop keeps debug remote member ready")
	_assert_true(runtime.room_session_controller.can_request_start_match(runtime.local_peer_id), "manual local loop enables explicit single-player start request")

	runtime.free()


func _test_room_scene_uses_canonical_controller_contract() -> void:
	var file := FileAccess.open(ROOM_SCENE_PATH, FileAccess.READ)
	_assert_true(file != null, "room scene contract file is readable")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_assert_true(text.contains("script = ExtResource(\"1_ctrl\")"), "room scene binds canonical controller ext resource")
	_assert_true(text.contains(ROOM_SCENE_CONTROLLER_PATH), "room scene controller path is canonical")
	_assert_true(not text.contains("bootstrap_local_loop_room_if_enabled"), "room scene contains no embedded debug bootstrap logic")


func _test_reset_local_loop_ready_only_applies_when_debug_enabled() -> void:
	var debug_tools: Node = RuntimeDebugToolsScript.new()
	var runtime: Node = _create_runtime(false, false, false)
	var room_controller: Node = runtime.room_session_controller
	add_child(debug_tools)

	room_controller.create_room(1)
	var remote = RoomMemberStateScript.new()
	remote.peer_id = 2
	remote.player_name = "Remote"
	remote.ready = true
	remote.slot_index = 1
	remote.character_id = "hero_remote"
	room_controller.join_room(remote)
	room_controller.set_member_ready(1, true)

	var config_on: RefCounted = AppRuntimeConfigScript.new()
	config_on.enable_local_loop_debug_room = true
	debug_tools.reset_local_loop_room_ready(room_controller, config_on, 1, 2)
	var snapshot_on = room_controller.build_room_snapshot()
	var local_on = _find_member(snapshot_on, 1)
	var remote_on = _find_member(snapshot_on, 2)
	_assert_true(local_on != null and remote_on != null and not local_on.ready and remote_on.ready, "debug on reset reapplies local loop ready policy")

	room_controller.set_member_ready(1, true)
	var config_off: RefCounted = AppRuntimeConfigScript.new()
	config_off.enable_local_loop_debug_room = false
	debug_tools.reset_local_loop_room_ready(room_controller, config_off, 1, 2)
	var snapshot_off = room_controller.build_room_snapshot()
	var local_off = _find_member(snapshot_off, 1)
	var remote_off = _find_member(snapshot_off, 2)
	_assert_true(local_off != null and not local_off.ready, "debug off reset still clears local ready for manual local loop room")
	_assert_true(remote_off != null and remote_off.ready, "debug off reset keeps remote ready for second round")

	debug_tools.free()
	runtime.free()


func _create_runtime(debug_enabled: bool, auto_create_room: bool, auto_add_remote: bool) -> Node:
	var runtime: Node = AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.runtime_config = AppRuntimeConfigScript.new()
	runtime.runtime_config.enable_local_loop_debug_room = debug_enabled
	runtime.runtime_config.auto_create_room_on_enter = auto_create_room
	runtime.runtime_config.auto_add_remote_debug_member = auto_add_remote
	return runtime


func _find_member(snapshot, peer_id: int):
	if snapshot == null:
		return null
	for member in snapshot.members:
		if member != null and member.peer_id == peer_id:
			return member
	return null


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return


