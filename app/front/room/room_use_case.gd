class_name RoomUseCase
extends RefCounted

const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const RoomClientGatewayScript = preload("res://network/runtime/room_client_gateway.gd")
const ClientConnectionConfigScript = preload("res://network/runtime/client_connection_config.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const PHASE15_LOG_PREFIX := "[QQT_P15]"
const ROOM_ANOMALY_LOG_PREFIX := "[QQT_ROOM_ANOM]"

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
		_log_room_anomaly("enter_room_without_runtime", {})
		return _fail("APP_RUNTIME_MISSING", "App runtime is not configured")
	app_runtime.current_room_entry_context = entry_context.duplicate_deep() if entry_context != null else RoomEntryContext.new()

	if entry_context != null and String(entry_context.topology) == FrontTopologyScript.DEDICATED_SERVER and String(entry_context.room_kind) != FrontRoomKindScript.PRACTICE:
		if app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("reset_room_state"):
			app_runtime.room_session_controller.reset_room_state()
		var connection_config := _build_connection_config(entry_context)
		_log_phase15("enter_dedicated_room_requested", {
			"entry_kind": String(entry_context.entry_kind),
			"room_kind": String(entry_context.room_kind),
			"server_host": String(connection_config.server_host),
			"server_port": int(connection_config.server_port),
			"room_id_hint": String(connection_config.room_id_hint),
			"room_display_name": String(connection_config.room_display_name),
		})
		if room_client_gateway != null:
			_pending_online_entry_context = entry_context.duplicate_deep()
			_pending_connection_config = connection_config.duplicate_deep()
			_await_room_before_enter = true
			room_client_gateway.connect_to_server(connection_config)
		else:
			_log_room_anomaly("enter_room_missing_gateway", _build_entry_context_context(entry_context))
		return {"ok": true, "error_code": "", "user_message": "", "pending": true}

	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_room"):
		app_runtime.front_flow.enter_room()
	return {"ok": true, "error_code": "", "user_message": ""}


func leave_room() -> Dictionary:
	if app_runtime == null:
		return _fail("APP_RUNTIME_MISSING", "App runtime is not configured")
	if room_client_gateway != null and _is_online_room():
		if room_client_gateway.has_method("request_leave_room_and_disconnect"):
			room_client_gateway.request_leave_room_and_disconnect()
		else:
			room_client_gateway.request_leave_room()
	var room_controller: Node = app_runtime.room_session_controller
	if room_controller != null and room_controller.has_method("reset_room_state"):
		room_controller.reset_room_state()
	app_runtime.current_room_snapshot = null
	app_runtime.current_room_entry_context = null
	_pending_online_entry_context = null
	_pending_connection_config = null
	_await_room_before_enter = false
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
	if app_runtime.current_room_entry_context == null and _pending_online_entry_context == null:
		return
	app_runtime.room_session_controller.apply_authoritative_snapshot(snapshot)
	app_runtime.current_room_snapshot = snapshot.duplicate_deep() if snapshot != null else null
	_update_reconnect_state(snapshot)


func _build_connection_config(entry_context: RoomEntryContext) -> ClientConnectionConfig:
	var config := ClientConnectionConfigScript.new()
	config.server_host = entry_context.server_host
	config.server_port = entry_context.server_port
	config.room_id_hint = entry_context.target_room_id
	config.room_kind = entry_context.room_kind
	config.room_display_name = entry_context.room_display_name
	if app_runtime != null and app_runtime.player_profile_state != null:
		config.player_name = app_runtime.player_profile_state.nickname
		config.selected_character_id = app_runtime.player_profile_state.default_character_id
		config.selected_character_skin_id = app_runtime.player_profile_state.default_character_skin_id
		config.selected_bubble_style_id = app_runtime.player_profile_state.default_bubble_style_id
		config.selected_bubble_skin_id = app_runtime.player_profile_state.default_bubble_skin_id
		config.selected_mode_id = app_runtime.player_profile_state.preferred_mode_id
	_sanitize_connection_profile(config)
	if config.server_host.strip_edges().is_empty() or config.server_port <= 0:
		_log_room_anomaly("invalid_connection_config", {
			"entry_kind": String(entry_context.entry_kind),
			"room_kind": String(entry_context.room_kind),
			"topology": String(entry_context.topology),
			"server_host": config.server_host,
			"server_port": config.server_port,
			"room_id_hint": config.room_id_hint,
		})
	return config


func _sanitize_connection_profile(config: ClientConnectionConfig) -> void:
	if config == null:
		return
	if not CharacterCatalogScript.has_character(config.selected_character_id):
		config.selected_character_id = CharacterCatalogScript.get_default_character_id()
	if not BubbleCatalogScript.has_bubble(config.selected_bubble_style_id):
		config.selected_bubble_style_id = BubbleCatalogScript.get_default_bubble_id()
	if not ModeCatalogScript.has_mode(config.selected_mode_id):
		config.selected_mode_id = ModeCatalogScript.get_default_mode_id()


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
	if room_client_gateway == null:
		_log_room_anomaly("transport_connected_without_gateway", {})
		return
	if _pending_online_entry_context == null or _pending_connection_config == null:
		_log_room_anomaly("transport_connected_without_pending_entry", {
			"has_pending_entry": _pending_online_entry_context != null,
			"has_pending_config": _pending_connection_config != null,
		})
		return
	match String(_pending_online_entry_context.entry_kind):
		FrontEntryKindScript.ONLINE_CREATE:
			_log_phase15("transport_connected_dispatch_create", {
				"room_kind": String(_pending_connection_config.room_kind),
				"room_display_name": String(_pending_connection_config.room_display_name),
			})
			room_client_gateway.request_create_room(_pending_connection_config)
		FrontEntryKindScript.ONLINE_JOIN:
			_log_phase15("transport_connected_dispatch_join", {
				"room_kind": String(_pending_connection_config.room_kind),
				"room_id_hint": String(_pending_connection_config.room_id_hint),
			})
			room_client_gateway.request_join_room(_pending_connection_config)
		_:
			_log_room_anomaly("transport_connected_with_unknown_entry_kind", {
				"entry_kind": String(_pending_online_entry_context.entry_kind),
				"topology": String(_pending_online_entry_context.topology),
				"room_id_hint": String(_pending_connection_config.room_id_hint),
			})


func _on_gateway_room_snapshot_received(snapshot: RoomSnapshot) -> void:
	if snapshot == null:
		_log_room_anomaly("received_null_room_snapshot", _build_pending_connection_context())
		return
	if String(snapshot.topology) == FrontTopologyScript.DEDICATED_SERVER and snapshot.room_id.is_empty():
		_log_room_anomaly("received_snapshot_without_room_id", _build_snapshot_context(snapshot))
	if String(snapshot.topology) == FrontTopologyScript.DEDICATED_SERVER and snapshot.members.is_empty():
		_log_room_anomaly("received_snapshot_without_members", _build_snapshot_context(snapshot))
	on_authoritative_snapshot(snapshot)
	_log_phase15("authoritative_room_snapshot_received", {
		"room_id": String(snapshot.room_id),
		"room_kind": String(snapshot.room_kind),
		"room_display_name": String(snapshot.room_display_name),
		"member_count": snapshot.members.size(),
		"match_active": bool(snapshot.match_active),
	})
	if _await_room_before_enter:
		if app_runtime == null or app_runtime.front_flow == null or not app_runtime.front_flow.has_method("enter_room"):
			_log_room_anomaly("awaiting_room_but_front_flow_missing", _build_snapshot_context(snapshot))
		else:
			app_runtime.front_flow.enter_room()
	_pending_online_entry_context = null
	_pending_connection_config = null
	_await_room_before_enter = false


func _update_reconnect_state(snapshot: RoomSnapshot) -> void:
	if app_runtime == null or app_runtime.front_settings_state == null or snapshot == null:
		return
	if String(snapshot.topology) != FrontTopologyScript.DEDICATED_SERVER:
		return
	if snapshot.room_id.is_empty():
		return
	app_runtime.front_settings_state.last_room_id = snapshot.room_id
	app_runtime.front_settings_state.reconnect_room_id = snapshot.room_id
	var server_host := ""
	var server_port := 0
	if app_runtime.current_room_entry_context != null:
		server_host = String(app_runtime.current_room_entry_context.server_host)
		server_port = int(app_runtime.current_room_entry_context.server_port)
	if server_host.strip_edges().is_empty():
		server_host = String(app_runtime.front_settings_state.last_server_host)
	if server_port <= 0:
		server_port = int(app_runtime.front_settings_state.last_server_port)
	app_runtime.front_settings_state.reconnect_host = server_host
	app_runtime.front_settings_state.reconnect_port = server_port


func _on_gateway_room_error(error_code: String, user_message: String) -> void:
	_log_room_anomaly("gateway_room_error", {
		"error_code": error_code,
		"user_message": user_message,
		"await_room_before_enter": _await_room_before_enter,
		"pending_entry_kind": String(_pending_online_entry_context.entry_kind) if _pending_online_entry_context != null else "",
		"pending_topology": String(_pending_online_entry_context.topology) if _pending_online_entry_context != null else "",
		"pending_server_host": String(_pending_connection_config.server_host) if _pending_connection_config != null else "",
		"pending_server_port": int(_pending_connection_config.server_port) if _pending_connection_config != null else 0,
		"pending_room_id_hint": String(_pending_connection_config.room_id_hint) if _pending_connection_config != null else "",
	})
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


func _log_room_anomaly(event_name: String, details: Dictionary) -> void:
	print("%s %s %s" % [ROOM_ANOMALY_LOG_PREFIX, event_name, JSON.stringify(details)])


func _log_phase15(event_name: String, details: Dictionary) -> void:
	print("%s[room_use_case] %s %s" % [PHASE15_LOG_PREFIX, event_name, JSON.stringify(details)])


func _build_entry_context_context(entry_context: RoomEntryContext) -> Dictionary:
	if entry_context == null:
		return {}
	return {
		"entry_kind": String(entry_context.entry_kind),
		"room_kind": String(entry_context.room_kind),
		"topology": String(entry_context.topology),
		"server_host": String(entry_context.server_host),
		"server_port": int(entry_context.server_port),
		"target_room_id": String(entry_context.target_room_id),
	}


func _build_pending_connection_context() -> Dictionary:
	return {
		"await_room_before_enter": _await_room_before_enter,
		"pending_entry_kind": String(_pending_online_entry_context.entry_kind) if _pending_online_entry_context != null else "",
		"pending_topology": String(_pending_online_entry_context.topology) if _pending_online_entry_context != null else "",
		"pending_server_host": String(_pending_connection_config.server_host) if _pending_connection_config != null else "",
		"pending_server_port": int(_pending_connection_config.server_port) if _pending_connection_config != null else 0,
		"pending_room_id_hint": String(_pending_connection_config.room_id_hint) if _pending_connection_config != null else "",
	}


func _build_snapshot_context(snapshot: RoomSnapshot) -> Dictionary:
	var context := _build_pending_connection_context()
	context["snapshot_room_id"] = String(snapshot.room_id) if snapshot != null else ""
	context["snapshot_topology"] = String(snapshot.topology) if snapshot != null else ""
	context["snapshot_member_count"] = snapshot.members.size() if snapshot != null else -1
	return context
