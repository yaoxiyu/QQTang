extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")

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
@onready var recent_room_label: Label = get_node_or_null("LobbyRoot/MainLayout/RecentCard/RecentVBox/RecentRoomLabel")
@onready var reconnect_button: Button = get_node_or_null("LobbyRoot/MainLayout/RecentCard/RecentVBox/ReconnectButton")
@onready var message_label: Label = get_node_or_null("LobbyRoot/MainLayout/MessageLabel")

var _app_runtime: Node = null


func _ready() -> void:
	call_deferred("_initialize_runtime")


func _initialize_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	if _app_runtime == null or not _app_runtime.is_inside_tree():
		call_deferred("_initialize_runtime")
		return
	_populate_practice_selectors()
	_refresh_view()
	_connect_signals()


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
		recent_room_label.text = "Recent Room: %s" % String(view_state.last_room_id)
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
	if _app_runtime != null and _app_runtime.client_room_runtime != null and not _app_runtime.client_room_runtime.room_error.is_connected(_on_room_error):
		_app_runtime.client_room_runtime.room_error.connect(_on_room_error)


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


func _on_reconnect_pressed() -> void:
	_on_join_room_pressed()


func _on_logout_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null:
		return
	_app_runtime.lobby_use_case.logout()
	if _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_login"):
		_app_runtime.front_flow.enter_login()


func _handle_room_entry_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_set_message(String(result.get("user_message", "Room entry failed")))
		return
	var entry_context: Variant = result.get("entry_context", null)
	if entry_context == null:
		_set_message("Room entry context is missing.")
		return
	var room_result: Dictionary = _app_runtime.room_use_case.enter_room(entry_context)
	if not bool(room_result.get("ok", false)):
		_set_message(String(room_result.get("user_message", "Failed to enter room")))
		return
	if bool(room_result.get("pending", false)):
		_set_message("Connecting...")
		return
	_set_message("")


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


func _on_room_error(_error_code: String, user_message: String) -> void:
	if _app_runtime == null or _app_runtime.front_flow == null:
		return
	if _app_runtime.front_flow.get_state_name() != &"LOBBY":
		return
	_set_message(user_message)
