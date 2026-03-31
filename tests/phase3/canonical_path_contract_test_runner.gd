extends Node

const SceneFlowControllerScript = preload("res://app/flow/scene_flow_controller.gd")
const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")

const CANONICAL_FRONT_FLOW_PATH := "res://app/flow/front_flow_controller.gd"
const CANONICAL_ROOM_SESSION_PATH := "res://network/session/room_session_controller.gd"
const CANONICAL_MATCH_START_PATH := "res://network/session/match_start_coordinator.gd"
const CANONICAL_BATTLE_SESSION_PATH := "res://network/session/battle_session_adapter.gd"

const FORMAL_SCENE_PATHS := [
	"res://scenes/front/room_scene.tscn",
	"res://scenes/front/loading_scene.tscn",
	"res://scenes/battle/battle_main.tscn",
]


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_battle_scene_path_uses_formal_battle_main()
	_test_formal_scenes_do_not_reference_sandbox_or_legacy_wrappers()
	_test_runtime_uses_canonical_scripts()


func _test_battle_scene_path_uses_formal_battle_main() -> void:
	_assert_true(SceneFlowControllerScript.BATTLE_SCENE_PATH == "res://scenes/battle/battle_main.tscn", "battle scene path uses formal BattleMain")
	_assert_true(not SceneFlowControllerScript.BATTLE_SCENE_PATH.contains("sandbox"), "battle scene path contains no sandbox segment")


func _test_formal_scenes_do_not_reference_sandbox_or_legacy_wrappers() -> void:
	for scene_path in FORMAL_SCENE_PATHS:
		var text: String = _read_text(scene_path)
		_assert_true(not text.contains("sandbox"), "%s contains no sandbox reference" % scene_path)
		_assert_true(not text.contains("res://gameplay/front/flow/"), "%s contains no legacy front wrapper path" % scene_path)
		_assert_true(not text.contains("res://gameplay/network/session/"), "%s contains no legacy session wrapper path" % scene_path)


func _test_runtime_uses_canonical_scripts() -> void:
	var runtime: Node = AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	_assert_true(runtime.front_flow.get_script().resource_path == CANONICAL_FRONT_FLOW_PATH, "app runtime uses canonical front flow script")
	_assert_true(runtime.room_session_controller.get_script().resource_path == CANONICAL_ROOM_SESSION_PATH, "app runtime uses canonical room session script")
	_assert_true(runtime.match_start_coordinator.get_script().resource_path == CANONICAL_MATCH_START_PATH, "app runtime uses canonical match start coordinator script")
	_assert_true(runtime.battle_session_adapter.get_script().resource_path == CANONICAL_BATTLE_SESSION_PATH, "app runtime uses canonical battle session adapter script")
	runtime.free()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
