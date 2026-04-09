extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LobbyRoomDirectoryBuilderScript = preload("res://app/front/lobby/lobby_room_directory_builder.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const PHASE15_LOG_PREFIX := "[QQT_P15]"

@onready var current_profile_label: Label = get_node_or_null("LobbyRoot/MainLayout/HeaderRow/CurrentProfileLabel")
@onready var logout_button: Button = get_node_or_null("LobbyRoot/MainLayout/HeaderRow/LogoutButton")
@onready var default_character_value: Label = get_node_or_null("LobbyRoot/MainLayout/ProfileCard/ProfileVBox/DefaultCharacterRow/DefaultCharacterValue")
@onready var default_character_skin_value: Label = get_node_or_null("LobbyRoot/MainLayout/ProfileCard/ProfileVBox/DefaultCharacterSkinRow/DefaultCharacterSkinValue")
@onready var default_bubble_value: Label = get_node_or_null("LobbyRoot/MainLayout/ProfileCard/ProfileVBox/DefaultBubbleRow/DefaultBubbleValue")
@onready var default_bubble_skin_value: Label = get_node_or_null("LobbyRoot/MainLayout/ProfileCard/ProfileVBox/DefaultBubbleSkinRow/DefaultBubbleSkinValue")
@onready var practice_map_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/PracticeCard/PracticeVBox/PracticeMapRow/PracticeMapSelector")
@onready var practice_rule_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/PracticeCard/PracticeVBox/PracticeRuleRow/PracticeRuleSelector")
@onready var practice_mode_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/PracticeCard/PracticeVBox/PracticeModeRow/PracticeModeSelector")
@onready var start_practice_button: Button = get_node_or_null("LobbyRoot/MainLayout/PracticeCard/PracticeVBox/StartPracticeButton")
@onready var host_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/ServerRow/HostInput")
@onready var port_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/ServerRow/PortInput")
@onready var create_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/CreateRoomRow/CreateRoomButton")
@onready var room_id_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/JoinRoomRow/RoomIdInput")
@onready var join_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/JoinRoomRow/JoinRoomButton")
@onready var connect_directory_button: Button = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/DirectoryConnectionRow/ConnectDirectoryButton")
@onready var refresh_room_list_button: Button = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/DirectoryConnectionRow/RefreshRoomListButton")
@onready var public_room_name_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/CreatePublicRoomRow/PublicRoomNameInput")
@onready var create_public_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/CreatePublicRoomRow/CreatePublicRoomButton")
@onready var public_room_list: ItemList = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/PublicRoomList")
@onready var join_selected_public_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/JoinSelectedPublicRoomButton")
@onready var directory_status_label: Label = get_node_or_null("LobbyRoot/MainLayout/OnlineCard/OnlineVBox/DirectoryStatusLabel")
@onready var recent_room_label: Label = get_node_or_null("LobbyRoot/MainLayout/RecentCard/RecentVBox/RecentRoomLabel")
@onready var reconnect_button: Button = get_node_or_null("LobbyRoot/MainLayout/RecentCard/RecentVBox/ReconnectButton")
@onready var message_label: Label = get_node_or_null("LobbyRoot/MainLayout/MessageLabel")

var _app_runtime: Node = null
var _room_directory_builder = LobbyRoomDirectoryBuilderScript.new()
var _last_room_directory_snapshot = null
var _directory_connect_requested: bool = false


func _ready() -> void:
	_bind_runtime()


func _bind_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if _app_runtime == null:
		_set_message("Runtime missing, returning to boot...")
		_redirect_to_boot_if_missing()
		return
	if _app_runtime.has_method("is_runtime_ready") and _app_runtime.is_runtime_ready():
		_on_runtime_ready()
		return
	if _app_runtime.has_signal("runtime_ready") and not _app_runtime.runtime_ready.is_connected(_on_runtime_ready):
		_app_runtime.runtime_ready.connect(_on_runtime_ready, CONNECT_ONE_SHOT)


func _on_runtime_ready() -> void:
	_populate_practice_selectors()
	_refresh_view()
	_connect_signals()


func _redirect_to_boot_if_missing() -> void:
	if _app_runtime != null and _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_boot"):
		_app_runtime.front_flow.enter_boot()
		return
	get_tree().change_scene_to_file("res://scenes/front/boot_scene.tscn")


func _populate_practice_selectors() -> void:
	if practice_map_selector != null:
		practice_map_selector.clear()
		for entry in MapCatalogScript.get_map_entries():
			practice_map_selector.add_item(String(entry.get("display_name", entry.get("id", ""))))
			practice_map_selector.set_item_metadata(practice_map_selector.item_count - 1, String(entry.get("id", "")))
	if practice_rule_selector != null:
		practice_rule_selector.clear()
		for entry in RuleSetCatalogScript.get_rule_entries():
			practice_rule_selector.add_item(String(entry.get("display_name", entry.get("id", ""))))
			practice_rule_selector.set_item_metadata(practice_rule_selector.item_count - 1, String(entry.get("id", "")))
	if practice_mode_selector != null:
		practice_mode_selector.clear()
		for entry in ModeCatalogScript.get_mode_entries():
			practice_mode_selector.add_item(String(entry.get("display_name", entry.get("id", ""))))
			practice_mode_selector.set_item_metadata(practice_mode_selector.item_count - 1, String(entry.get("id", "")))


func _refresh_view() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null:
		return
	var result: Dictionary = _app_runtime.lobby_use_case.enter_lobby()
	var view_state = result.get("view_state", null)
	if view_state == null:
		return
	if current_profile_label != null:
		current_profile_label.text = String(view_state.profile_name)
	if default_character_value != null:
		default_character_value.text = String(view_state.default_character_id)
	if default_character_skin_value != null:
		default_character_skin_value.text = String(view_state.default_character_skin_id)
	if default_bubble_value != null:
		default_bubble_value.text = String(view_state.default_bubble_style_id)
	if default_bubble_skin_value != null:
		default_bubble_skin_value.text = String(view_state.default_bubble_skin_id)
	if host_input != null:
		host_input.text = String(view_state.last_server_host)
	if port_input != null:
		port_input.text = str(int(view_state.last_server_port))
	if room_id_input != null:
		room_id_input.text = String(view_state.last_room_id)
	if recent_room_label != null:
		recent_room_label.text = "Recent Room: %s" % String(view_state.reconnect_room_id if not String(view_state.reconnect_room_id).is_empty() else view_state.last_room_id)
	_select_metadata(practice_map_selector, String(view_state.preferred_map_id))
	_select_metadata(practice_rule_selector, String(view_state.preferred_rule_id))
	_select_metadata(practice_mode_selector, String(view_state.preferred_mode_id))
	_set_message("")


func _connect_signals() -> void:
	if start_practice_button != null and not start_practice_button.pressed.is_connected(_on_start_practice_pressed):
		start_practice_button.pressed.connect(_on_start_practice_pressed)
	if create_room_button != null and not create_room_button.pressed.is_connected(_on_create_room_pressed):
		create_room_button.pressed.connect(_on_create_room_pressed)
	if join_room_button != null and not join_room_button.pressed.is_connected(_on_join_room_pressed):
		join_room_button.pressed.connect(_on_join_room_pressed)
	if reconnect_button != null and not reconnect_button.pressed.is_connected(_on_reconnect_pressed):
		reconnect_button.pressed.connect(_on_reconnect_pressed)
	if logout_button != null and not logout_button.pressed.is_connected(_on_logout_pressed):
		logout_button.pressed.connect(_on_logout_pressed)
	if connect_directory_button != null and not connect_directory_button.pressed.is_connected(_on_connect_directory_pressed):
		connect_directory_button.pressed.connect(_on_connect_directory_pressed)
	if refresh_room_list_button != null and not refresh_room_list_button.pressed.is_connected(_on_refresh_room_list_pressed):
		refresh_room_list_button.pressed.connect(_on_refresh_room_list_pressed)
	if create_public_room_button != null and not create_public_room_button.pressed.is_connected(_on_create_public_room_pressed):
		create_public_room_button.pressed.connect(_on_create_public_room_pressed)
	if join_selected_public_room_button != null and not join_selected_public_room_button.pressed.is_connected(_on_join_selected_public_room_pressed):
		join_selected_public_room_button.pressed.connect(_on_join_selected_public_room_pressed)
	if _app_runtime != null and _app_runtime.client_room_runtime != null and not _app_runtime.client_room_runtime.room_error.is_connected(_on_room_error):
		_app_runtime.client_room_runtime.room_error.connect(_on_room_error)
	if _app_runtime != null and _app_runtime.client_room_runtime != null and not _app_runtime.client_room_runtime.transport_connected.is_connected(_on_transport_connected):
		_app_runtime.client_room_runtime.transport_connected.connect(_on_transport_connected)
	if _app_runtime != null and _app_runtime.client_room_runtime != null and _app_runtime.client_room_runtime.has_signal("room_directory_snapshot_received") and not _app_runtime.client_room_runtime.room_directory_snapshot_received.is_connected(_on_room_directory_snapshot_received):
		_app_runtime.client_room_runtime.room_directory_snapshot_received.connect(_on_room_directory_snapshot_received)


func _on_start_practice_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.start_practice(
		_selected_metadata(practice_map_selector),
		_selected_metadata(practice_rule_selector),
		_selected_metadata(practice_mode_selector)
	)
	_handle_room_entry_result(result)


func _on_create_room_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.create_private_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_handle_room_entry_result(result)


func _on_join_room_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.join_private_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0,
		room_id_input.text.strip_edges() if room_id_input != null else ""
	)
	_handle_room_entry_result(result)


func _on_connect_directory_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_directory_use_case == null:
		_set_directory_status("Directory flow is not available.")
		return
	_directory_connect_requested = true
	_log_phase15("ui_connect_directory_pressed", {
		"host": host_input.text.strip_edges() if host_input != null else "",
		"port": int(port_input.text.to_int()) if port_input != null else 0,
	})
	var result: Dictionary = _app_runtime.lobby_directory_use_case.connect_directory(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_apply_directory_result(result)


func _on_refresh_room_list_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_directory_use_case == null:
		_set_directory_status("Directory flow is not available.")
		return
	_directory_connect_requested = true
	_log_phase15("ui_refresh_room_list_pressed", {
		"host": host_input.text.strip_edges() if host_input != null else "",
		"port": int(port_input.text.to_int()) if port_input != null else 0,
	})
	var result: Dictionary = _app_runtime.lobby_directory_use_case.refresh_directory(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_apply_directory_result(result)


func _on_create_public_room_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_directory_status("Lobby room flow is not available.")
		return
	_log_phase15("ui_create_public_room_pressed", {
		"host": host_input.text.strip_edges() if host_input != null else "",
		"port": int(port_input.text.to_int()) if port_input != null else 0,
		"room_display_name": public_room_name_input.text.strip_edges() if public_room_name_input != null else "",
	})
	var result: Dictionary = _app_runtime.lobby_use_case.create_public_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0,
		public_room_name_input.text.strip_edges() if public_room_name_input != null else ""
	)
	_handle_room_entry_result(result)


func _on_join_selected_public_room_pressed() -> void:
	if public_room_list == null or public_room_list.get_selected_items().is_empty():
		_set_directory_status("Select a public room first.")
		return
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_directory_status("Lobby room flow is not available.")
		return
	var selected_index := int(public_room_list.get_selected_items()[0])
	var room_id := String(public_room_list.get_item_metadata(selected_index))
	_log_phase15("ui_join_selected_public_room_pressed", {
		"room_id": room_id,
		"selected_index": selected_index,
	})
	var result: Dictionary = _app_runtime.lobby_use_case.join_public_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0,
		room_id
	)
	_handle_room_entry_result(result)


func _on_reconnect_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var view_state = _app_runtime.lobby_use_case.enter_lobby().get("view_state", null)
	var reconnect_room_id := String(view_state.reconnect_room_id if view_state != null else "").strip_edges()
	var reconnect_host := String(view_state.reconnect_host if view_state != null else "").strip_edges()
	var reconnect_port := int(view_state.reconnect_port if view_state != null else 0)
	if reconnect_room_id.is_empty():
		_set_message("No reconnect room is available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.join_private_room(
		reconnect_host,
		reconnect_port,
		reconnect_room_id
	)
	_handle_room_entry_result(result)


func _on_logout_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null:
		return
	_app_runtime.lobby_use_case.logout()
	if _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_login"):
		_app_runtime.front_flow.enter_login()


func _handle_room_entry_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_set_message(String(result.get("user_message", "Room entry failed")))
		_set_directory_status(String(result.get("user_message", "")))
		return
	var entry_context: Variant = result.get("entry_context", null)
	if entry_context == null:
		_set_message("Room entry context is missing.")
		_set_directory_status("Room entry context is missing.")
		return
	_log_phase15("room_entry_context_ready", {
		"entry_kind": String(entry_context.entry_kind),
		"room_kind": String(entry_context.room_kind),
		"target_room_id": String(entry_context.target_room_id),
		"room_display_name": String(entry_context.room_display_name),
	})
	_directory_connect_requested = false
	if _app_runtime != null and _app_runtime.client_room_runtime != null and _app_runtime.client_room_runtime.has_method("unsubscribe_room_directory"):
		_app_runtime.client_room_runtime.unsubscribe_room_directory()
	var room_result: Dictionary = _app_runtime.room_use_case.enter_room(entry_context)
	if not bool(room_result.get("ok", false)):
		_set_message(String(room_result.get("user_message", "Failed to enter room")))
		_set_directory_status(String(room_result.get("user_message", "")))
		return
	if bool(room_result.get("pending", false)):
		_set_message("Connecting...")
		_set_directory_status("")
		return
	_set_message("")
	_set_directory_status("")


func _selected_metadata(selector: OptionButton) -> String:
	if selector == null or selector.selected < 0:
		return ""
	return String(selector.get_item_metadata(selector.selected))


func _select_metadata(selector: OptionButton, target: String) -> void:
	if selector == null:
		return
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) == target:
			selector.select(index)
			return
	if selector.item_count > 0:
		selector.select(0)


func _set_message(text: String) -> void:
	if message_label != null:
		message_label.text = text


func _set_directory_status(text: String) -> void:
	if directory_status_label != null:
		directory_status_label.text = text


func _on_room_error(_error_code: String, user_message: String) -> void:
	if _app_runtime == null or _app_runtime.front_flow == null:
		return
	if _app_runtime.front_flow.get_state_name() != &"LOBBY":
		return
	_set_message(user_message)
	_set_directory_status(user_message)


func _on_transport_connected() -> void:
	if not _directory_connect_requested:
		return
	if _app_runtime == null or _app_runtime.front_flow == null or _app_runtime.lobby_directory_use_case == null:
		return
	if _app_runtime.front_flow.get_state_name() != &"LOBBY":
		return
	var result: Dictionary = _app_runtime.lobby_directory_use_case.refresh_directory(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_apply_directory_result(result)


func _apply_directory_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_set_directory_status(String(result.get("user_message", "Directory request failed")))
		return
	_set_directory_status(String(result.get("user_message", "")))


func _on_room_directory_snapshot_received(snapshot) -> void:
	_last_room_directory_snapshot = snapshot.duplicate_deep() if snapshot != null and snapshot.has_method("duplicate_deep") else snapshot
	if public_room_list == null:
		return
	public_room_list.clear()
	if snapshot == null:
		_set_directory_status("No public rooms available.")
		return
	var view_models := _room_directory_builder.build_view_models(snapshot)
	_log_phase15("ui_room_directory_snapshot_render", {
		"entry_count": view_models.size(),
		"revision": int(snapshot.revision) if snapshot != null else -1,
	})
	for view_model in view_models:
		var label_text := String(view_model.get("summary_text", view_model.get("room_display_name", "")))
		public_room_list.add_item(label_text)
		public_room_list.set_item_metadata(public_room_list.item_count - 1, String(view_model.get("room_id", "")))
	_set_directory_status("Loaded %d public room(s)." % public_room_list.item_count)


func _log_phase15(event_name: String, payload: Dictionary) -> void:
	print("%s[lobby_scene] %s %s" % [PHASE15_LOG_PREFIX, event_name, JSON.stringify(payload)])
