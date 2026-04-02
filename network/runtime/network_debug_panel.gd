class_name NetworkDebugPanel
extends RefCounted

var panel_root: Control = null
var title_label: Label = null
var mode_label: Label = null
var connection_label: Label = null
var host_button: Button = null
var client_button: Button = null
var address_input: LineEdit = null
var port_input: LineEdit = null
var launch_match_button: Button = null
var log_output: RichTextLabel = null


func setup(root: Control) -> void:
	panel_root = root
	if panel_root == null:
		return
	title_label = panel_root.get_node("TitleLabel")
	mode_label = panel_root.get_node("ModeLabel")
	connection_label = panel_root.get_node("ConnectionLabel")
	host_button = panel_root.get_node("HostButton")
	client_button = panel_root.get_node("ClientButton")
	address_input = panel_root.get_node("AddressInput")
	port_input = panel_root.get_node("PortInput")
	launch_match_button = panel_root.get_node("LaunchMatchButton")
	log_output = panel_root.get_node("LogOutput")


func bind_actions(on_host_pressed: Callable, on_client_pressed: Callable, on_launch_match_pressed: Callable) -> void:
	if host_button != null and not host_button.pressed.is_connected(on_host_pressed):
		host_button.pressed.connect(on_host_pressed)
	if client_button != null and not client_button.pressed.is_connected(on_client_pressed):
		client_button.pressed.connect(on_client_pressed)
	if launch_match_button != null and not launch_match_button.pressed.is_connected(on_launch_match_pressed):
		launch_match_button.pressed.connect(on_launch_match_pressed)


func initialize_defaults() -> void:
	if log_output != null:
		log_output.selection_enabled = true
	if address_input != null:
		address_input.text = "127.0.0.1"
	if port_input != null:
		port_input.text = "9000"


func refresh_mode(mode_name: String, launch_enabled: bool) -> void:
	if title_label != null:
		title_label.text = "Transport Debug Shell (Not Formal Game Entry)"
	if mode_label != null:
		mode_label.text = "Mode: %s" % mode_name
	if launch_match_button != null:
		launch_match_button.disabled = not launch_enabled


func refresh_connection(is_idle: bool, connected: bool, remote_peer_count: int) -> void:
	if connection_label == null:
		return
	if is_idle:
		connection_label.text = "Connection: Disconnected"
		return
	connection_label.text = "Connection: %s (%d peers)" % [
		"Connected" if connected else "Connecting",
		remote_peer_count,
	]


func apply_layout(viewport_size: Vector2) -> void:
	if panel_root == null:
		return
	var panel_width := 520.0
	var panel_height: float = min(max(viewport_size.y - 40.0, 360.0), 760.0)
	panel_root.position = Vector2(20, 20)
	panel_root.size = Vector2(panel_width, panel_height)

	if title_label != null:
		title_label.position = Vector2(16, 16)
		title_label.size = Vector2(panel_width - 32, 24)
	if mode_label != null:
		mode_label.position = Vector2(16, 44)
		mode_label.size = Vector2(panel_width - 32, 22)
	if connection_label != null:
		connection_label.position = Vector2(16, 68)
		connection_label.size = Vector2(panel_width - 32, 22)
	if host_button != null:
		host_button.position = Vector2(16, 104)
		host_button.size = Vector2(110, 32)
	if client_button != null:
		client_button.position = Vector2(136, 104)
		client_button.size = Vector2(110, 32)
	if address_input != null:
		address_input.position = Vector2(16, 146)
		address_input.size = Vector2(320, 32)
	if port_input != null:
		port_input.position = Vector2(346, 146)
		port_input.size = Vector2(80, 32)
	if launch_match_button != null:
		launch_match_button.position = Vector2(16, 188)
		launch_match_button.size = Vector2(160, 34)
	if log_output != null:
		log_output.position = Vector2(16, 234)
		log_output.size = Vector2(panel_width - 32, panel_height - 250)


func log(message: String) -> void:
	if log_output == null:
		return
	log_output.append_text(message + "\n")


func get_address() -> String:
	return address_input.text.strip_edges() if address_input != null else "127.0.0.1"


func get_port(default_port: int = 9000) -> int:
	if port_input == null:
		return default_port
	var port := int(port_input.text.strip_edges().to_int())
	return port if port > 0 else default_port

