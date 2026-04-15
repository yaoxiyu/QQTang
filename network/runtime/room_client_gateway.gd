class_name RoomClientGateway
extends RefCounted
const ROOM_GATEWAY_ANOMALY_TAG := "net.room_gateway.anomaly"

signal transport_connected()
signal room_snapshot_received(snapshot: RoomSnapshot)
signal room_error(error_code: String, user_message: String)
signal canonical_start_config_received(config: BattleStartConfig)
signal match_loading_snapshot_received(snapshot: MatchLoadingSnapshot)

# Phase17: Resume signals
signal room_member_session_received(payload: Dictionary)
signal match_resume_accepted(config: BattleStartConfig, snapshot: MatchResumeSnapshot)

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
		connection_config.selected_bubble_skin_id,
		connection_config.room_ticket,
		connection_config.room_ticket_id,
		connection_config.account_id,
		connection_config.profile_id,
		connection_config.device_session_id
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
		connection_config.selected_map_id,
		connection_config.selected_rule_set_id,
		connection_config.selected_mode_id,
		connection_config.room_kind,
		connection_config.room_display_name,
		connection_config.room_ticket,
		connection_config.room_ticket_id,
		connection_config.account_id,
		connection_config.profile_id,
		connection_config.device_session_id
	)


func request_update_profile(
	player_name: String,
	character_id: String,
	character_skin_id: String,
	bubble_style_id: String,
	bubble_skin_id: String,
	team_id: int
) -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_update_profile(player_name, character_id, character_skin_id, bubble_style_id, bubble_skin_id, team_id)


func request_update_selection(map_id: String, rule_id: String, mode_id: String) -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_update_selection(map_id, rule_id, mode_id)


func request_update_match_room_config(match_format_id: String, selected_mode_ids: Array[String]) -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_update_match_room_config(match_format_id, selected_mode_ids)


func request_enter_match_queue() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_enter_match_queue()


func request_cancel_match_queue() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_cancel_match_queue()


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


func request_match_loading_ready(match_id: String, revision: int) -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_match_loading_ready(match_id, revision)


func request_rematch() -> void:
	if client_room_runtime == null:
		return
	client_room_runtime.request_rematch()


# Phase17: Resume request
func request_resume_room(connection_config: ClientConnectionConfig, member_id: String, reconnect_token: String, match_id: String) -> void:
	if client_room_runtime == null or connection_config == null:
		return
	client_room_runtime.request_resume_room(
		connection_config.room_id_hint,
		member_id,
		reconnect_token,
		match_id,
		connection_config.room_ticket,
		connection_config.room_ticket_id,
		connection_config.account_id,
		connection_config.profile_id,
		connection_config.device_session_id
	)


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
	if client_room_runtime.has_signal("match_loading_snapshot_received") and not client_room_runtime.match_loading_snapshot_received.is_connected(_on_match_loading_snapshot_received):
		client_room_runtime.match_loading_snapshot_received.connect(_on_match_loading_snapshot_received)
	# Phase17: Connect resume signals
	if client_room_runtime.has_signal("room_member_session_received") and not client_room_runtime.room_member_session_received.is_connected(_on_room_member_session_received):
		client_room_runtime.room_member_session_received.connect(_on_room_member_session_received)
	if client_room_runtime.has_signal("match_resume_accepted") and not client_room_runtime.match_resume_accepted.is_connected(_on_match_resume_accepted):
		client_room_runtime.match_resume_accepted.connect(_on_match_resume_accepted)


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
	if client_room_runtime.has_signal("match_loading_snapshot_received") and client_room_runtime.match_loading_snapshot_received.is_connected(_on_match_loading_snapshot_received):
		client_room_runtime.match_loading_snapshot_received.disconnect(_on_match_loading_snapshot_received)
	# Phase17: Disconnect resume signals
	if client_room_runtime.has_signal("room_member_session_received") and client_room_runtime.room_member_session_received.is_connected(_on_room_member_session_received):
		client_room_runtime.room_member_session_received.disconnect(_on_room_member_session_received)
	if client_room_runtime.has_signal("match_resume_accepted") and client_room_runtime.match_resume_accepted.is_connected(_on_match_resume_accepted):
		client_room_runtime.match_resume_accepted.disconnect(_on_match_resume_accepted)


func _on_transport_connected() -> void:
	transport_connected.emit()


func _on_room_snapshot_received(snapshot: RoomSnapshot) -> void:
	room_snapshot_received.emit(snapshot)


func _on_room_error(error_code: String, user_message: String) -> void:
	room_error.emit(error_code, user_message)


func _on_canonical_start_config_received(config: BattleStartConfig) -> void:
	canonical_start_config_received.emit(config)


func _on_match_loading_snapshot_received(snapshot: MatchLoadingSnapshot) -> void:
	match_loading_snapshot_received.emit(snapshot)


# Phase17: Resume signal callbacks
func _on_room_member_session_received(payload: Dictionary) -> void:
	room_member_session_received.emit(payload)


func _on_match_resume_accepted(config: BattleStartConfig, snapshot: MatchResumeSnapshot) -> void:
	match_resume_accepted.emit(config, snapshot)


const LogNetScript = preload("res://app/logging/log_net.gd")

func _log_room_anomaly(event_name: String, details: Dictionary) -> void:
	LogNetScript.warn("%s %s" % [event_name, JSON.stringify(details)], "", 0, ROOM_GATEWAY_ANOMALY_TAG)
