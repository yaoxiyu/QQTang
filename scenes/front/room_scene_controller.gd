extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")

@onready var room_hud_controller: RoomHudController = $RoomHudController
@onready var room_root: Control = $RoomRoot
@onready var main_layout: VBoxContainer = $RoomRoot/MainLayout
@onready var title_label: Label = $RoomRoot/MainLayout/TitleLabel
@onready var member_list: VBoxContainer = $RoomRoot/MainLayout/MemberList
@onready var ready_button: Button = $RoomRoot/MainLayout/ActionRow/ReadyButton
@onready var start_button: Button = $RoomRoot/MainLayout/ActionRow/StartButton
@onready var map_label: Label = $RoomRoot/MainLayout/SelectorRow/MapLabel
@onready var map_selector: OptionButton = $RoomRoot/MainLayout/SelectorRow/MapSelector
@onready var rule_label: Label = $RoomRoot/MainLayout/SelectorRow/RuleLabel
@onready var rule_selector: OptionButton = $RoomRoot/MainLayout/SelectorRow/RuleSelector
@onready var debug_label: Label = $RoomRoot/MainLayout/RoomDebugPanel/DebugLabel

var _app_runtime: Node = null
var _room_controller: Node = null
var _front_flow: Node = null
var _coordinator: Node = null
var _suppress_selection_callbacks: bool = false


func _ready() -> void:
	_configure_layout()
	_populate_selectors()
	call_deferred("_initialize_runtime")


func _initialize_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	_room_controller = _app_runtime.room_session_controller
	_front_flow = _app_runtime.front_flow
	_coordinator = _app_runtime.match_start_coordinator
	_connect_runtime_signals()
	if _app_runtime.debug_tools != null and _app_runtime.debug_tools.has_method("bootstrap_local_loop_room_if_enabled"):
		_app_runtime.debug_tools.bootstrap_local_loop_room_if_enabled(
			_room_controller,
			_app_runtime.runtime_config,
			_app_runtime.local_peer_id,
			_app_runtime.remote_peer_id
		)
	_refresh_room(_room_controller.build_room_snapshot())


func _exit_tree() -> void:
	if _room_controller != null:
		if _room_controller.room_snapshot_changed.is_connected(_on_room_snapshot_changed):
			_room_controller.room_snapshot_changed.disconnect(_on_room_snapshot_changed)
		if _room_controller.start_match_requested.is_connected(_on_start_match_requested):
			_room_controller.start_match_requested.disconnect(_on_start_match_requested)


func _configure_layout() -> void:
	room_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_layout.anchor_right = 1.0
	main_layout.anchor_bottom = 1.0
	main_layout.offset_left = 48.0
	main_layout.offset_top = 36.0
	main_layout.offset_right = -48.0
	main_layout.offset_bottom = -36.0
	main_layout.add_theme_constant_override("separation", 16)
	member_list.add_theme_constant_override("separation", 8)
	title_label.text = "QQTang Room"
	map_label.text = "Map"
	rule_label.text = "Rule"
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.text = "Initializing room runtime..."


func _populate_selectors() -> void:
	_suppress_selection_callbacks = true
	_populate_map_selector()
	_populate_rule_selector()
	_suppress_selection_callbacks = false


func _populate_map_selector() -> void:
	map_selector.clear()
	for entry in MapCatalogScript.get_map_entries():
		var map_id := String(entry.get("map_id", ""))
		if map_id.is_empty():
			continue
		var display_name := String(entry.get("display_name", map_id))
		_add_selector_item(map_selector, display_name, map_id)


func _populate_rule_selector() -> void:
	rule_selector.clear()
	for entry in RuleCatalogScript.get_rule_entries():
		var rule_id := String(entry.get("rule_id", ""))
		if rule_id.is_empty():
			continue
		var display_name := String(entry.get("display_name", rule_id))
		_add_selector_item(rule_selector, display_name, rule_id)


func _connect_runtime_signals() -> void:
	if _room_controller != null:
		if not _room_controller.room_snapshot_changed.is_connected(_on_room_snapshot_changed):
			_room_controller.room_snapshot_changed.connect(_on_room_snapshot_changed)
		if not _room_controller.start_match_requested.is_connected(_on_start_match_requested):
			_room_controller.start_match_requested.connect(_on_start_match_requested)

	if not ready_button.pressed.is_connected(_on_ready_button_pressed):
		ready_button.pressed.connect(_on_ready_button_pressed)
	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
	if not map_selector.item_selected.is_connected(_on_map_selected):
		map_selector.item_selected.connect(_on_map_selected)
	if not rule_selector.item_selected.is_connected(_on_rule_selected):
		rule_selector.item_selected.connect(_on_rule_selected)


func _refresh_room(snapshot: RoomSnapshot) -> void:
	if snapshot == null or _room_controller == null or _front_flow == null or _app_runtime == null:
		return

	for child in member_list.get_children():
		child.queue_free()

	for member in snapshot.sorted_members():
		var label := Label.new()
		if room_hud_controller != null:
			label.text = room_hud_controller.build_member_line(member, snapshot.owner_peer_id)
		else:
			var owner_text := " [Owner]" if member.peer_id == snapshot.owner_peer_id else ""
			var ready_text := "Ready" if member.ready else "Not Ready"
			label.text = "P%d  %s  %s%s" % [member.slot_index + 1, member.player_name, ready_text, owner_text]
		member_list.add_child(label)

	_select_metadata(map_selector, snapshot.selected_map_id)
	_select_metadata(rule_selector, snapshot.rule_set_id)

	var local_ready := bool(_room_controller.room_session.ready_state.get(_app_runtime.local_peer_id, false))
	ready_button.text = "Cancel Ready" if local_ready else "Ready"
	start_button.text = "Start Match"
	start_button.disabled = not _room_controller.can_request_start_match(_app_runtime.local_peer_id)

	if room_hud_controller != null:
		debug_label.text = room_hud_controller.build_debug_text(snapshot, _front_flow.get_state_name())
	else:
		var lines := [
			"Room: %s" % snapshot.room_id,
			"Owner: %d" % snapshot.owner_peer_id,
			"Map: %s" % snapshot.selected_map_id,
			"Rule: %s" % snapshot.rule_set_id,
			"AllReady: %s" % str(snapshot.all_ready),
			"Flow: %s" % String(_front_flow.get_state_name())
		]
		debug_label.text = "\n".join(lines)


func _add_selector_item(selector: OptionButton, title: String, value: String) -> void:
	selector.add_item(title)
	selector.set_item_metadata(selector.item_count - 1, value)


func _select_metadata(selector: OptionButton, value: String) -> void:
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) == value:
			selector.select(index)
			return


func _on_room_snapshot_changed(snapshot: RoomSnapshot) -> void:
	_refresh_room(snapshot)


func _on_start_match_requested(snapshot: RoomSnapshot) -> void:
	var config: BattleStartConfig = _app_runtime.build_and_store_start_config(snapshot)
	if config == null:
		debug_label.text = "Failed to build start config"
		return
	_front_flow.request_start_match()


func _on_ready_button_pressed() -> void:
	if _room_controller == null or _app_runtime == null:
		return
	if _should_prepare_manual_local_loop_room():
		_app_runtime.debug_tools.ensure_manual_local_loop_room(
			_room_controller,
			_app_runtime.local_peer_id,
			_app_runtime.remote_peer_id,
			_selected_metadata(map_selector),
			_selected_metadata(rule_selector)
		)
	var local_ready := bool(_room_controller.room_session.ready_state.get(_app_runtime.local_peer_id, false))
	_room_controller.set_member_ready(_app_runtime.local_peer_id, not local_ready)


func _on_start_button_pressed() -> void:
	if _room_controller == null or _app_runtime == null:
		return
	_room_controller.request_start_match(_app_runtime.local_peer_id)


func _on_map_selected(index: int) -> void:
	if _suppress_selection_callbacks or _room_controller == null:
		return
	_room_controller.set_room_selection(
		String(map_selector.get_item_metadata(index)),
		_selected_metadata(rule_selector)
	)


func _on_rule_selected(index: int) -> void:
	if _suppress_selection_callbacks or _room_controller == null:
		return
	_room_controller.set_room_selection(
		_selected_metadata(map_selector),
		String(rule_selector.get_item_metadata(index))
	)


func _selected_metadata(selector: OptionButton) -> String:
	var selected_index := selector.get_selected_id()
	if selected_index < 0 or selected_index >= selector.item_count:
		return ""
	return String(selector.get_item_metadata(selected_index))


func _should_prepare_manual_local_loop_room() -> bool:
	if _room_controller == null or _app_runtime == null:
		return false
	if _app_runtime.debug_tools == null or not _app_runtime.debug_tools.has_method("ensure_manual_local_loop_room"):
		return false
	if _room_controller.room_session == null:
		return true
	if not _room_controller.room_session.peers.has(_app_runtime.local_peer_id):
		return true
	return _room_controller.room_session.peers.size() == 1 and not _room_controller.room_session.peers.has(_app_runtime.remote_peer_id)
