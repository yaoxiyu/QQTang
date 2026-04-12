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
const LogFrontScript = preload("res://app/logging/log_front.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const PHASE15_LOG_PREFIX := "[QQT_P15]"
const ROOM_ANOMALY_LOG_PREFIX := "[QQT_ROOM_ANOM]"
const PENDING_CONNECTION_WATCHDOG_GRACE_SEC := 1.0

var app_runtime: Node = null
var room_client_gateway: RoomClientGateway = null
var _pending_online_entry_context: RoomEntryContext = null
var _pending_connection_config: ClientConnectionConfig = null
var _await_room_before_enter: bool = false
var _pending_connection_watchdog_token: int = 0


func configure(p_app_runtime: Node) -> void:
	app_runtime = p_app_runtime
	if app_runtime == null:
		_disconnect_gateway_signals()
		if room_client_gateway != null and room_client_gateway.has_method("unbind_runtime"):
			room_client_gateway.unbind_runtime()
		_clear_pending_online_entry_state()
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
	_clear_pending_online_entry_state()


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
			_schedule_pending_connection_watchdog(_pending_connection_config)
			if _has_ready_transport_for(connection_config):
				_log_phase15("enter_room_reusing_connected_transport", {
					"server_host": String(connection_config.server_host),
					"server_port": int(connection_config.server_port),
					"entry_kind": String(entry_context.entry_kind),
					"room_kind": String(entry_context.room_kind),
				})
				_on_gateway_transport_connected()
			else:
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
	if app_runtime.front_settings_state != null and app_runtime.front_settings_state.has_method("clear_reconnect_ticket"):
		app_runtime.front_settings_state.clear_reconnect_ticket()
		if app_runtime.front_settings_repository != null and app_runtime.front_settings_repository.has_method("save_settings"):
			app_runtime.front_settings_repository.save_settings(app_runtime.front_settings_state)
	app_runtime.current_room_snapshot = null
	app_runtime.current_room_entry_context = null
	_clear_pending_online_entry_state()
	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_lobby"):
		app_runtime.front_flow.enter_lobby()
	return {"ok": true, "error_code": "", "user_message": ""}


func update_local_profile(
	player_name: String,
	character_id: String,
	character_skin_id: String,
	bubble_style_id: String,
	bubble_skin_id: String,
	team_id: int = 1
) -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return _fail("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	var result: Dictionary = app_runtime.room_session_controller.request_update_member_profile(
		int(app_runtime.local_peer_id),
		player_name,
		character_id,
		character_skin_id,
		bubble_style_id,
		bubble_skin_id,
		team_id
	)
	if bool(result.get("ok", false)) and room_client_gateway != null and _is_online_room():
		room_client_gateway.request_update_profile(player_name, character_id, character_skin_id, bubble_style_id, bubble_skin_id, team_id)
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
	if room_client_gateway != null and _is_online_room():
		var blocker: Dictionary = app_runtime.room_session_controller.get_start_match_blocker(int(app_runtime.local_peer_id))
		if not blocker.is_empty():
			blocker["ok"] = false
			return blocker
		room_client_gateway.request_start_match()
		return {"ok": true, "error_code": "", "user_message": "", "pending": true}
	var result: Dictionary = app_runtime.room_session_controller.request_begin_match(int(app_runtime.local_peer_id))
	if not bool(result.get("ok", false)):
		return result
	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("request_start_match"):
		app_runtime.front_flow.request_start_match()
	return result


func request_rematch() -> Dictionary:
	if app_runtime == null or room_client_gateway == null:
		return _fail("ROOM_USE_CASE_MISSING", "App runtime or gateway is not configured")
	if not _is_online_room():
		return _fail("NOT_ONLINE_ROOM", "Rematch is only supported in online rooms")
	room_client_gateway.request_rematch()
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


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


func _has_ready_transport_for(connection_config: ClientConnectionConfig) -> bool:
	if connection_config == null or app_runtime == null or app_runtime.client_room_runtime == null:
		return false
	var client_room_runtime = app_runtime.client_room_runtime
	return client_room_runtime.has_method("is_connected_to") \
		and client_room_runtime.is_connected_to(String(connection_config.server_host), int(connection_config.server_port)) \
		and client_room_runtime.has_method("is_transport_connected") \
		and client_room_runtime.is_transport_connected()


func _is_online_room() -> bool:
	if app_runtime == null:
		return false
	if app_runtime.current_room_entry_context != null and String(app_runtime.current_room_entry_context.topology) == FrontTopologyScript.DEDICATED_SERVER:
		return true
	if app_runtime.current_room_snapshot != null and String(app_runtime.current_room_snapshot.topology) == FrontTopologyScript.DEDICATED_SERVER:
		return true
	if app_runtime.room_session_controller != null and app_runtime.room_session_controller.room_runtime_context != null:
		return String(app_runtime.room_session_controller.room_runtime_context.topology) == FrontTopologyScript.DEDICATED_SERVER
	return false


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
	if not room_client_gateway.match_loading_snapshot_received.is_connected(_on_gateway_match_loading_snapshot_received):
		room_client_gateway.match_loading_snapshot_received.connect(_on_gateway_match_loading_snapshot_received)
	# Phase17: Connect resume signals
	if room_client_gateway.has_signal("room_member_session_received") and not room_client_gateway.room_member_session_received.is_connected(_on_gateway_room_member_session_received):
		room_client_gateway.room_member_session_received.connect(_on_gateway_room_member_session_received)
	if room_client_gateway.has_signal("match_resume_accepted") and not room_client_gateway.match_resume_accepted.is_connected(_on_gateway_match_resume_accepted):
		room_client_gateway.match_resume_accepted.connect(_on_gateway_match_resume_accepted)


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
	if room_client_gateway.match_loading_snapshot_received.is_connected(_on_gateway_match_loading_snapshot_received):
		room_client_gateway.match_loading_snapshot_received.disconnect(_on_gateway_match_loading_snapshot_received)
	# Phase17: Disconnect resume signals
	if room_client_gateway.has_signal("room_member_session_received") and room_client_gateway.room_member_session_received.is_connected(_on_gateway_room_member_session_received):
		room_client_gateway.room_member_session_received.disconnect(_on_gateway_room_member_session_received)
	if room_client_gateway.has_signal("match_resume_accepted") and room_client_gateway.match_resume_accepted.is_connected(_on_gateway_match_resume_accepted):
		room_client_gateway.match_resume_accepted.disconnect(_on_gateway_match_resume_accepted)


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
	
	# Phase17: Check for resume flow
	if _pending_online_entry_context.use_resume_flow:
		_log_phase15("transport_connected_dispatch_resume", {
			"room_id": String(_pending_online_entry_context.target_room_id),
			"member_id": String(_pending_online_entry_context.reconnect_member_id),
			"match_id": String(_pending_online_entry_context.reconnect_match_id),
		})
		room_client_gateway.request_resume_room(
			_pending_online_entry_context.target_room_id,
			_pending_online_entry_context.reconnect_member_id,
			_pending_online_entry_context.reconnect_token,
			_pending_online_entry_context.reconnect_match_id
		)
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
	_clear_pending_online_entry_state()


func _update_reconnect_state(snapshot: RoomSnapshot) -> void:
	if app_runtime == null or app_runtime.front_settings_state == null or snapshot == null:
		return
	if String(snapshot.topology) != FrontTopologyScript.DEDICATED_SERVER:
		return
	if snapshot.room_id.is_empty():
		return
	app_runtime.front_settings_state.last_room_id = snapshot.room_id
	app_runtime.front_settings_state.reconnect_room_id = snapshot.room_id
	# Phase16: Reconnect ticket extension
	app_runtime.front_settings_state.reconnect_room_kind = snapshot.room_kind
	app_runtime.front_settings_state.reconnect_room_display_name = snapshot.room_display_name
	app_runtime.front_settings_state.reconnect_topology = snapshot.topology
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
	app_runtime.front_settings_state.reconnect_state = "active_match" if bool(snapshot.match_active) else "room_only"
	_save_front_settings()


func _on_gateway_canonical_start_config_received(config: BattleStartConfig) -> void:
	if app_runtime == null:
		return
	if app_runtime.has_method("apply_canonical_start_config"):
		app_runtime.apply_canonical_start_config(config)
	# Phase16: Write match_id to reconnect ticket
	if app_runtime.front_settings_state != null and config != null and not config.match_id.is_empty():
		app_runtime.front_settings_state.reconnect_match_id = config.match_id
		app_runtime.front_settings_state.reconnect_state = "active_match"
		_save_front_settings()
	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("request_start_match"):
		app_runtime.front_flow.request_start_match()


func _on_gateway_match_loading_snapshot_received(snapshot: MatchLoadingSnapshot) -> void:
	if app_runtime == null:
		return
	if app_runtime.loading_use_case != null and app_runtime.loading_use_case.has_method("consume_loading_snapshot"):
		app_runtime.loading_use_case.consume_loading_snapshot(snapshot)
	if app_runtime.room_session_controller == null:
		return
	if snapshot == null:
		if app_runtime.room_session_controller.has_method("clear_loading_state"):
			app_runtime.room_session_controller.clear_loading_state()
		return
	if app_runtime.room_session_controller.has_method("set_loading_state"):
		app_runtime.room_session_controller.set_loading_state(
			String(snapshot.phase),
			snapshot.ready_peer_ids,
			snapshot.expected_peer_ids,
			"gateway_match_loading_snapshot"
		)
	if snapshot.is_committed() and app_runtime.room_session_controller.has_method("clear_loading_state"):
		app_runtime.room_session_controller.clear_loading_state()
	elif snapshot.is_aborted() and app_runtime.room_session_controller.has_method("set_last_error"):
		app_runtime.room_session_controller.set_last_error(snapshot.error_code, snapshot.user_message, {})


# Phase17: Handle room member session received
func _on_gateway_room_member_session_received(payload: Dictionary) -> void:
	if app_runtime == null or app_runtime.front_settings_state == null:
		return
	
	var room_id := String(payload.get("room_id", ""))
	var room_kind := String(payload.get("room_kind", ""))
	var room_display_name := String(payload.get("room_display_name", ""))
	var member_id := String(payload.get("member_id", ""))
	var reconnect_token := String(payload.get("reconnect_token", ""))
	
	_log_phase15("room_member_session_received", {
		"room_id": room_id,
		"room_kind": room_kind,
		"member_id": member_id,
	})
	
	# Write to front_settings_state for reconnect capability
	app_runtime.front_settings_state.reconnect_room_id = room_id
	app_runtime.front_settings_state.reconnect_room_kind = room_kind
	app_runtime.front_settings_state.reconnect_room_display_name = room_display_name
	app_runtime.front_settings_state.reconnect_member_id = member_id
	app_runtime.front_settings_state.reconnect_token = reconnect_token
	app_runtime.front_settings_state.reconnect_state = "room_only"
	
	# Preserve host/port from current entry context
	if app_runtime.current_room_entry_context != null:
		app_runtime.front_settings_state.reconnect_host = app_runtime.current_room_entry_context.server_host
		app_runtime.front_settings_state.reconnect_port = app_runtime.current_room_entry_context.server_port
		app_runtime.front_settings_state.reconnect_topology = app_runtime.current_room_entry_context.topology
	_save_front_settings()


# Phase17: Handle match resume accepted
func _on_gateway_match_resume_accepted(config: BattleStartConfig, snapshot: MatchResumeSnapshot) -> void:
	if app_runtime == null:
		return
	
	_log_phase15("match_resume_accepted", {
		"match_id": config.match_id if config != null else "",
		"controlled_peer_id": snapshot.controlled_peer_id if snapshot != null else 0,
	})
	
	# Apply resume payload to app_runtime
	if app_runtime.has_method("apply_match_resume_payload"):
		app_runtime.apply_match_resume_payload(config, snapshot)
	
	# Update reconnect state
	if app_runtime.front_settings_state != null:
		app_runtime.front_settings_state.reconnect_state = "active_match"
		_save_front_settings()
	
	# Trigger loading scene in resume mode
	if app_runtime.front_flow != null:
		if app_runtime.front_flow.has_method("request_resume_match"):
			app_runtime.front_flow.request_resume_match()
		elif app_runtime.front_flow.has_method("request_start_match"):
			app_runtime.front_flow.request_start_match()


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
	if _should_clear_pending_reconnect_ticket(error_code):
		_clear_reconnect_ticket_after_rejected_resume(error_code)
	_clear_pending_online_entry_state()
	if app_runtime != null and app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("set_last_error"):
		app_runtime.room_session_controller.set_last_error(error_code, user_message, {})


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
	}


func _save_front_settings() -> void:
	if app_runtime == null or not ("front_settings_repository" in app_runtime) or not ("front_settings_state" in app_runtime):
		return
	if app_runtime.front_settings_repository == null or app_runtime.front_settings_state == null:
		return
	if app_runtime.front_settings_repository.has_method("save_settings"):
		app_runtime.front_settings_repository.save_settings(app_runtime.front_settings_state)


func _should_clear_pending_reconnect_ticket(error_code: String) -> bool:
	if _pending_online_entry_context == null or not _pending_online_entry_context.use_resume_flow:
		return false
	return [
		"ROOM_NOT_FOUND",
		"MEMBER_NOT_FOUND",
		"RECONNECT_TOKEN_INVALID",
		"RESUME_WINDOW_EXPIRED",
		"MATCH_NOT_ACTIVE",
		"MATCH_ID_MISMATCH",
	].has(error_code)


func _clear_reconnect_ticket_after_rejected_resume(error_code: String) -> void:
	if app_runtime == null or app_runtime.front_settings_state == null:
		return
	if not app_runtime.front_settings_state.has_method("clear_reconnect_ticket"):
		return
	_log_phase15("clear_reconnect_ticket_after_rejected_resume", {
		"error_code": error_code,
		"room_id": String(app_runtime.front_settings_state.reconnect_room_id),
		"member_id": String(app_runtime.front_settings_state.reconnect_member_id),
		"match_id": String(app_runtime.front_settings_state.reconnect_match_id),
	})
	app_runtime.front_settings_state.clear_reconnect_ticket()
	_save_front_settings()


func _schedule_pending_connection_watchdog(connection_config: ClientConnectionConfig) -> void:
	_pending_connection_watchdog_token += 1
	var token := _pending_connection_watchdog_token
	if connection_config == null or app_runtime == null or not is_instance_valid(app_runtime) or not app_runtime.is_inside_tree():
		return
	var timeout_sec: float = max(float(connection_config.connect_timeout_sec), 0.5) + PENDING_CONNECTION_WATCHDOG_GRACE_SEC
	_await_pending_connection_watchdog(token, timeout_sec)


func _await_pending_connection_watchdog(token: int, timeout_sec: float) -> void:
	if app_runtime == null or not is_instance_valid(app_runtime) or not app_runtime.is_inside_tree():
		return
	var deadline_msec := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline_msec:
		await app_runtime.get_tree().process_frame
		if token != _pending_connection_watchdog_token:
			return
		if app_runtime == null or not is_instance_valid(app_runtime) or not app_runtime.is_inside_tree():
			return
	if token != _pending_connection_watchdog_token:
		return
	if not _await_room_before_enter or _pending_online_entry_context == null or _pending_connection_config == null:
		return
	var user_message := "Connection timed out while entering room"
	var timeout_details := _build_pending_connection_context()
	timeout_details["timeout_sec"] = timeout_sec
	timeout_details["room_kind"] = String(_pending_connection_config.room_kind)
	timeout_details["room_display_name"] = String(_pending_connection_config.room_display_name)
	_log_room_anomaly("gateway_room_connect_timeout", timeout_details)
	if app_runtime != null and app_runtime.client_room_runtime != null and app_runtime.client_room_runtime.has_method("disconnect_from_server"):
		app_runtime.client_room_runtime.disconnect_from_server()
	_clear_pending_online_entry_state()
	if app_runtime != null and app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("set_last_error"):
		app_runtime.room_session_controller.set_last_error("ROOM_CONNECT_TIMEOUT", user_message, timeout_details)
	if app_runtime != null and app_runtime.client_room_runtime != null and app_runtime.client_room_runtime.has_signal("room_error"):
		app_runtime.client_room_runtime.room_error.emit("ROOM_CONNECT_TIMEOUT", user_message)


func _clear_pending_online_entry_state() -> void:
	_pending_connection_watchdog_token += 1
	_pending_online_entry_context = null
	_pending_connection_config = null
	_await_room_before_enter = false


func _log_room_anomaly(event_name: String, details: Dictionary) -> void:
	LogNetScript.warn("%s %s %s" % [ROOM_ANOMALY_LOG_PREFIX, event_name, JSON.stringify(details)], "", 0, "front.room.anomaly")


func _log_phase15(event_name: String, details: Dictionary) -> void:
	LogFrontScript.debug("%s[room_use_case] %s %s" % [PHASE15_LOG_PREFIX, event_name, JSON.stringify(details)], "", 0, "front.room.flow")


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
