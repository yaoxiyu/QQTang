extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LoginRequestScript = preload("res://app/front/auth/login_request.gd")

@onready var player_name_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/PlayerNameRow/PlayerNameInput")
@onready var host_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/EndpointCard/EndpointVBox/HostRow/HostInput")
@onready var port_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/EndpointCard/EndpointVBox/PortRow/PortInput")
@onready var enter_lobby_button: Button = get_node_or_null("LoginRoot/MainLayout/ActionRow/EnterLobbyButton")
@onready var exit_button: Button = get_node_or_null("LoginRoot/MainLayout/ActionRow/ExitButton")
@onready var message_label: Label = get_node_or_null("LoginRoot/MainLayout/MessageLabel")

var _app_runtime: Node = null


func _ready() -> void:
	call_deferred("_initialize_runtime")


func _initialize_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	if _app_runtime == null or not _app_runtime.is_inside_tree():
		call_deferred("_initialize_runtime")
		return
	_apply_profile_defaults()
	_connect_signals()
	_set_message("")

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


func _set_message(text: String) -> void:
	if message_label != null:
		message_label.text = text
