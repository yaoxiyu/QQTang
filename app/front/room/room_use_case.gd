class_name RoomUseCase
extends RefCounted

const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const RoomClientGatewayScript = preload("res://network/runtime/room_client_gateway.gd")
const ClientConnectionConfigScript = preload("res://network/runtime/client_connection_config.gd")

var app_runtime: Node = null
var room_client_gateway: RoomClientGateway = null
var _pending_online_entry_context: RoomEntryContext = null
var _pending_connection_config: ClientConnectionConfig = null
var _await_room_before_enter: bool = false


func configure(p_app_runtime: Node) -> void:
	app_runtime = p_app_runtime
	if app_runtime == null:
		_disconnect_gateway_signals()
		if room_client_gateway != null and room_client_gateway.has_method("unbind_runtime"):
			room_client_gateway.unbind_runtime()
		_pending_online_entry_context = null
		_pending_connection_config = null
		_await_room_before_enter = false
		return
	if room_client_gateway == null:
		room_client_gateway = RoomClientGatewayScript.new()
	room_client_gateway.bind_runtime(app_runtime, app_runtime.client_room_runtime if app_runtime != null else null)
	_connect_gateway_signals()


func dispose() -> void:
	_disconnect_gateway_signals()
	if room_client_gateway != null and room_client_gateway.has_method("unbind_runtime"):
		room_client_gateway.unbind_runtime()
	room_client_gateway = null
	app_runtime = null
	_pending_online_entry_context = null
	_pending_connection_config = null
	_await_room_before_enter = false


func enter_room(entry_context: RoomEntryContext) -> Dictionary:
	if app_runtime == null:
		return _fail("APP_RUNTIME_MISSING", "App runtime is not configured")
	app_runtime.current_room_entry_context = entry_context.duplicate_deep() if entry_context != null else RoomEntryContext.new()

	if entry_context != null and entry_context.room_kind == FrontRoomKindScript.PRIVATE_ROOM:
		if app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("reset_room_state"):
			app_runtime.room_session_controller.reset_room_state()
		var connection_config := _build_connection_config(entry_context)
		if room_client_gateway != null:
			_pending_online_entry_context = entry_context.duplicate_deep()
			_pending_connection_config = connection_config.duplicate_deep()
			_await_room_before_enter = String(entry_context.entry_kind) == FrontEntryKindScript.ONLINE_JOIN
			room_client_gateway.connect_to_server(connection_config)
		if not _await_room_before_enter and app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_room"):
			app_runtime.front_flow.enter_room()
		return {"ok": true, "error_code": "", "user_message": "", "pending": true}

	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_room"):
		app_runtime.front_flow.enter_room()
	return {"ok": true, "error_code": "", "user_message": ""}


func leave_room() -> Dictionary:
	if app_runtime == null:
		return _fail("APP_RUNTIME_MISSING", "App runtime is not configured")
	var room_controller: Node = app_runtime.room_session_controller
	if room_controller != null and room_controller.has_method("leave_room"):
		room_controller.leave_room(int(app_runtime.local_peer_id))
	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_lobby"):
		app_runtime.front_flow.enter_lobby()
	return {"ok": true, "error_code": "", "user_message": ""}


func update_local_profile(
	player_name: String,
	character_id: String,
	character_skin_id: String,
	bubble_style_id: String,
	bubble_skin_id: String
) -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return _fail("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	var result: Dictionary = app_runtime.room_session_controller.request_update_member_profile(
		int(app_runtime.local_peer_id),
		player_name,
		character_id,
		character_skin_id,
		bubble_style_id,
		bubble_skin_id
	)
	if room_client_gateway != null and _is_online_room():
		room_client_gateway.request_update_profile(player_name, character_id, character_skin_id, bubble_style_id, bubble_skin_id)
	return result


func update_selection(map_id: String, rule_id: String, mode_id: String) -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return _fail("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	var result: Dictionary = app_runtime.room_session_controller.request_update_selection(
		int(app_runtime.local_peer_id),
		map_id,
		rule_id,
		mode_id
	)
	if bool(result.get("ok", false)) and room_client_gateway != null and _is_online_room():
		room_client_gateway.request_update_selection(map_id, rule_id, mode_id)
	return result


func toggle_ready() -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return _fail("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	var result: Dictionary = app_runtime.room_session_controller.request_toggle_ready(int(app_runtime.local_peer_id))
	if bool(result.get("ok", false)) and room_client_gateway != null and _is_online_room():
		room_client_gateway.request_toggle_ready()
	return result


func start_match() -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return _fail("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	var result: Dictionary = app_runtime.room_session_controller.request_begin_match(int(app_runtime.local_peer_id))
	if not bool(result.get("ok", false)):
		return result
	if room_client_gateway != null and _is_online_room():
		room_client_gateway.request_start_match()
		return result
	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("request_start_match"):
		app_runtime.front_flow.request_start_match()
	return result


func on_authoritative_snapshot(snapshot: RoomSnapshot) -> void:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return
	app_runtime.room_session_controller.apply_authoritative_snapshot(snapshot)
	app_runtime.current_room_snapshot = snapshot.duplicate_deep() if snapshot != null else null


func _build_connection_config(entry_context: RoomEntryContext) -> ClientConnectionConfig:
	var config := ClientConnectionConfigScript.new()
	config.server_host = entry_context.server_host
	config.server_port = entry_context.server_port
	config.room_id_hint = entry_context.target_room_id
	if app_runtime != null and app_runtime.player_profile_state != null:
		config.player_name = app_runtime.player_profile_state.nickname
		config.selected_character_id = app_runtime.player_profile_state.default_character_id
		config.selected_character_skin_id = app_runtime.player_profile_state.default_character_skin_id
		config.selected_bubble_style_id = app_runtime.player_profile_state.default_bubble_style_id
		config.selected_bubble_skin_id = app_runtime.player_profile_state.default_bubble_skin_id
		config.selected_mode_id = app_runtime.player_profile_state.preferred_mode_id
	return config


func _is_online_room() -> bool:
	if app_runtime == null or app_runtime.current_room_entry_context == null:
		return false
	return String(app_runtime.current_room_entry_context.topology) == FrontTopologyScript.DEDICATED_SERVER


func _connect_gateway_signals() -> void:
	if room_client_gateway == null:
		return
	if not room_client_gateway.transport_connected.is_connected(_on_gateway_transport_connected):
		room_client_gateway.transport_connected.connect(_on_gateway_transport_connected)
	if not room_client_gateway.room_snapshot_received.is_connected(_on_gateway_room_snapshot_received):
		room_client_gateway.room_snapshot_received.connect(_on_gateway_room_snapshot_received)
	if not room_client_gateway.room_error.is_connected(_on_gateway_room_error):
		room_client_gateway.room_error.connect(_on_gateway_room_error)
	if not room_client_gateway.canonical_start_config_received.is_connected(_on_gateway_canonical_start_config_received):
		room_client_gateway.canonical_start_config_received.connect(_on_gateway_canonical_start_config_received)


func _disconnect_gateway_signals() -> void:
	if room_client_gateway == null:
		return
	if room_client_gateway.transport_connected.is_connected(_on_gateway_transport_connected):
		room_client_gateway.transport_connected.disconnect(_on_gateway_transport_connected)
	if room_client_gateway.room_snapshot_received.is_connected(_on_gateway_room_snapshot_received):
		room_client_gateway.room_snapshot_received.disconnect(_on_gateway_room_snapshot_received)
	if room_client_gateway.room_error.is_connected(_on_gateway_room_error):
		room_client_gateway.room_error.disconnect(_on_gateway_room_error)
	if room_client_gateway.canonical_start_config_received.is_connected(_on_gateway_canonical_start_config_received):
		room_client_gateway.canonical_start_config_received.disconnect(_on_gateway_canonical_start_config_received)


func _on_gateway_transport_connected() -> void:
	if room_client_gateway == null or _pending_online_entry_context == null or _pending_connection_config == null:
		return
	match String(_pending_online_entry_context.entry_kind):
		FrontEntryKindScript.ONLINE_CREATE:
			room_client_gateway.request_create_room(_pending_connection_config)
		FrontEntryKindScript.ONLINE_JOIN:
			room_client_gateway.request_join_room(_pending_connection_config)
		_:
			pass


func _on_gateway_room_snapshot_received(snapshot: RoomSnapshot) -> void:
	on_authoritative_snapshot(snapshot)
	if _await_room_before_enter and app_runtime != null and app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_room"):
		app_runtime.front_flow.enter_room()
	_pending_online_entry_context = null
	_pending_connection_config = null
	_await_room_before_enter = false


func _on_gateway_room_error(error_code: String, user_message: String) -> void:
	_pending_online_entry_context = null
	_pending_connection_config = null
	_await_room_before_enter = false
	if app_runtime != null and app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("set_last_error"):
		app_runtime.room_session_controller.set_last_error(error_code, user_message, {})


func _on_gateway_canonical_start_config_received(config: BattleStartConfig) -> void:
	if app_runtime == null:
		return
	if app_runtime.has_method("apply_canonical_start_config"):
		app_runtime.apply_canonical_start_config(config)
	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("request_start_match"):
		app_runtime.front_flow.request_start_match()


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
	}
