extends "res://tests/gut/base/qqt_contract_test.gd"

const ROOM_SCENE_CONTROLLER_PATH := "res://scenes/front/room_scene_controller.gd"
const ROOM_SCENE_CORE_IMPL_PATH := "res://scenes/front/room/room_scene_controller_impl.gd"
const ROOM_FORMAL_LOADOUT_PRESENTER_PATH := "res://scenes/front/room/room_formal_loadout_presenter.gd"
const ROOM_FORMAL_POPUP_CONTROLLER_PATH := "res://scenes/front/room/room_formal_popup_controller.gd"
const APP_BATTLE_MODULE_REGISTRY_PATH := "res://app/flow/app_battle_module_registry.gd"
const BATTLE_MAIN_CONTROLLER_PATH := "res://scenes/battle/battle_main_controller.gd"
const ROOM_SCENE_PATH := "res://scenes/front/room_scene.tscn"
const MAX_ROOM_SCENE_CONTROLLER_LINES := 420
const MAX_ROOM_SCENE_CORE_IMPL_LINES := 600
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


func test_room_scene_core_impl_keeps_formal_ui_factories_out() -> void:
	var text := _read_text(ROOM_SCENE_CORE_IMPL_PATH)
	assert_false(text.is_empty(), "room_scene_controller_impl.gd should be readable")
	assert_true(_line_count(text) <= MAX_ROOM_SCENE_CORE_IMPL_LINES, "room_scene_controller_impl.gd should stay <= %d lines" % MAX_ROOM_SCENE_CORE_IMPL_LINES)
	var violations: Array[String] = []
	for pattern in ["Button.new()", "PopupPanel.new()", "add_child(", "func _make_room_style(", "func _create_formal_slot_card("]:
		if text.find(pattern) >= 0:
			violations.append(pattern)
	assert_true(violations.is_empty(), "room_scene_controller_impl.gd should delegate formal UI factories:\n%s" % "\n".join(violations))


func test_formal_room_property_controls_are_host_gated() -> void:
	var text := _read_text(ROOM_FORMAL_LOADOUT_PRESENTER_PATH)
	assert_false(text.is_empty(), "room_formal_loadout_presenter.gd should be readable")
	assert_true(text.find("_formal_choose_mode_button.visible = is_custom_room and can_edit_room") >= 0, "choose mode must be hidden from non-hosts")
	assert_true(text.find("_formal_room_property_button.visible = is_custom_room and can_edit_room") >= 0, "room property must be hidden from non-hosts")
	assert_true(text.find("_formal_choose_map_button.visible = is_custom_room and can_edit_room") >= 0, "choose map must be hidden from non-hosts")
	assert_true(text.find("func _resolve_formal_map_display_name(") >= 0, "map labels must resolve catalog display names")


func test_formal_room_popup_entrypoints_are_host_gated() -> void:
	var text := _read_text(ROOM_FORMAL_POPUP_CONTROLLER_PATH)
	assert_false(text.is_empty(), "room_formal_popup_controller.gd should be readable")
	assert_true(text.find("func _on_formal_choose_mode_pressed()") < text.find("只有房主可以选择模式"), "choose mode popup must reject non-hosts")
	assert_true(text.find("func _on_formal_room_property_pressed()") < text.find("只有房主可以修改房间属性"), "room property popup must reject non-hosts")
	assert_true(text.find("func _on_formal_choose_map_pressed()") < text.find("只有房主可以选择地图"), "choose map popup must reject non-hosts")


func test_battle_scene_reparent_does_not_trigger_shutdown() -> void:
	var registry_text := _read_text(APP_BATTLE_MODULE_REGISTRY_PATH)
	var battle_text := _read_text(BATTLE_MAIN_CONTROLLER_PATH)
	assert_true(registry_text.find("begin_runtime_reparent") >= 0, "battle registry should mark intentional reparent")
	assert_true(registry_text.find("end_runtime_reparent") >= 0, "battle registry should clear intentional reparent")
	assert_true(battle_text.find("if _runtime_reparenting:") >= 0, "battle main exit_tree should ignore intentional runtime reparent")


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
