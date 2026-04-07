extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LoginRequestScript = preload("res://app/front/auth/login_request.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")

@onready var player_name_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/PlayerNameRow/PlayerNameInput")
@onready var character_selector: OptionButton = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/CharacterRow/CharacterSelector")
@onready var character_skin_selector: OptionButton = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/CharacterSkinRow/CharacterSkinSelector")
@onready var bubble_selector: OptionButton = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/BubbleRow/BubbleSelector")
@onready var bubble_skin_selector: OptionButton = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/BubbleSkinRow/BubbleSkinSelector")
@onready var host_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/EndpointCard/EndpointVBox/HostRow/HostInput")
@onready var port_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/EndpointCard/EndpointVBox/PortRow/PortInput")
@onready var enter_lobby_button: Button = get_node_or_null("LoginRoot/MainLayout/ActionRow/EnterLobbyButton")
@onready var exit_button: Button = get_node_or_null("LoginRoot/MainLayout/ActionRow/ExitButton")
@onready var message_label: Label = get_node_or_null("LoginRoot/MainLayout/MessageLabel")

var _app_runtime: Node = null
var _suppress_selector_callbacks: bool = false


func _ready() -> void:
	call_deferred("_initialize_runtime")


func _initialize_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	if _app_runtime == null or not _app_runtime.is_inside_tree():
		call_deferred("_initialize_runtime")
		return
	_populate_selectors()
	_apply_profile_defaults()
	_connect_signals()
	_set_message("")


func _populate_selectors() -> void:
	_suppress_selector_callbacks = true
	if character_selector != null:
		character_selector.clear()
		for entry in CharacterCatalogScript.get_character_entries():
			character_selector.add_item(String(entry.get("display_name", entry.get("id", ""))))
			character_selector.set_item_metadata(character_selector.item_count - 1, String(entry.get("id", "")))
	if character_skin_selector != null:
		character_skin_selector.clear()
		character_skin_selector.add_item("None")
		character_skin_selector.set_item_metadata(0, "")
		for skin_def in CharacterSkinCatalogScript.get_all():
			if skin_def == null:
				continue
			character_skin_selector.add_item(String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_def.skin_id))
			character_skin_selector.set_item_metadata(character_skin_selector.item_count - 1, skin_def.skin_id)
	if bubble_selector != null:
		bubble_selector.clear()
		for entry in BubbleCatalogScript.get_bubble_entries():
			bubble_selector.add_item(String(entry.get("display_name", entry.get("id", ""))))
			bubble_selector.set_item_metadata(bubble_selector.item_count - 1, String(entry.get("id", "")))
	if bubble_skin_selector != null:
		bubble_skin_selector.clear()
		bubble_skin_selector.add_item("None")
		bubble_skin_selector.set_item_metadata(0, "")
		for skin_def in BubbleSkinCatalogScript.get_all():
			if skin_def == null:
				continue
			bubble_skin_selector.add_item(String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_def.bubble_skin_id))
			bubble_skin_selector.set_item_metadata(bubble_skin_selector.item_count - 1, skin_def.bubble_skin_id)
	_suppress_selector_callbacks = false


func _apply_profile_defaults() -> void:
	if _app_runtime == null:
		return
	var profile = _app_runtime.player_profile_state
	var settings = _app_runtime.front_settings_state
	if player_name_input != null and profile != null:
		player_name_input.text = profile.nickname
	if host_input != null and settings != null:
		host_input.text = settings.last_server_host
	if port_input != null and settings != null:
		port_input.text = str(settings.last_server_port)
	_select_metadata(character_selector, String(profile.default_character_id if profile != null else ""))
	_select_metadata(character_skin_selector, String(profile.default_character_skin_id if profile != null else ""))
	_select_metadata(bubble_selector, String(profile.default_bubble_style_id if profile != null else ""))
	_select_metadata(bubble_skin_selector, String(profile.default_bubble_skin_id if profile != null else ""))


func _connect_signals() -> void:
	if enter_lobby_button != null and not enter_lobby_button.pressed.is_connected(_on_enter_lobby_pressed):
		enter_lobby_button.pressed.connect(_on_enter_lobby_pressed)
	if exit_button != null and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)


func _on_enter_lobby_pressed() -> void:
	if _app_runtime == null or _app_runtime.login_use_case == null:
		_set_message("Login use case is not available.")
		return
	var request := LoginRequestScript.new()
	var profile = _app_runtime.player_profile_state
	request.nickname = player_name_input.text.strip_edges() if player_name_input != null else ""
	request.profile_id = String(profile.profile_id if profile != null else "")
	request.default_character_id = _selected_metadata(character_selector)
	request.default_character_skin_id = _selected_metadata(character_skin_selector)
	request.default_bubble_style_id = _selected_metadata(bubble_selector)
	request.default_bubble_skin_id = _selected_metadata(bubble_skin_selector)
	request.server_host = host_input.text.strip_edges() if host_input != null else ""
	request.server_port = int(port_input.text.to_int()) if port_input != null else 0

	var result: Dictionary = _app_runtime.login_use_case.login(request)
	if not bool(result.get("ok", false)):
		_set_message(String(result.get("user_message", "Login failed")))
		return
	_set_message("")
	if _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_lobby"):
		_app_runtime.front_flow.enter_lobby()


func _on_exit_pressed() -> void:
	get_tree().quit()


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
