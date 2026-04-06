extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const BattleContentManifestBuilderScript = preload("res://gameplay/battle/config/battle_content_manifest_builder.gd")
const RoomSelectionBuilderScript = preload("res://gameplay/front/room_selection/room_selection_builder.gd")
const NetworkErrorCodesScript = preload("res://network/runtime/network_error_codes.gd")
const ClientLaunchModeScript = preload("res://network/runtime/client_launch_mode.gd")
const RoomClientGatewayScript = preload("res://network/runtime/room_client_gateway.gd")

@onready var room_hud_controller: RoomHudController = $RoomHudController
@onready var room_root: Control = $RoomRoot
@onready var main_layout: VBoxContainer = $RoomRoot/MainLayout
@onready var title_label: Label = $RoomRoot/MainLayout/TitleLabel
@onready var network_config_panel: VBoxContainer = $RoomRoot/MainLayout/NetworkConfigPanel
@onready var mode_label: Label = $RoomRoot/MainLayout/NetworkConfigPanel/ModeRow/ModeLabel
@onready var mode_selector: OptionButton = $RoomRoot/MainLayout/NetworkConfigPanel/ModeRow/ModeSelector
@onready var connect_button: Button = $RoomRoot/MainLayout/NetworkConfigPanel/ModeRow/ConnectButton
@onready var create_room_button: Button = $RoomRoot/MainLayout/NetworkConfigPanel/ModeRow/CreateRoomButton
@onready var host_label: Label = $RoomRoot/MainLayout/NetworkConfigPanel/ServerRow/HostLabel
@onready var host_input: LineEdit = $RoomRoot/MainLayout/NetworkConfigPanel/ServerRow/HostInput
@onready var port_label: Label = $RoomRoot/MainLayout/NetworkConfigPanel/ServerRow/PortLabel
@onready var port_input: LineEdit = $RoomRoot/MainLayout/NetworkConfigPanel/ServerRow/PortInput
@onready var room_id_label: Label = $RoomRoot/MainLayout/NetworkConfigPanel/ServerRow/RoomIdLabel
@onready var room_id_input: LineEdit = $RoomRoot/MainLayout/NetworkConfigPanel/ServerRow/RoomIdInput
@onready var player_name_label: Label = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/PlayerNameLabel
@onready var player_name_input: LineEdit = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/PlayerNameInput
@onready var character_label: Label = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/CharacterLabel
@onready var character_selector: OptionButton = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/CharacterSelector
@onready var character_skin_label: Label = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/CharacterSkinLabel
@onready var character_skin_selector: OptionButton = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/CharacterSkinSelector
@onready var bubble_label: Label = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/BubbleLabel
@onready var bubble_selector: OptionButton = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/BubbleSelector
@onready var bubble_skin_label: Label = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/BubbleSkinLabel
@onready var bubble_skin_selector: OptionButton = $RoomRoot/MainLayout/NetworkConfigPanel/PlayerRow/BubbleSkinSelector
@onready var member_list: VBoxContainer = $RoomRoot/MainLayout/MemberList
@onready var action_row: Control = $RoomRoot/MainLayout/ActionRow
@onready var ready_button: Button = $RoomRoot/MainLayout/ActionRow/ReadyButton
@onready var start_button: Button = $RoomRoot/MainLayout/ActionRow/StartButton
@onready var selector_row: Control = $RoomRoot/MainLayout/SelectorRow
@onready var map_label: Label = $RoomRoot/MainLayout/SelectorRow/MapLabel
@onready var map_selector: OptionButton = $RoomRoot/MainLayout/SelectorRow/MapSelector
@onready var rule_label: Label = $RoomRoot/MainLayout/SelectorRow/RuleLabel
@onready var rule_selector: OptionButton = $RoomRoot/MainLayout/SelectorRow/RuleSelector
@onready var game_mode_label: Label = $RoomRoot/MainLayout/SelectorRow/GameModeLabel
@onready var game_mode_selector: OptionButton = $RoomRoot/MainLayout/SelectorRow/GameModeSelector
@onready var map_preview_label: Label = $RoomRoot/MainLayout/SelectionPreviewPanel/MapPreviewLabel
@onready var rule_preview_label: Label = $RoomRoot/MainLayout/SelectionPreviewPanel/RulePreviewLabel
@onready var selection_preview_panel: VBoxContainer = $RoomRoot/MainLayout/SelectionPreviewPanel
@onready var character_preview_label: Label = $RoomRoot/MainLayout/SelectionPreviewPanel/CharacterPreviewLabel
@onready var character_preview_viewport: RoomCharacterPreview = $RoomRoot/MainLayout/SelectionPreviewPanel/CharacterPreviewViewport
@onready var character_skin_preview_label: Label = $RoomRoot/MainLayout/SelectionPreviewPanel/CharacterSkinPreviewLabel
@onready var character_skin_icon: TextureRect = $RoomRoot/MainLayout/SelectionPreviewPanel/CharacterSkinIcon
@onready var bubble_preview_label: Label = $RoomRoot/MainLayout/SelectionPreviewPanel/BubblePreviewLabel
@onready var bubble_skin_preview_label: Label = $RoomRoot/MainLayout/SelectionPreviewPanel/BubbleSkinPreviewLabel
@onready var bubble_skin_icon: TextureRect = $RoomRoot/MainLayout/SelectionPreviewPanel/BubbleSkinIcon
@onready var mode_preview_label: Label = $RoomRoot/MainLayout/SelectionPreviewPanel/ModePreviewLabel
@onready var room_debug_panel: PanelContainer = $RoomRoot/MainLayout/RoomDebugPanel
@onready var debug_label: Label = $RoomRoot/MainLayout/RoomDebugPanel/DebugLabel

var _app_runtime: Node = null
var _room_controller: Node = null
var _front_flow: Node = null
var _coordinator: Node = null
var _client_room_runtime: Node = null
var _room_client_gateway: Node = null
var _suppress_selection_callbacks: bool = false
var _content_manifest_builder = BattleContentManifestBuilderScript.new()


func _ready() -> void:
	_configure_layout()
	_populate_selectors()
	call_deferred("_initialize_runtime")


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_update_summary_layout_mode()


func _initialize_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	_room_controller = _app_runtime.room_session_controller
	_front_flow = _app_runtime.front_flow
	_coordinator = _app_runtime.match_start_coordinator
	_client_room_runtime = _app_runtime.client_room_runtime
	_ensure_room_client_gateway()
	_connect_runtime_signals()
	_apply_runtime_config_to_ui()
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
	if _room_client_gateway != null:
		if _room_client_gateway.transport_connected.is_connected(_on_network_transport_connected):
			_room_client_gateway.transport_connected.disconnect(_on_network_transport_connected)
		if _room_client_gateway.room_snapshot_received.is_connected(_on_network_room_snapshot_received):
			_room_client_gateway.room_snapshot_received.disconnect(_on_network_room_snapshot_received)
		if _room_client_gateway.room_error.is_connected(_on_network_room_error):
			_room_client_gateway.room_error.disconnect(_on_network_room_error)
		if _room_client_gateway.canonical_start_config_received.is_connected(_on_canonical_start_config_received):
			_room_client_gateway.canonical_start_config_received.disconnect(_on_canonical_start_config_received)


func _configure_layout() -> void:
	room_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_scroll_layout()
	_materialize_section_cards()
	_ensure_summary_split()
	main_layout.add_theme_constant_override("separation", 16)
	network_config_panel.add_theme_constant_override("separation", 8)
	member_list.add_theme_constant_override("separation", 8)
	var server_row := host_label.get_parent() as Control
	var player_row := player_name_label.get_parent() as Control
	if server_row is FlowContainer:
		server_row.add_theme_constant_override("h_separation", 8)
		server_row.add_theme_constant_override("v_separation", 8)
	if player_row is FlowContainer:
		player_row.add_theme_constant_override("h_separation", 8)
		player_row.add_theme_constant_override("v_separation", 8)
	if selector_row is FlowContainer:
		(selector_row as FlowContainer).add_theme_constant_override("h_separation", 8)
		(selector_row as FlowContainer).add_theme_constant_override("v_separation", 8)
	title_label.text = "QQTang Room"
	mode_label.text = "Mode"
	host_label.text = "Host"
	port_label.text = "Port"
	room_id_label.text = "Room"
	player_name_label.text = "Player"
	character_label.text = "Character"
	character_skin_label.text = "Skin"
	bubble_label.text = "Bubble"
	bubble_skin_label.text = "Bubble Skin"
	map_label.text = "Map"
	rule_label.text = "Rule"
	game_mode_label.text = "Game Mode"
	connect_button.text = "Connect"
	create_room_button.text = "Create/Join Room"
	host_input.placeholder_text = "127.0.0.1"
	port_input.placeholder_text = "9000"
	room_id_input.placeholder_text = "room_id(optional)"
	player_name_input.placeholder_text = "Player1"
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.text = "Initializing room runtime..."
	map_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_skin_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_skin_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_preview_label.text = "地图预览加载中..."
	rule_preview_label.text = "规则预览加载中..."
	character_preview_label.text = "角色预览加载中..."
	character_skin_preview_label.text = "角色皮肤预览加载中..."
	bubble_preview_label.text = "泡泡预览加载中..."
	bubble_skin_preview_label.text = "泡泡皮肤预览加载中..."
	mode_preview_label.text = "模式预览加载中..."
	_configure_preview_icon(character_skin_icon)
	_configure_preview_icon(bubble_skin_icon)
	_style_summary_panels()
	_update_summary_layout_mode()
	_style_primary_actions()


func _populate_selectors() -> void:
	_suppress_selection_callbacks = true
	_populate_mode_selector()
	_populate_character_selector()
	_populate_character_skin_selector()
	_populate_bubble_selector()
	_populate_bubble_skin_selector()
	_populate_map_selector()
	_populate_rule_selector()
	_populate_game_mode_selector()
	_suppress_selection_callbacks = false
	_update_selection_preview(_selected_metadata(map_selector), _selected_metadata(rule_selector))


func _populate_mode_selector() -> void:
	mode_selector.clear()
	_add_selector_item(mode_selector, "Local Singleplayer", str(ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER))
	_add_selector_item(mode_selector, "Network Client", str(ClientLaunchModeScript.Value.NETWORK_CLIENT))


func _populate_character_selector() -> void:
	character_selector.clear()
	CharacterCatalogScript.load_all()
	for entry in CharacterCatalogScript.get_character_entries():
		_add_selector_item(character_selector, String(entry.get("display_name", "")), String(entry.get("id", "")))


func _populate_bubble_selector() -> void:
	bubble_selector.clear()
	BubbleCatalogScript.load_all()
	for entry in BubbleCatalogScript.get_bubble_entries():
		var bubble_id := String(entry.get("id", ""))
		if bubble_id.is_empty():
			continue
		var display_name := String(entry.get("display_name", bubble_id))
		_add_selector_item(bubble_selector, display_name, bubble_id)


func _populate_character_skin_selector() -> void:
	character_skin_selector.clear()
	_add_selector_item(character_skin_selector, "None", "")
	CharacterSkinCatalogScript.load_all()
	for skin_def in CharacterSkinCatalogScript.get_all():
		if skin_def == null:
			continue
		_add_selector_item(character_skin_selector, String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_def.skin_id), skin_def.skin_id)


func _populate_bubble_skin_selector() -> void:
	bubble_skin_selector.clear()
	_add_selector_item(bubble_skin_selector, "None", "")
	BubbleSkinCatalogScript.load_all()
	for skin_def in BubbleSkinCatalogScript.get_all():
		if skin_def == null:
			continue
		_add_selector_item(bubble_skin_selector, String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_def.bubble_skin_id), skin_def.bubble_skin_id)


func _populate_map_selector() -> void:
	map_selector.clear()
	MapCatalogScript.load_all()
	for entry in MapCatalogScript.get_map_entries():
		var map_id := String(entry.get("id", ""))
		if map_id.is_empty():
			continue
		var display_name := String(entry.get("display_name", map_id))
		_add_selector_item(map_selector, display_name, map_id)


func _populate_rule_selector() -> void:
	rule_selector.clear()
	RuleSetCatalogScript.load_all()
	for entry in RuleSetCatalogScript.get_rule_entries():
		var rule_id := String(entry.get("id", ""))
		if rule_id.is_empty():
			continue
		var display_name := String(entry.get("display_name", rule_id))
		_add_selector_item(rule_selector, display_name, rule_id)


func _populate_game_mode_selector() -> void:
	game_mode_selector.clear()
	ModeCatalogScript.load_all()
	for entry in ModeCatalogScript.get_mode_entries():
		var mode_id := String(entry.get("mode_id", entry.get("id", "")))
		if mode_id.is_empty():
			continue
		var display_name := String(entry.get("display_name", mode_id))
		_add_selector_item(game_mode_selector, display_name, mode_id)


func _connect_runtime_signals() -> void:
	if _room_controller != null:
		if not _room_controller.room_snapshot_changed.is_connected(_on_room_snapshot_changed):
			_room_controller.room_snapshot_changed.connect(_on_room_snapshot_changed)
		if not _room_controller.start_match_requested.is_connected(_on_start_match_requested):
			_room_controller.start_match_requested.connect(_on_start_match_requested)
	if _room_client_gateway != null:
		if not _room_client_gateway.transport_connected.is_connected(_on_network_transport_connected):
			_room_client_gateway.transport_connected.connect(_on_network_transport_connected)
		if not _room_client_gateway.room_snapshot_received.is_connected(_on_network_room_snapshot_received):
			_room_client_gateway.room_snapshot_received.connect(_on_network_room_snapshot_received)
		if not _room_client_gateway.room_error.is_connected(_on_network_room_error):
			_room_client_gateway.room_error.connect(_on_network_room_error)
		if not _room_client_gateway.canonical_start_config_received.is_connected(_on_canonical_start_config_received):
			_room_client_gateway.canonical_start_config_received.connect(_on_canonical_start_config_received)

	if not ready_button.pressed.is_connected(_on_ready_button_pressed):
		ready_button.pressed.connect(_on_ready_button_pressed)
	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
	if not map_selector.item_selected.is_connected(_on_map_selected):
		map_selector.item_selected.connect(_on_map_selected)
	if not rule_selector.item_selected.is_connected(_on_rule_selected):
		rule_selector.item_selected.connect(_on_rule_selected)
	if not character_selector.item_selected.is_connected(_on_character_selected):
		character_selector.item_selected.connect(_on_character_selected)
	if not character_skin_selector.item_selected.is_connected(_on_character_skin_selected):
		character_skin_selector.item_selected.connect(_on_character_skin_selected)
	if not bubble_selector.item_selected.is_connected(_on_bubble_selected):
		bubble_selector.item_selected.connect(_on_bubble_selected)
	if not bubble_skin_selector.item_selected.is_connected(_on_bubble_skin_selected):
		bubble_skin_selector.item_selected.connect(_on_bubble_skin_selected)
	if not game_mode_selector.item_selected.is_connected(_on_game_mode_selected):
		game_mode_selector.item_selected.connect(_on_game_mode_selected)
	if not mode_selector.item_selected.is_connected(_on_mode_selected):
		mode_selector.item_selected.connect(_on_mode_selected)
	if not connect_button.pressed.is_connected(_on_connect_button_pressed):
		connect_button.pressed.connect(_on_connect_button_pressed)
	if not create_room_button.pressed.is_connected(_on_create_room_button_pressed):
		create_room_button.pressed.connect(_on_create_room_button_pressed)


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
	if character_selector.item_count > 0 and character_selector.selected < 0:
		_select_metadata(character_selector, String(CharacterCatalogScript.get_default_character_id()))
	if game_mode_selector.item_count > 0 and game_mode_selector.selected < 0:
		_select_metadata(game_mode_selector, String(ModeCatalogScript.get_default_mode_id()))
	if character_skin_selector.item_count > 0 and character_skin_selector.selected < 0:
		_select_metadata(character_skin_selector, "")
	if bubble_selector.item_count > 0 and bubble_selector.selected < 0:
		_select_metadata(bubble_selector, String(BubbleCatalogScript.get_default_bubble_id()))
	if bubble_skin_selector.item_count > 0 and bubble_skin_selector.selected < 0:
		_select_metadata(bubble_skin_selector, "")
	_update_selection_preview(snapshot.selected_map_id, snapshot.rule_set_id)

	var local_ready := bool(_room_controller.room_session.ready_state.get(_app_runtime.local_peer_id, false))
	ready_button.text = "Cancel Ready" if local_ready else "Ready"
	start_button.text = "Start Match"
	start_button.disabled = not _room_controller.can_request_start_match(_app_runtime.local_peer_id)
	create_room_button.disabled = false
	connect_button.disabled = false
	_apply_runtime_config_to_ui()

	var lines: PackedStringArray = PackedStringArray()
	if room_hud_controller != null:
		lines = PackedStringArray(room_hud_controller.build_debug_text(snapshot, _front_flow.get_state_name()).split("\n"))
	elif _app_runtime != null and _app_runtime.session_diagnostics != null:
		lines = _app_runtime.session_diagnostics.build_room_debug_lines(_app_runtime, String(_front_flow.get_state_name()))
	else:
		lines = PackedStringArray([
			"Room: %s" % snapshot.room_id,
			"Match: %s" % String(_room_controller.room_runtime_context.pending_match_id if _room_controller != null and _room_controller.room_runtime_context != null else ""),
			"Map: %s" % snapshot.selected_map_id,
			"Rule: %s" % snapshot.rule_set_id,
			"RoomFlow: %s" % String(_room_controller.get_room_flow_state_name() if _room_controller != null and _room_controller.has_method("get_room_flow_state_name") else "UNKNOWN"),
			"SessionFlow: %s" % String(_room_controller.get_session_lifecycle_state_name() if _room_controller != null and _room_controller.has_method("get_session_lifecycle_state_name") else "UNKNOWN"),
			"FrontFlow: %s" % String(_front_flow.get_state_name()),
			"AllReady: %s" % str(snapshot.all_ready),
		])
	for extra_line in _build_connection_debug_lines():
		lines.append(extra_line)
	debug_label.text = "\n".join(lines)


func _build_connection_debug_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if _app_runtime == null or _app_runtime.runtime_config == null:
		return lines
	var runtime_config = _app_runtime.runtime_config
	var connection = runtime_config.client_connection
	lines.append("LaunchMode: %s" % _launch_mode_to_string(int(runtime_config.launch_mode)))
	if connection != null:
		lines.append("Authority: %s:%d" % [connection.server_host, connection.server_port])
		lines.append("RoomHint: %s" % connection.room_id_hint)
		lines.append("PlayerProfile: %s / %s / %s" % [connection.player_name, connection.selected_character_id, connection.selected_bubble_style_id])
		lines.append("PlayerSkins: %s / %s" % [connection.selected_character_skin_id, connection.selected_bubble_skin_id])
		lines.append("GameMode: %s" % connection.selected_mode_id)
	return lines


func _add_selector_item(selector: OptionButton, title: String, value: String) -> void:
	selector.add_item(title)
	selector.set_item_metadata(selector.item_count - 1, value)


func _select_metadata(selector: OptionButton, value: String) -> void:
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) == value:
			selector.select(index)
			return


func _apply_runtime_config_to_ui() -> void:
	if _app_runtime == null or _app_runtime.runtime_config == null:
		return
	var runtime_config = _app_runtime.runtime_config
	var launch_mode := int(runtime_config.launch_mode)
	if launch_mode == ClientLaunchModeScript.Value.TRANSPORT_DEBUG:
		launch_mode = ClientLaunchModeScript.Value.NETWORK_CLIENT
	_select_metadata(mode_selector, str(launch_mode))
	if runtime_config.client_connection == null:
		return
	var connection = runtime_config.client_connection
	host_input.text = connection.server_host
	port_input.text = str(connection.server_port)
	room_id_input.text = connection.room_id_hint
	player_name_input.text = connection.player_name
	_select_metadata(character_selector, connection.selected_character_id)
	if character_selector.selected < 0:
		_select_metadata(character_selector, String(CharacterCatalogScript.get_default_character_id()))
	_select_metadata(character_skin_selector, connection.selected_character_skin_id)
	if character_skin_selector.selected < 0:
		_select_metadata(character_skin_selector, String(CharacterSkinCatalogScript.get_default_skin_id()))
	_select_metadata(bubble_selector, connection.selected_bubble_style_id)
	if bubble_selector.selected < 0:
		_select_metadata(bubble_selector, String(BubbleCatalogScript.get_default_bubble_id()))
	_select_metadata(bubble_skin_selector, connection.selected_bubble_skin_id)
	if bubble_skin_selector.selected < 0:
		_select_metadata(bubble_skin_selector, String(BubbleSkinCatalogScript.get_default_skin_id()))
	_select_metadata(game_mode_selector, connection.selected_mode_id)
	if game_mode_selector.selected < 0:
		_select_metadata(game_mode_selector, String(ModeCatalogScript.get_default_mode_id()))
	_update_selection_preview(_selected_metadata(map_selector), _selected_metadata(rule_selector))
	_update_network_controls_for_mode(launch_mode)


func _apply_connection_config_from_ui() -> void:
	if _app_runtime == null or _app_runtime.runtime_config == null:
		return
	var runtime_config = _app_runtime.runtime_config
	var selected_mode := int(_selected_metadata(mode_selector).to_int())
	runtime_config.launch_mode = selected_mode
	runtime_config.transport_debug_enabled = false
	if runtime_config.client_connection == null:
		return
	var connection = runtime_config.client_connection
	connection.server_host = host_input.text.strip_edges() if not host_input.text.strip_edges().is_empty() else "127.0.0.1"
	var parsed_port := int(port_input.text.strip_edges().to_int())
	connection.server_port = parsed_port if parsed_port > 0 else 9000
	connection.room_id_hint = room_id_input.text.strip_edges()
	connection.player_name = player_name_input.text.strip_edges() if not player_name_input.text.strip_edges().is_empty() else "Player%d" % _app_runtime.local_peer_id
	connection.selected_character_id = _selected_metadata(character_selector)
	connection.selected_character_skin_id = _selected_metadata(character_skin_selector)
	connection.selected_bubble_style_id = _selected_metadata(bubble_selector)
	connection.selected_bubble_skin_id = _selected_metadata(bubble_skin_selector)
	connection.selected_mode_id = _selected_metadata(game_mode_selector)
	_update_network_controls_for_mode(selected_mode)


func _update_network_controls_for_mode(mode: int) -> void:
	var is_network_mode := mode == ClientLaunchModeScript.Value.NETWORK_CLIENT
	host_input.editable = is_network_mode
	port_input.editable = is_network_mode
	room_id_input.editable = is_network_mode
	connect_button.disabled = false
	create_room_button.text = "Create/Join Room" if is_network_mode else "Create Local Room"


func _on_room_snapshot_changed(snapshot: RoomSnapshot) -> void:
	_refresh_room(snapshot)


func _on_start_match_requested(snapshot: RoomSnapshot) -> void:
	if _selected_launch_mode() == ClientLaunchModeScript.Value.NETWORK_CLIENT and _room_client_gateway != null:
		_room_client_gateway.request_start_match()
		return
	var config: BattleStartConfig = _app_runtime.build_and_store_start_config(snapshot)
	if config == null or config.match_id.is_empty():
		var last_error: Dictionary = _app_runtime.last_runtime_error if _app_runtime != null else {}
		debug_label.text = String(last_error.get("user_message", "Failed to build start config"))
		return
	_front_flow.request_start_match()


func _on_ready_button_pressed() -> void:
	if _room_controller == null or _app_runtime == null:
		return
	_apply_connection_config_from_ui()
	var selected_map_id := _selected_metadata(map_selector)
	var selected_rule_id := _selected_metadata(rule_selector)
	if _selected_launch_mode() == ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER:
		_app_runtime.set_local_peer_id(1)
		_ensure_local_room_created()
		_apply_local_profile_to_room()
	elif _room_client_gateway != null:
		_room_client_gateway.request_update_profile(
			_app_runtime.runtime_config.client_connection.player_name,
			_app_runtime.runtime_config.client_connection.selected_character_id,
			_app_runtime.runtime_config.client_connection.selected_character_skin_id,
			_app_runtime.runtime_config.client_connection.selected_bubble_style_id,
			_app_runtime.runtime_config.client_connection.selected_bubble_skin_id
		)
		_room_client_gateway.request_toggle_ready()
		return
	if _should_prepare_manual_local_loop_room():
		_app_runtime.debug_tools.ensure_manual_local_loop_room(
			_room_controller,
			_app_runtime.local_peer_id,
			_app_runtime.remote_peer_id,
			selected_map_id,
			selected_rule_id
		)
	var result: Dictionary = _room_controller.request_toggle_ready(_app_runtime.local_peer_id) if _room_controller.has_method("request_toggle_ready") else {"ok": false}
	if not bool(result.get("ok", false)):
		debug_label.text = String(result.get("user_message", "Failed to toggle ready"))


func _on_start_button_pressed() -> void:
	if _room_controller == null or _app_runtime == null:
		return
	_apply_connection_config_from_ui()
	if _selected_launch_mode() == ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER:
		_app_runtime.set_local_peer_id(1)
		_apply_local_profile_to_room()
	elif _room_client_gateway != null:
		_room_client_gateway.request_start_match()
		return
	var result: Dictionary = _room_controller.request_begin_match(_app_runtime.local_peer_id) if _room_controller.has_method("request_begin_match") else {}
	if not bool(result.get("ok", false)):
		if _app_runtime.error_router != null:
			_app_runtime.error_router.route_error(
				_app_runtime,
				String(result.get("error_code", NetworkErrorCodesScript.ROOM_START_FORBIDDEN)),
				"room",
				"start_button_pressed",
				String(result.get("user_message", "Unable to start match")),
				{
					"room_snapshot": _room_controller.build_room_snapshot().to_dict(),
					"requester_peer_id": _app_runtime.local_peer_id,
				},
				"stay_in_room",
				true
			)
		return


func _on_map_selected(index: int) -> void:
	if _suppress_selection_callbacks or _room_controller == null or _app_runtime == null:
		return
	var selected_map_id := String(map_selector.get_item_metadata(index))
	_update_selection_preview(selected_map_id, _selected_metadata(rule_selector))
	if _selected_launch_mode() == ClientLaunchModeScript.Value.NETWORK_CLIENT and _room_client_gateway != null:
		_room_client_gateway.request_update_selection(
			selected_map_id,
			_selected_metadata(rule_selector)
		)
		return
	_room_controller.request_update_selection(
		_app_runtime.local_peer_id,
		selected_map_id,
		_selected_metadata(rule_selector)
	)


func _on_character_selected(_index: int) -> void:
	if _suppress_selection_callbacks:
		return
	_apply_connection_config_from_ui()
	_push_local_profile_update()
	_update_selection_preview(_selected_metadata(map_selector), _selected_metadata(rule_selector))


func _on_character_skin_selected(_index: int) -> void:
	if _suppress_selection_callbacks:
		return
	_apply_connection_config_from_ui()
	_push_local_profile_update()
	_update_selection_preview(_selected_metadata(map_selector), _selected_metadata(rule_selector))


func _on_rule_selected(index: int) -> void:
	if _suppress_selection_callbacks or _room_controller == null or _app_runtime == null:
		return
	var selected_rule_id := String(rule_selector.get_item_metadata(index))
	_update_selection_preview(_selected_metadata(map_selector), selected_rule_id)
	if _selected_launch_mode() == ClientLaunchModeScript.Value.NETWORK_CLIENT and _room_client_gateway != null:
		_room_client_gateway.request_update_selection(
			_selected_metadata(map_selector),
			selected_rule_id
		)
		return
	_room_controller.request_update_selection(
		_app_runtime.local_peer_id,
		_selected_metadata(map_selector),
		selected_rule_id
	)


func _on_mode_selected(_index: int) -> void:
	if _suppress_selection_callbacks or _room_controller == null:
		return
	_apply_connection_config_from_ui()
	_refresh_room(_room_controller.build_room_snapshot())


func _on_bubble_selected(_index: int) -> void:
	if _suppress_selection_callbacks:
		return
	_apply_connection_config_from_ui()
	_push_local_profile_update()
	_update_selection_preview(_selected_metadata(map_selector), _selected_metadata(rule_selector))


func _on_bubble_skin_selected(_index: int) -> void:
	if _suppress_selection_callbacks:
		return
	_apply_connection_config_from_ui()
	_push_local_profile_update()
	_update_selection_preview(_selected_metadata(map_selector), _selected_metadata(rule_selector))


func _on_game_mode_selected(_index: int) -> void:
	if _suppress_selection_callbacks:
		return
	_update_selection_preview(_selected_metadata(map_selector), _selected_metadata(rule_selector))


func _on_connect_button_pressed() -> void:
	if _app_runtime == null:
		return
	_apply_connection_config_from_ui()
	if _selected_launch_mode() == ClientLaunchModeScript.Value.NETWORK_CLIENT:
		var candidate_config: BattleStartConfig = _coordinator.build_client_request_payload(
			_room_controller.build_room_snapshot(),
			_app_runtime.local_peer_id,
			_app_runtime.runtime_config.client_connection.server_host,
			_app_runtime.runtime_config.client_connection.server_port
		) if _coordinator != null and _coordinator.has_method("build_client_request_payload") else null
		_app_runtime.current_start_config = candidate_config
		if _room_client_gateway != null:
			_room_client_gateway.connect_to_server(_app_runtime.runtime_config.client_connection)
		debug_label.text = "Connecting to dedicated server...\n" + debug_label.text
	else:
		debug_label.text = "Local singleplayer mode does not require remote connect.\n" + debug_label.text


func _on_create_room_button_pressed() -> void:
	if _room_controller == null or _app_runtime == null:
		return
	_apply_connection_config_from_ui()
	if _selected_launch_mode() == ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER:
		_app_runtime.set_local_peer_id(1)
		_ensure_local_room_created()
		_apply_local_profile_to_room()
		_room_controller.set_room_selection(_selected_metadata(map_selector), _selected_metadata(rule_selector))
		_refresh_room(_room_controller.build_room_snapshot())
		return
	if _room_client_gateway != null:
		_room_client_gateway.request_join_room(_app_runtime.runtime_config.client_connection)
		debug_label.text = "Requesting dedicated server room join...\n" + debug_label.text


func _on_network_transport_connected() -> void:
	debug_label.text = "Dedicated server transport connected.\n" + debug_label.text


func _on_network_room_snapshot_received(snapshot: RoomSnapshot) -> void:
	if _room_controller != null and _room_controller.has_method("apply_authoritative_snapshot"):
		_room_controller.apply_authoritative_snapshot(snapshot)
	if _app_runtime != null:
		_app_runtime.current_room_snapshot = snapshot.duplicate_deep()


func _on_network_room_error(_error_code: String, user_message: String) -> void:
	debug_label.text = "%s\n%s" % [user_message, debug_label.text]


func _on_canonical_start_config_received(config: BattleStartConfig) -> void:
	if _app_runtime == null or config == null:
		return
	_app_runtime.apply_canonical_start_config(config)
	_front_flow.request_start_match()


func _ensure_room_client_gateway() -> void:
	if _app_runtime == null:
		return
	if _room_client_gateway == null or not is_instance_valid(_room_client_gateway):
		_room_client_gateway = RoomClientGatewayScript.new()
		_room_client_gateway.name = "RoomClientGateway"
		_app_runtime.session_root.add_child(_room_client_gateway)
	elif _room_client_gateway.get_parent() != _app_runtime.session_root:
		var old_parent := _room_client_gateway.get_parent()
		if old_parent != null:
			old_parent.remove_child(_room_client_gateway)
		_app_runtime.session_root.add_child(_room_client_gateway)
	if _room_client_gateway != null and _room_client_gateway.has_method("bind_runtime"):
		_room_client_gateway.bind_runtime(_app_runtime, _client_room_runtime)


func _ensure_local_room_created() -> void:
	if _room_controller == null or _app_runtime == null:
		return
	if _room_controller.room_session != null and _room_controller.room_session.peers.has(_app_runtime.local_peer_id):
		return
	_room_controller.create_room(_app_runtime.local_peer_id)


func _apply_local_profile_to_room() -> void:
	if _room_controller == null or _app_runtime == null or _app_runtime.runtime_config == null:
		return
	if _room_controller.room_session == null or not _room_controller.room_session.peers.has(_app_runtime.local_peer_id):
		return
	var connection = _app_runtime.runtime_config.client_connection
	if connection == null:
		return
	if _room_controller.has_method("request_update_member_profile"):
		_room_controller.request_update_member_profile(
			_app_runtime.local_peer_id,
			connection.player_name,
			connection.selected_character_id,
			connection.selected_character_skin_id,
			connection.selected_bubble_style_id,
			connection.selected_bubble_skin_id
		)


func _push_local_profile_update() -> void:
	if _app_runtime == null or _app_runtime.runtime_config == null:
		return
	var connection = _app_runtime.runtime_config.client_connection
	if connection == null:
		return
	if _selected_launch_mode() == ClientLaunchModeScript.Value.NETWORK_CLIENT:
		if _room_client_gateway != null:
			_room_client_gateway.request_update_profile(
				connection.player_name,
				connection.selected_character_id,
				connection.selected_character_skin_id,
				connection.selected_bubble_style_id,
				connection.selected_bubble_skin_id
			)
		return
	_apply_local_profile_to_room()


func _selected_metadata(selector: OptionButton) -> String:
	var selected_index := selector.get_selected_id()
	if selected_index < 0 or selected_index >= selector.item_count:
		return ""
	return String(selector.get_item_metadata(selected_index))


func _selected_launch_mode() -> int:
	return int(_selected_metadata(mode_selector).to_int())


func _should_prepare_manual_local_loop_room() -> bool:
	if _room_controller == null or _app_runtime == null:
		return false
	if _selected_launch_mode() != ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER:
		return false
	if _app_runtime.debug_tools == null or not _app_runtime.debug_tools.has_method("ensure_manual_local_loop_room"):
		return false
	if _room_controller.room_session == null:
		return true
	if not _room_controller.room_session.peers.has(_app_runtime.local_peer_id):
		return true
	return _room_controller.room_session.peers.size() == 1 and not _room_controller.room_session.peers.has(_app_runtime.remote_peer_id)


func _launch_mode_to_string(mode: int) -> String:
	match mode:
		ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER:
			return "LOCAL_SINGLEPLAYER"
		ClientLaunchModeScript.Value.NETWORK_CLIENT:
			return "NETWORK_CLIENT"
		ClientLaunchModeScript.Value.TRANSPORT_DEBUG:
			return "TRANSPORT_DEBUG"
		_:
			return "UNKNOWN"


func _update_selection_preview(map_id: String, rule_id: String) -> void:
	var selected_character_id := _selected_metadata(character_selector)
	var selected_character_skin_id := _selected_metadata(character_skin_selector)
	var local_peer_id := int(_app_runtime.local_peer_id if _app_runtime != null else 1)
	var room_selection := RoomSelectionBuilderScript.build_selection_state(
		_selected_metadata(game_mode_selector),
		map_id,
		rule_id,
		[
			{
				"peer_id": int(_app_runtime.local_peer_id if _app_runtime != null else 1),
				"character_id": selected_character_id,
				"character_skin_id": selected_character_skin_id,
				"bubble_style_id": _selected_metadata(bubble_selector),
				"bubble_skin_id": _selected_metadata(bubble_skin_selector),
				"ready": false,
			}
		]
	)
	var players : Dictionary = room_selection.get("players", {})
	var local_player : Dictionary = players.get(local_peer_id, {})
	var preview_character_id := String(local_player.get("character_id", selected_character_id))
	var preview_skin_id := String(local_player.get("character_skin_id", selected_character_skin_id))
	map_preview_label.text = _build_map_preview_text(map_id)
	rule_preview_label.text = _build_rule_preview_text(rule_id)
	character_preview_label.text = _build_character_preview_text(preview_character_id)
	character_skin_preview_label.text = _build_character_skin_preview_text(preview_skin_id)
	_update_character_preview_visual(preview_character_id, preview_skin_id)
	bubble_preview_label.text = _build_bubble_preview_text(String(local_player.get("bubble_style_id", _selected_metadata(bubble_selector))))
	bubble_skin_preview_label.text = _build_bubble_skin_preview_text(String(local_player.get("bubble_skin_id", _selected_metadata(bubble_skin_selector))))
	mode_preview_label.text = _build_mode_preview_text(String(room_selection.get("mode_id", _selected_metadata(game_mode_selector))), rule_id)
	_update_character_skin_icon(selected_character_skin_id)
	_update_bubble_skin_icon(_selected_metadata(bubble_skin_selector))


func _update_character_preview_visual(character_id: String, skin_id: String) -> void:
	if character_preview_viewport == null:
		return
	if not character_preview_viewport.has_method("configure_preview"):
		return
	character_preview_viewport.configure_preview(character_id, skin_id)


func _build_map_preview_text(map_id: String) -> String:
	var manifest: Dictionary = _content_manifest_builder.build_preview_manifest(map_id, _selected_metadata(rule_selector))
	var map_manifest: Dictionary = manifest.get("map", {})
	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	if map_manifest.is_empty():
		return "地图: %s\n暂无地图摘要" % map_id
	var display_name := String(map_manifest.get("display_name", map_id))
	var tags := PackedStringArray(map_manifest.get("tags", []))
	var item_brief := String(ui_summary.get("item_brief", ""))
	if not item_brief.is_empty():
		return "地图: %s\n%s\n%s" % [display_name, " | ".join(tags), item_brief]
	return "地图: %s\n%s" % [display_name, " | ".join(tags)]


func _build_rule_preview_text(rule_id: String) -> String:
	var manifest: Dictionary = _content_manifest_builder.build_preview_manifest(_selected_metadata(map_selector), rule_id)
	var rule_manifest: Dictionary = manifest.get("rule", {})
	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	if rule_manifest.is_empty():
		return "规则: %s\n暂无规则摘要" % rule_id
	var display_name := String(rule_manifest.get("display_name", rule_id))
	var description := String(rule_manifest.get("description", "")).strip_edges()
	var summary := String(rule_manifest.get("brief", ""))
	var item_brief := String(ui_summary.get("item_brief", ""))
	if not description.is_empty():
		if not item_brief.is_empty():
			return "规则: %s\n%s\n%s\n%s" % [display_name, description, summary, item_brief]
		return "规则: %s\n%s\n%s" % [display_name, description, summary]
	if not item_brief.is_empty():
		return "规则: %s\n%s\n%s" % [display_name, summary, item_brief]
	return "规则: %s\n%s" % [display_name, summary]


func _build_character_preview_text(character_id: String) -> String:
	var character_entry := _find_entry_by_id(CharacterCatalogScript.get_character_entries(), character_id)
	if character_entry.is_empty():
		return "角色: %s\n暂无角色摘要" % character_id
	return "角色: %s | 炸弹:%d 火力:%d 速度:%d" % [
		String(character_entry.get("display_name", character_id)),
		int(character_entry.get("base_bomb_count", 0)),
		int(character_entry.get("base_firepower", 0)),
		int(character_entry.get("base_move_speed", 0)),
	]


func _build_bubble_preview_text(bubble_id: String) -> String:
	var bubble_entry := _find_entry_by_id(BubbleCatalogScript.get_bubble_entries(), bubble_id)
	if bubble_entry.is_empty():
		return "泡泡: %s\n暂无泡泡摘要" % bubble_id
	return "泡泡: %s | 风格: %s" % [
		String(bubble_entry.get("display_name", bubble_id)),
		bubble_id,
	]


func _build_character_skin_preview_text(skin_id: String) -> String:
	if skin_id.is_empty():
		return "角色皮肤: None"
	var skin_def := CharacterSkinCatalogScript.get_by_id(skin_id)
	if skin_def == null:
		return "角色皮肤: %s\n暂无角色皮肤摘要" % skin_id
	return "角色皮肤: %s | 稀有度: %s" % [
		String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_id),
		String(skin_def.rarity if not skin_def.rarity.is_empty() else "normal"),
	]


func _build_bubble_skin_preview_text(skin_id: String) -> String:
	if skin_id.is_empty():
		return "泡泡皮肤: None"
	var skin_def := BubbleSkinCatalogScript.get_by_id(skin_id)
	if skin_def == null:
		return "泡泡皮肤: %s\n暂无泡泡皮肤摘要" % skin_id
	return "泡泡皮肤: %s | 标签: %s" % [
		String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_id),
		", ".join(PackedStringArray(skin_def.tags)),
	]


func _build_mode_preview_text(mode_id: String, rule_id: String) -> String:
	var mode_entry := _find_entry_by_id(ModeCatalogScript.get_mode_entries(), mode_id, "mode_id")
	if mode_entry.is_empty():
		return "模式: %s\n暂无模式摘要" % mode_id
	return "模式: %s | 规则: %s | 人数: %d-%d" % [
		String(mode_entry.get("display_name", mode_id)),
		String(mode_entry.get("rule_set_id", rule_id)),
		int(mode_entry.get("min_player_count", 1)),
		int(mode_entry.get("max_player_count", 4)),
	]


func _find_entry_by_id(entries: Array, entry_id: String, key_name: String = "id") -> Dictionary:
	for entry in entries:
		if not entry is Dictionary:
			continue
		var dict_entry: Dictionary = entry
		var candidate_id := String(dict_entry.get(key_name, dict_entry.get("id", "")))
		if candidate_id == entry_id:
			return dict_entry
	return {}


func _configure_preview_icon(icon_rect: TextureRect) -> void:
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = null
	icon_rect.visible = false


func _update_character_skin_icon(skin_id: String) -> void:
	if skin_id.is_empty():
		_set_preview_icon(character_skin_icon, null)
		return
	var resolved_skin_id := skin_id if CharacterSkinCatalogScript.has_id(skin_id) else ""
	var skin_def := CharacterSkinCatalogScript.get_by_id(resolved_skin_id)
	_set_preview_icon(character_skin_icon, skin_def.ui_icon if skin_def != null else null)


func _update_bubble_skin_icon(skin_id: String) -> void:
	if skin_id.is_empty():
		_set_preview_icon(bubble_skin_icon, null)
		return
	var resolved_skin_id := skin_id if BubbleSkinCatalogScript.has_id(skin_id) else ""
	var skin_def := BubbleSkinCatalogScript.get_by_id(resolved_skin_id)
	_set_preview_icon(bubble_skin_icon, skin_def.icon if skin_def != null else null)


func _set_preview_icon(icon_rect: TextureRect, texture: Texture2D) -> void:
	icon_rect.texture = texture
	icon_rect.visible = texture != null


func _ensure_scroll_layout() -> void:
	var scroll: ScrollContainer = room_root.get_node_or_null("RoomScroll") as ScrollContainer
	var margin: MarginContainer = null
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "RoomScroll"
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		room_root.add_child(scroll)
		room_root.move_child(scroll, 0)

		margin = MarginContainer.new()
		margin.name = "RoomMargin"
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_top", 24)
		margin.add_theme_constant_override("margin_right", 24)
		margin.add_theme_constant_override("margin_bottom", 24)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(margin)

		var current_parent := main_layout.get_parent()
		if current_parent != null:
			current_parent.remove_child(main_layout)
		margin.add_child(main_layout)
	else:
		margin = scroll.get_node_or_null("RoomMargin") as MarginContainer

	if scroll != null:
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	if margin != null:
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_layout.offset_left = 0.0
	main_layout.offset_top = 0.0
	main_layout.offset_right = 0.0
	main_layout.offset_bottom = 0.0


func _ensure_summary_split() -> void:
	var summary_split: BoxContainer = main_layout.get_node_or_null("SummarySplit") as BoxContainer
	if summary_split == null:
		summary_split = HBoxContainer.new()
		summary_split.name = "SummarySplit"
		summary_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		summary_split.add_theme_constant_override("separation", 12)
		main_layout.add_child(summary_split)
		main_layout.move_child(summary_split, main_layout.get_children().find(selection_preview_panel))
		main_layout.remove_child(selection_preview_panel)
		summary_split.add_child(selection_preview_panel)
		main_layout.remove_child(room_debug_panel)
		summary_split.add_child(room_debug_panel)
	else:
		summary_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_split.size_flags_vertical = Control.SIZE_EXPAND_FILL

	selection_preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_preview_panel.custom_minimum_size = Vector2(320, 0)
	room_debug_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_debug_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_debug_panel.custom_minimum_size = Vector2(320, 220)


func _materialize_section_cards() -> void:
	_wrap_main_layout_section("ConnectionCard", "连接与玩家", [network_config_panel])
	_wrap_main_layout_section("LobbyCard", "房间成员", [member_list, action_row])
	_wrap_main_layout_section("MatchConfigCard", "对局配置", [selector_row])


func _wrap_main_layout_section(card_name: String, title: String, sections: Array) -> void:
	if main_layout.get_node_or_null(card_name) != null:
		return
	if sections.is_empty():
		return
	var first_node := sections[0] as Node
	if first_node == null or first_node.get_parent() != main_layout:
		return
	var insert_index := first_node.get_index()
	var card := PanelContainer.new()
	card.name = card_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.add_child(card)
	main_layout.move_child(card, insert_index)

	var style := StyleBoxFlat.new()
	style.bg_color = Color("1c2333")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("32415c")
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 14
	style.content_margin_top = 14
	style.content_margin_right = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)

	var header := Label.new()
	header.name = "Header"
	header.text = title
	header.add_theme_font_size_override("font_size", 18)
	header.modulate = Color("dfe9ff")
	content.add_child(header)

	for section in sections:
		var control := section as Control
		if control == null:
			continue
		main_layout.remove_child(control)
		content.add_child(control)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _style_summary_panels() -> void:
	selection_preview_panel.add_theme_constant_override("separation", 8)
	selection_preview_panel.add_theme_constant_override("outline_size", 0)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color("20283a")
	preview_style.border_width_left = 1
	preview_style.border_width_top = 1
	preview_style.border_width_right = 1
	preview_style.border_width_bottom = 1
	preview_style.border_color = Color("374966")
	preview_style.corner_radius_top_left = 10
	preview_style.corner_radius_top_right = 10
	preview_style.corner_radius_bottom_right = 10
	preview_style.corner_radius_bottom_left = 10
	preview_style.content_margin_left = 14
	preview_style.content_margin_top = 14
	preview_style.content_margin_right = 14
	preview_style.content_margin_bottom = 14
	selection_preview_panel.add_theme_stylebox_override("panel", preview_style)
	debug_label.custom_minimum_size = Vector2(0, 180)
	var debug_style := preview_style.duplicate()
	room_debug_panel.add_theme_stylebox_override("panel", debug_style)


func _style_primary_actions() -> void:
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.modulate = Color("eef4ff")
	connect_button.modulate = Color("d7ecff")
	create_room_button.modulate = Color("d7ecff")
	ready_button.modulate = Color("fff2c4")
	start_button.modulate = Color("d5ffd9")


func _update_summary_layout_mode() -> void:
	var summary_split := main_layout.get_node_or_null("SummarySplit")
	if summary_split == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	if viewport_width < 1180.0 and summary_split is HBoxContainer:
		var replacement := VBoxContainer.new()
		replacement.name = "SummarySplit"
		replacement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		replacement.size_flags_vertical = Control.SIZE_EXPAND_FILL
		replacement.add_theme_constant_override("separation", 12)
		var parent := summary_split.get_parent()
		var index := summary_split.get_index()
		parent.add_child(replacement)
		parent.move_child(replacement, index)
		summary_split.remove_child(selection_preview_panel)
		summary_split.remove_child(room_debug_panel)
		replacement.add_child(selection_preview_panel)
		replacement.add_child(room_debug_panel)
		summary_split.queue_free()
	elif viewport_width >= 1180.0 and summary_split is VBoxContainer:
		var replacement := HBoxContainer.new()
		replacement.name = "SummarySplit"
		replacement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		replacement.size_flags_vertical = Control.SIZE_EXPAND_FILL
		replacement.add_theme_constant_override("separation", 12)
		var parent := summary_split.get_parent()
		var index := summary_split.get_index()
		parent.add_child(replacement)
		parent.move_child(replacement, index)
		summary_split.remove_child(selection_preview_panel)
		summary_split.remove_child(room_debug_panel)
		replacement.add_child(selection_preview_panel)
		replacement.add_child(room_debug_panel)
		summary_split.queue_free()
