extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
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
var _client_room_runtime: Node = null
var _room_client_gateway: Node = null
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
	main_layout.anchor_right = 1.0
	main_layout.anchor_bottom = 1.0
	main_layout.offset_left = 48.0
	main_layout.offset_top = 36.0
	main_layout.offset_right = -48.0
	main_layout.offset_bottom = -36.0
	main_layout.add_theme_constant_override("separation", 16)
	network_config_panel.add_theme_constant_override("separation", 8)
	member_list.add_theme_constant_override("separation", 8)
	title_label.text = "QQTang Room"
	mode_label.text = "Mode"
	host_label.text = "Host"
	port_label.text = "Port"
	room_id_label.text = "Room"
	player_name_label.text = "Player"
	character_label.text = "Character"
	map_label.text = "Map"
	rule_label.text = "Rule"
	connect_button.text = "Connect"
	create_room_button.text = "Create/Join Room"
	host_input.placeholder_text = "127.0.0.1"
	port_input.placeholder_text = "9000"
	room_id_input.placeholder_text = "room_id(optional)"
	player_name_input.placeholder_text = "Player1"
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.text = "Initializing room runtime..."


func _populate_selectors() -> void:
	_suppress_selection_callbacks = true
	_populate_mode_selector()
	_populate_character_selector()
	_populate_map_selector()
	_populate_rule_selector()
	_suppress_selection_callbacks = false


func _populate_mode_selector() -> void:
	mode_selector.clear()
	_add_selector_item(mode_selector, "Local Singleplayer", str(ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER))
	_add_selector_item(mode_selector, "Network Client", str(ClientLaunchModeScript.Value.NETWORK_CLIENT))


func _populate_character_selector() -> void:
	character_selector.clear()
	for entry in CharacterCatalogScript.get_character_entries():
		_add_selector_item(character_selector, String(entry.get("display_name", "")), String(entry.get("id", "")))


func _populate_map_selector() -> void:
	map_selector.clear()
	for entry in MapCatalogScript.get_map_entries():
		var map_id := String(entry.get("id", ""))
		if map_id.is_empty():
			continue
		var display_name := String(entry.get("display_name", map_id))
		_add_selector_item(map_selector, display_name, map_id)


func _populate_rule_selector() -> void:
	rule_selector.clear()
	for entry in RuleCatalogScript.get_rule_entries():
		var rule_id := String(entry.get("id", ""))
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
		lines.append("PlayerProfile: %s / %s" % [connection.player_name, connection.selected_character_id])
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
	if _selected_launch_mode() == ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER:
		_app_runtime.set_local_peer_id(1)
		_ensure_local_room_created()
		_apply_local_profile_to_room()
	elif _room_client_gateway != null:
		_room_client_gateway.request_update_profile(
			_app_runtime.runtime_config.client_connection.player_name,
			_app_runtime.runtime_config.client_connection.selected_character_id
		)
		_room_client_gateway.request_toggle_ready()
		return
	if _should_prepare_manual_local_loop_room():
		_app_runtime.debug_tools.ensure_manual_local_loop_room(
			_room_controller,
			_app_runtime.local_peer_id,
			_app_runtime.remote_peer_id,
			_selected_metadata(map_selector),
			_selected_metadata(rule_selector)
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
	if _selected_launch_mode() == ClientLaunchModeScript.Value.NETWORK_CLIENT and _room_client_gateway != null:
		_room_client_gateway.request_update_selection(
			String(map_selector.get_item_metadata(index)),
			_selected_metadata(rule_selector)
		)
		return
	_room_controller.request_update_selection(
		_app_runtime.local_peer_id,
		String(map_selector.get_item_metadata(index)),
		_selected_metadata(rule_selector)
	)


func _on_rule_selected(index: int) -> void:
	if _suppress_selection_callbacks or _room_controller == null or _app_runtime == null:
		return
	if _selected_launch_mode() == ClientLaunchModeScript.Value.NETWORK_CLIENT and _room_client_gateway != null:
		_room_client_gateway.request_update_selection(
			_selected_metadata(map_selector),
			String(rule_selector.get_item_metadata(index))
		)
		return
	_room_controller.request_update_selection(
		_app_runtime.local_peer_id,
		_selected_metadata(map_selector),
		String(rule_selector.get_item_metadata(index))
	)


func _on_mode_selected(_index: int) -> void:
	if _suppress_selection_callbacks or _room_controller == null:
		return
	_apply_connection_config_from_ui()
	_refresh_room(_room_controller.build_room_snapshot())


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
			connection.selected_character_id
		)


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
