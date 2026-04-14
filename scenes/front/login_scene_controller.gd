extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LoginRequestScript = preload("res://app/front/auth/login_request.gd")

@onready var account_input = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/AccountRow/AccountInput")
@onready var player_name_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/PlayerNameRow/PlayerNameInput")
@onready var password_input = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/PasswordRow/PasswordInput")
@onready var host_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/EndpointCard/EndpointVBox/HostRow/HostInput")
@onready var port_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/EndpointCard/EndpointVBox/PortRow/PortInput")
@onready var enter_lobby_button: Button = get_node_or_null("LoginRoot/MainLayout/ActionRow/EnterLobbyButton")
@onready var register_button = get_node_or_null("LoginRoot/MainLayout/ActionRow/RegisterButton")
@onready var guest_login_button = get_node_or_null("LoginRoot/MainLayout/ActionRow/GuestLoginButton")
@onready var exit_button: Button = get_node_or_null("LoginRoot/MainLayout/ActionRow/ExitButton")
@onready var session_status_label = get_node_or_null("LoginRoot/MainLayout/AuthCard/AuthVBox/SessionStatusLabel")
@onready var last_account_label = get_node_or_null("LoginRoot/MainLayout/AuthCard/AuthVBox/LastAccountLabel")
@onready var message_label: Label = get_node_or_null("LoginRoot/MainLayout/MessageLabel")

var _app_runtime: Node = null


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
	_apply_profile_defaults()
	_refresh_session_summary()
	_connect_signals()
	_set_message("")


func _redirect_to_boot_if_missing() -> void:
	if _app_runtime != null and _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_boot"):
		_app_runtime.front_flow.enter_boot()
		return
	get_tree().change_scene_to_file("res://scenes/front/boot_scene.tscn")

func _apply_profile_defaults() -> void:
	if _app_runtime == null:
		return
	var profile = _app_runtime.player_profile_state
	var settings = _app_runtime.front_settings_state
	if player_name_input != null and profile != null:
		player_name_input.text = String(profile.nickname)
	if account_input != null and _app_runtime.auth_session_state != null:
		account_input.text = _app_runtime.auth_session_state.account_id
	if host_input != null and settings != null:
		host_input.text = settings.account_service_host
	if port_input != null and settings != null:
		port_input.text = str(settings.account_service_port)


func _connect_signals() -> void:
	if enter_lobby_button != null and not enter_lobby_button.pressed.is_connected(_on_enter_lobby_pressed):
		enter_lobby_button.pressed.connect(_on_enter_lobby_pressed)
	if register_button != null and not register_button.pressed.is_connected(_on_register_pressed):
		register_button.pressed.connect(_on_register_pressed)
	if guest_login_button != null and not guest_login_button.pressed.is_connected(_on_guest_login_pressed):
		guest_login_button.pressed.connect(_on_guest_login_pressed)
	if exit_button != null and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)


func _on_enter_lobby_pressed() -> void:
	if _app_runtime == null or _app_runtime.login_use_case == null:
		_set_message("Login use case is not available.")
		return
	if account_input != null and account_input.text.strip_edges().is_empty():
		_set_message("Account is required.")
		return
	if password_input != null and password_input.text.is_empty():
		_set_message("Password is required.")
		return
	var request := LoginRequestScript.new()
	request.account = account_input.text.strip_edges() if account_input != null else ""
	request.password = password_input.text if password_input != null else ""
	request.client_platform = OS.get_name().to_lower()
	request.server_host = host_input.text.strip_edges() if host_input != null else ""
	request.server_port = int(port_input.text.to_int()) if port_input != null else 0

	if _app_runtime.profile_gateway != null and _app_runtime.profile_gateway.has_method("configure_base_url"):
		_app_runtime.profile_gateway.configure_base_url("http://%s:%d" % [request.server_host if not request.server_host.is_empty() else "127.0.0.1", request.server_port if request.server_port > 0 else 18080])
	var result: Dictionary = _app_runtime.login_use_case.login(request)
	if not bool(result.get("ok", false)):
		_set_message(String(result.get("user_message", "Login failed")))
		_refresh_session_summary()
		return
	_set_message("")
	_refresh_session_summary()
	if _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_lobby"):
		_app_runtime.front_flow.enter_lobby()


func _on_register_pressed() -> void:
	var host := host_input.text.strip_edges() if host_input != null else ""
	if host.is_empty():
		host = "127.0.0.1"
	var port := int(port_input.text.to_int()) if port_input != null else 0
	if port <= 0:
		port = 18080
	var register_url := "http://%s:%d/register" % [host, port]
	var open_result := OS.shell_open(register_url)
	if open_result != OK:
		_set_message("Failed to open register page: %s" % register_url)
		return
	_set_message("Register page opened in browser.")


func _on_guest_login_pressed() -> void:
	if _app_runtime == null or _app_runtime.runtime_config == null or not bool(_app_runtime.runtime_config.enable_pass_through_auth_fallback):
		_set_message("Guest login is unavailable.")
		return
	_on_enter_lobby_pressed()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _set_message(text: String) -> void:
	if message_label != null:
		message_label.text = text


func _refresh_session_summary() -> void:
	if _app_runtime == null:
		return
	if session_status_label != null and _app_runtime.auth_session_state != null:
		session_status_label.text = "Session: %s" % String(_app_runtime.auth_session_state.session_state)
	if last_account_label != null:
		var account_text := "-"
		if _app_runtime.auth_session_state != null and not String(_app_runtime.auth_session_state.account_id).strip_edges().is_empty():
			account_text = String(_app_runtime.auth_session_state.account_id)
		last_account_label.text = "Last Account: %s" % account_text
