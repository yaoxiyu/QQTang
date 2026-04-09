class_name RoomClientGateway
extends RefCounted
const ROOM_ANOMALY_LOG_PREFIX := "[QQT_ROOM_ANOM]"

signal transport_connected()
signal room_snapshot_received(snapshot: RoomSnapshot)
signal room_error(error_code: String, user_message: String)
signal canonical_start_config_received(config: BattleStartConfig)

var app_runtime: Node = null
var client_room_runtime: Node = null


func bind_runtime(bound_app_runtime: Node, bound_client_room_runtime: Node) -> void:
	if client_room_runtime != null:
		_disconnect_runtime_signals()
	app_runtime = bound_app_runtime
	client_room_runtime = bound_client_room_runtime
	_connect_runtime_signals()


func unbind_runtime() -> void:
	if client_room_runtime != null:
		_disconnect_runtime_signals()
	client_room_runtime = null
	app_runtime = null


func connect_to_server(connection_config: ClientConnectionConfig) -> void:
	if client_room_runtime == null or connection_config == null:
		_log_room_anomaly("connect_to_server_missing_dependency", {
			"has_client_room_runtime": client_room_runtime != null,
			"has_connection_config": connection_config != null,
		})
		return
	client_room_runtime.connect_to_server(
		connection_config.server_host,
		connection_config.server_port,
		connection_config.connect_timeout_sec
	)


func request_join_room(connection_config: ClientConnectionConfig) -> void:
	if client_room_runtime == null or connection_config == null:
		_log_room_anomaly("request_join_room_missing_dependency", {
			"has_client_room_runtime": client_room_runtime != null,
			"has_connection_config": connection_config != null,
		})
		return
	client_room_runtime.request_join_room(
		connection_config.room_id_hint,
		connection_config.player_name,
		connection_config.selected_character_id,
		connection_config.selected_character_skin_id,
		connection_config.selected_bubble_style_id,
		connection_config.selected_bubble_skin_id
	)


func request_create_room(connection_config: ClientConnectionConfig) -> void:
	if client_room_runtime == null or connection_config == null:
		_log_room_anomaly("request_create_room_missing_dependency", {
			"has_client_room_runtime": client_room_runtime != null,
			"has_connection_config": connection_config != null,
		})
		return
	client_room_runtime.request_create_room(
		connection_config.room_id_hint,
		connection_config.player_name,
		connection_config.selected_character_id,
		connection_config.selected_character_skin_id,
		connection_config.selected_bubble_style_id,
		connection_config.selected_bubble_skin_id,
		"",
		"",
		connection_config.selected_mode_id,
		connection_config.room_kind,
		connection_config.room_display_name
	)


func request_update_profile(
	player_name: String,
	character_id: String,
	character_skin_id: String,
	bubble_style_id: String,
	bubble_skin_id: String
) -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_update_profile(player_name, character_id, character_skin_id, bubble_style_id, bubble_skin_id)


func request_update_selection(map_id: String, rule_id: String, mode_id: String) -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_update_selection(map_id, rule_id, mode_id)


func request_toggle_ready() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_toggle_ready()


func request_start_match() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_start_match()


func request_leave_room() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_leave_room()


func request_leave_room_and_disconnect() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_leave_room_and_disconnect()


func request_room_directory_snapshot() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_room_directory_snapshot()


func subscribe_room_directory() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.subscribe_room_directory()


func unsubscribe_room_directory() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.unsubscribe_room_directory()


func _connect_runtime_signals() -> void:
	if client_room_runtime == null:
		return
	if not client_room_runtime.transport_connected.is_connected(_on_transport_connected):
		client_room_runtime.transport_connected.connect(_on_transport_connected)
	if not client_room_runtime.room_snapshot_received.is_connected(_on_room_snapshot_received):
		client_room_runtime.room_snapshot_received.connect(_on_room_snapshot_received)
	if not client_room_runtime.room_error.is_connected(_on_room_error):
		client_room_runtime.room_error.connect(_on_room_error)
	if not client_room_runtime.canonical_start_config_received.is_connected(_on_canonical_start_config_received):
		client_room_runtime.canonical_start_config_received.connect(_on_canonical_start_config_received)


func _disconnect_runtime_signals() -> void:
	if client_room_runtime == null:
		return
	if client_room_runtime.transport_connected.is_connected(_on_transport_connected):
		client_room_runtime.transport_connected.disconnect(_on_transport_connected)
	if client_room_runtime.room_snapshot_received.is_connected(_on_room_snapshot_received):
		client_room_runtime.room_snapshot_received.disconnect(_on_room_snapshot_received)
	if client_room_runtime.room_error.is_connected(_on_room_error):
		client_room_runtime.room_error.disconnect(_on_room_error)
	if client_room_runtime.canonical_start_config_received.is_connected(_on_canonical_start_config_received):
		client_room_runtime.canonical_start_config_received.disconnect(_on_canonical_start_config_received)


func _on_transport_connected() -> void:
	transport_connected.emit()


func _on_room_snapshot_received(snapshot: RoomSnapshot) -> void:
	room_snapshot_received.emit(snapshot)


func _on_room_error(error_code: String, user_message: String) -> void:
	room_error.emit(error_code, user_message)


func _on_canonical_start_config_received(config: BattleStartConfig) -> void:
	canonical_start_config_received.emit(config)


func _log_room_anomaly(event_name: String, details: Dictionary) -> void:
	print("%s %s %s" % [ROOM_ANOMALY_LOG_PREFIX, event_name, JSON.stringify(details)])
