extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LoginRequestScript = preload("res://app/front/auth/login_request.gd")

@onready var login_root: Control = get_node_or_null("LoginRoot")
@onready var main_layout: VBoxContainer = get_node_or_null("LoginRoot/MainLayout")
@onready var title_label: Label = get_node_or_null("LoginRoot/MainLayout/TitleLabel")
@onready var intro_label: Label = get_node_or_null("LoginRoot/MainLayout/IntroLabel")
@onready var profile_card: PanelContainer = get_node_or_null("LoginRoot/MainLayout/ProfileCard")
@onready var endpoint_card: PanelContainer = get_node_or_null("LoginRoot/MainLayout/EndpointCard")
@onready var auth_card: PanelContainer = get_node_or_null("LoginRoot/MainLayout/AuthCard")
@onready var action_row: HBoxContainer = get_node_or_null("LoginRoot/MainLayout/ActionRow")
@onready var account_input = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/AccountRow/AccountInput")
@onready var player_name_input: LineEdit = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/PlayerNameRow/PlayerNameInput")
@onready var password_input = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/PasswordRow/PasswordInput")
@onready var account_label: Label = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/AccountRow/AccountLabel")
@onready var password_label: Label = get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/PasswordRow/PasswordLabel")
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
	_apply_formal_login_layout()
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
	get_tree().change_scene_to_file.call_deferred("res://scenes/front/boot_scene.tscn")

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
	_refresh_front_state()
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


func _refresh_front_state() -> void:
	if _app_runtime == null:
		return
	if _app_runtime.wallet_use_case != null and _app_runtime.wallet_use_case.has_method("refresh_wallet"):
		_app_runtime.wallet_use_case.refresh_wallet()
	if _app_runtime.inventory_use_case != null and _app_runtime.inventory_use_case.has_method("refresh_inventory"):
		_app_runtime.inventory_use_case.refresh_inventory()
	if _app_runtime.shop_use_case != null and _app_runtime.shop_use_case.has_method("refresh_catalog"):
		_app_runtime.shop_use_case.refresh_catalog()


func _apply_formal_login_layout() -> void:
	_bind_login_asset_ids()
	_ensure_background_node()
	_ensure_logo_node()
	if login_root != null:
		login_root.mouse_filter = Control.MOUSE_FILTER_STOP
	if main_layout != null:
		main_layout.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		main_layout.offset_left = 86.0
		main_layout.offset_top = -286.0
		main_layout.offset_right = 586.0
		main_layout.offset_bottom = 286.0
		main_layout.add_theme_constant_override("separation", 18)
		main_layout.custom_minimum_size = Vector2(500, 572)
	if title_label != null:
		title_label.text = "QQTang"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.add_theme_font_size_override("font_size", 44)
	if intro_label != null:
		intro_label.text = "Account login"
		intro_label.add_theme_font_size_override("font_size", 18)
		intro_label.modulate = Color(0.82, 0.88, 0.95, 1.0)
	_apply_card_style(profile_card)
	_apply_card_style(endpoint_card)
	_apply_status_card_style(auth_card)
	_apply_input_layout()
	_apply_button_layout()
	_apply_message_layout()


func _bind_login_asset_ids() -> void:
	_set_asset_meta(login_root, "ui.login.bg.main")
	_set_asset_meta(profile_card, "ui.login.panel.auth")
	_set_asset_meta(account_input, "ui.login.input.account.normal")
	_set_asset_meta(password_input, "ui.login.input.password.normal")
	_set_asset_meta(enter_lobby_button, "ui.login.button.login.normal")
	_set_asset_meta(register_button, "ui.login.button.register.normal")
	_set_asset_meta(guest_login_button, "ui.login.button.guest.normal")


func _ensure_background_node() -> void:
	if login_root == null:
		return
	var background: ColorRect = login_root.get_node_or_null("FormalBackground")
	if background == null:
		background = ColorRect.new()
		background.name = "FormalBackground"
		login_root.add_child(background)
		login_root.move_child(background, 0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.07, 0.11, 0.16, 1.0)
	background.set_meta("ui_asset_id", "ui.login.bg.main")


func _ensure_logo_node() -> void:
	if login_root == null:
		return
	var logo: Label = login_root.get_node_or_null("LogoLabel")
	if logo == null:
		logo = Label.new()
		logo.name = "LogoLabel"
		login_root.add_child(logo)
	logo.text = "QQTang"
	logo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	logo.offset_left = -430.0
	logo.offset_top = 78.0
	logo.offset_right = -80.0
	logo.offset_bottom = 166.0
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	logo.add_theme_font_size_override("font_size", 56)
	logo.modulate = Color(0.96, 0.82, 0.34, 1.0)
	logo.set_meta("ui_asset_id", "ui.login.logo.main")


func _apply_card_style(card: PanelContainer) -> void:
	if card == null:
		return
	card.custom_minimum_size = Vector2(500, 0)
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.13, 0.18, 0.24, 0.94), Color(0.32, 0.45, 0.60, 0.65), 8))


func _apply_status_card_style(card: PanelContainer) -> void:
	if card == null:
		return
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.13, 0.18, 0.88), Color(0.24, 0.34, 0.46, 0.5), 8))


func _apply_input_layout() -> void:
	if account_label != null:
		account_label.text = "Account"
		account_label.custom_minimum_size = Vector2(92, 0)
	if password_label != null:
		password_label.text = "Password"
		password_label.custom_minimum_size = Vector2(92, 0)
	for input in [account_input, password_input, host_input, port_input]:
		if input == null:
			continue
		input.custom_minimum_size = Vector2(320, 38)
		input.add_theme_stylebox_override("normal", _make_panel_style(Color(0.06, 0.08, 0.11, 1.0), Color(0.24, 0.34, 0.45, 0.7), 6))
		input.add_theme_stylebox_override("focus", _make_panel_style(Color(0.07, 0.10, 0.14, 1.0), Color(0.95, 0.75, 0.25, 1.0), 6))
	if endpoint_card != null:
		endpoint_card.visible = false


func _apply_button_layout() -> void:
	if action_row != null:
		action_row.add_theme_constant_override("separation", 10)
	for button in [enter_lobby_button, register_button, guest_login_button, exit_button]:
		if button == null:
			continue
		button.custom_minimum_size = Vector2(132, 40)
		button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.80, 0.56, 0.18, 1.0), Color(1.0, 0.78, 0.32, 1.0), 6))
		button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.92, 0.66, 0.22, 1.0), Color(1.0, 0.86, 0.46, 1.0), 6))
		button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.62, 0.40, 0.13, 1.0), Color(0.95, 0.72, 0.28, 1.0), 6))
		button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))
	if enter_lobby_button != null:
		enter_lobby_button.text = "Login"
	if register_button != null:
		register_button.text = "Register"
	if exit_button != null:
		exit_button.text = "Exit"


func _apply_message_layout() -> void:
	if message_label == null:
		return
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.64, 0.34, 1.0))


func _make_panel_style(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


func _set_asset_meta(node: Node, asset_id: String) -> void:
	if node == null:
		return
	node.set_meta("ui_asset_id", asset_id)

