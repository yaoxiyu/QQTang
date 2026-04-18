extends "res://tests/gut/base/qqt_contract_test.gd"

const ROOM_SCENE_CONTROLLER_PATH := "res://scenes/front/room_scene_controller.gd"
const ROOM_SCENE_PATH := "res://scenes/front/room_scene.tscn"
const MAX_ROOM_SCENE_CONTROLLER_LINES := 420
const FORBIDDEN_PATTERNS := [
	"func _ensure_scroll_layout(",
	"func _ensure_action_buttons(",
	"ScrollContainer.new()",
	"Button.new()",
	"add_child(",
	"remove_child(",
	"move_child(",
]
const REQUIRED_SCENE_NODES := [
	"RoomRoot/RoomScroll",
	"RoomRoot/RoomScroll/MainLayout",
	"RoomRoot/RoomScroll/MainLayout/ActionRow/AddOpponentButton",
]


func test_room_scene_controller_stays_within_boundary() -> void:
	var text := _read_text(ROOM_SCENE_CONTROLLER_PATH)
	assert_false(text.is_empty(), "room_scene_controller.gd should be readable")
	assert_true(_line_count(text) <= MAX_ROOM_SCENE_CONTROLLER_LINES, "room_scene_controller.gd should stay <= %d lines" % MAX_ROOM_SCENE_CONTROLLER_LINES)

	var violations: Array[String] = []
	for pattern in FORBIDDEN_PATTERNS:
		if text.find(pattern) >= 0:
			violations.append(pattern)
	assert_true(violations.is_empty(), "room_scene_controller.gd boundary violations:\n%s" % "\n".join(violations))


func test_room_scene_owns_required_structure() -> void:
	var scene: PackedScene = load(ROOM_SCENE_PATH)
	assert_not_null(scene, "room_scene.tscn should load")
	if scene == null:
		return
	var root := scene.instantiate()
	for node_path in REQUIRED_SCENE_NODES:
		assert_true(root.has_node(node_path), "room_scene.tscn should expose %s" % node_path)
	root.free()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _line_count(text: String) -> int:
	if text.is_empty():
		return 0
	return text.split("\n").size()
