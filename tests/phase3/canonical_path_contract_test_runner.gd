extends Node

const SceneFlowControllerScript = preload("res://app/flow/scene_flow_controller.gd")
const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")

const LEGACY_WRAPPERS := [
	{
		"path": "res://gameplay/front/flow/app_runtime_root.gd",
		"canonical": "res://app/flow/app_runtime_root.gd",
	},
	{
		"path": "res://gameplay/front/flow/front_flow_controller.gd",
		"canonical": "res://app/flow/front_flow_controller.gd",
	},
	{
		"path": "res://gameplay/front/flow/scene_flow_controller.gd",
		"canonical": "res://app/flow/scene_flow_controller.gd",
	},
	{
		"path": "res://gameplay/network/session/room_session_controller.gd",
		"canonical": "res://network/session/room_session_controller.gd",
	},
	{
		"path": "res://gameplay/network/session/match_start_coordinator.gd",
		"canonical": "res://network/session/match_start_coordinator.gd",
	},
	{
		"path": "res://gameplay/network/session/battle_session_adapter.gd",
		"canonical": "res://network/session/battle_session_adapter.gd",
	},
]

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
	_test_legacy_wrappers_are_comment_plus_extends_only()


func _test_battle_scene_path_uses_formal_battle_main() -> void:
	_assert_true(SceneFlowControllerScript.BATTLE_SCENE_PATH == "res://scenes/battle/battle_main.tscn", "battle scene path uses formal BattleMain")
	_assert_true(not SceneFlowControllerScript.BATTLE_SCENE_PATH.contains("sandbox"), "battle scene path contains no sandbox segment")


func _test_formal_scenes_do_not_reference_sandbox_or_legacy_wrappers() -> void:
	for scene_path in FORMAL_SCENE_PATHS:
		var text := _read_text(scene_path)
		_assert_true(not text.contains("sandbox"), "%s contains no sandbox reference" % scene_path)
		_assert_true(not text.contains("res://gameplay/front/flow/"), "%s contains no legacy front wrapper path" % scene_path)
		_assert_true(not text.contains("res://gameplay/network/session/"), "%s contains no legacy session wrapper path" % scene_path)


func _test_runtime_uses_canonical_scripts() -> void:
	var runtime = AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	_assert_true(runtime.front_flow.get_script().resource_path == FrontFlowControllerScript.resource_path, "app runtime uses canonical front flow script")
	_assert_true(runtime.room_session_controller.get_script().resource_path == RoomSessionControllerScript.resource_path, "app runtime uses canonical room session script")
	_assert_true(runtime.match_start_coordinator.get_script().resource_path == MatchStartCoordinatorScript.resource_path, "app runtime uses canonical match start coordinator script")
	_assert_true(runtime.battle_session_adapter.get_script().resource_path == BattleSessionAdapterScript.resource_path, "app runtime uses canonical battle session adapter script")
	runtime.queue_free()


func _test_legacy_wrappers_are_comment_plus_extends_only() -> void:
	for wrapper in LEGACY_WRAPPERS:
		var wrapper_path: String = str(wrapper.get("path", ""))
		var canonical_path: String = str(wrapper.get("canonical", ""))
		var text := _read_text(wrapper_path)
		_assert_true(text.contains("Legacy compatibility wrapper."), "%s is marked as legacy wrapper" % wrapper_path)
		_assert_true(text.contains(canonical_path), "%s documents canonical path" % wrapper_path)
		var code_lines: Array[String] = []
		for raw_line in text.split("\n"):
			var line := raw_line.strip_edges()
			if line.is_empty() or line.begins_with("#"):
				continue
			code_lines.append(line)
		_assert_true(code_lines.size() == 1, "%s contains only one code statement" % wrapper_path)
		_assert_true(code_lines.size() == 1 and code_lines[0] == "extends \"%s\"" % canonical_path, "%s only extends canonical path" % wrapper_path)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
