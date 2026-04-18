class_name RoomUseCase
extends RefCounted

const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const RoomClientGatewayScript = preload("res://network/runtime/room_client_gateway.gd")
const RoomSelectionPolicyScript = preload("res://app/front/room/room_selection_policy.gd")
const RoomConnectionOrchestratorScript = preload("res://app/front/room/room_connection_orchestrator.gd")
const RoomBattleEntryBuilderScript = preload("res://app/front/room/room_battle_entry_builder.gd")
const RoomReconnectCoordinatorScript = preload("res://app/front/room/room_reconnect_coordinator.gd")
const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const ROOM_USE_CASE_LOG_TAG := "front.room.flow"
const ROOM_ANOMALY_LOG_PREFIX := "[QQT_ROOM_ANOM]"

var app_runtime: Node = null
var room_client_gateway: RoomClientGateway = null
var _connection_orchestrator: RefCounted = RoomConnectionOrchestratorScript.new()
var _pending_online_entry_context: RoomEntryContext = null
var _pending_connection_config: ClientConnectionConfig = null
var _await_room_before_enter: bool = false

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
	if RoomUseCaseRuntimeStateScript.is_matchmade_room(app_runtime, entry_context):
		# Only force lobby return if room_return_policy is not return_to_source_room.
		if not RoomUseCaseRuntimeStateScript.has_source_room_return_policy(app_runtime, entry_context):
			entry_context.return_target = FrontReturnTargetScript.LOBBY
			entry_context.return_to_lobby_after_settlement = true
	app_runtime.current_room_entry_context = entry_context.duplicate_deep() if entry_context != null else RoomEntryContext.new()

	if entry_context != null and String(entry_context.topology) == FrontTopologyScript.DEDICATED_SERVER and String(entry_context.room_kind) != FrontRoomKindScript.PRACTICE:
		if app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("reset_room_state"):
			app_runtime.room_session_controller.reset_room_state()
		var connection_config := _build_connection_config(entry_context)
		_log_room("enter_dedicated_room_requested", {
			"entry_kind": String(entry_context.entry_kind),
			"room_kind": String(entry_context.room_kind),
			"server_host": String(connection_config.server_host),
			"server_port": int(connection_config.server_port),
			"room_id_hint": String(connection_config.room_id_hint),
			"room_display_name": String(connection_config.room_display_name),
		})
		if room_client_gateway != null:
			_connection_orchestrator.begin_pending_connection(entry_context, connection_config)
			_sync_pending_state_from_orchestrator()
			_schedule_pending_connection_watchdog(_pending_connection_config)
			if _has_ready_transport_for(connection_config):
				_log_room("enter_room_reusing_connected_transport", {
					"server_host": String(connection_config.server_host),
					"server_port": int(connection_config.server_port),
					"entry_kind": String(entry_context.entry_kind),
					"room_kind": String(entry_context.room_kind),
				})
				_on_gateway_transport_connected()
			else:
				room_client_gateway.connect_to_server(connection_config)
		else:
			_log_room_anomaly("enter_room_missing_gateway", RoomUseCaseRuntimeStateScript.build_entry_context_context(entry_context))
		return {"ok": true, "error_code": "", "user_message": "", "pending": true}

	if app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_room"):
		app_runtime.front_flow.enter_room()
	return {"ok": true, "error_code": "", "user_message": ""}


func leave_room() -> Dictionary:
	if app_runtime == null:
		return _fail("APP_RUNTIME_MISSING", "App runtime is not configured")
	# matchmade_room no longer forces lobby return; room_return_policy governs this.
	if RoomUseCaseRuntimeStateScript.is_matchmade_room(app_runtime):
		var return_policy := ""
		if app_runtime.current_room_snapshot != null:
			return_policy = String(app_runtime.current_room_snapshot.room_return_policy)
		if return_policy != "return_to_source_room":
			if app_runtime.current_room_entry_context != null:
				app_runtime.current_room_entry_context.return_target = FrontReturnTargetScript.LOBBY
				app_runtime.current_room_entry_context.return_to_lobby_after_settlement = true
	if room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		if RoomUseCaseRuntimeStateScript.is_match_room(app_runtime) and RoomUseCaseRuntimeStateScript.get_current_room_queue_state(app_runtime) == "queueing" and room_client_gateway.has_method("request_cancel_match_queue"):
			room_client_gateway.request_cancel_match_queue()
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
	var effective_team_id := team_id
	if RoomUseCaseRuntimeStateScript.is_matchmade_room(app_runtime):
		effective_team_id = _resolve_locked_team_id(team_id)
	var result: Dictionary = app_runtime.room_session_controller.request_update_member_profile(
		int(app_runtime.local_peer_id),
		player_name,
		character_id,
		character_skin_id,
		bubble_style_id,
		bubble_skin_id,
		effective_team_id
	)
	if bool(result.get("ok", false)) and room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		room_client_gateway.request_update_profile(player_name, character_id, character_skin_id, bubble_style_id, bubble_skin_id, effective_team_id)
	return result


func update_selection(map_id: String, rule_id: String, mode_id: String) -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return _fail("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	if RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return _fail("MATCH_ROOM_SELECTION_FORBIDDEN", "Match room selection is controlled by match format and mode pool")
	if RoomUseCaseRuntimeStateScript.is_matchmade_room(app_runtime):
		return _fail("MATCHMADE_SELECTION_LOCKED", "Matchmade room selection is locked")
	var result: Dictionary = app_runtime.room_session_controller.request_update_selection(
		int(app_runtime.local_peer_id),
		map_id,
		rule_id,
		mode_id
	)
	if bool(result.get("ok", false)) and room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		room_client_gateway.request_update_selection(map_id, rule_id, mode_id)
	return result


func toggle_ready() -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return _fail("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	if RoomUseCaseRuntimeStateScript.is_matchmade_room(app_runtime):
		return _fail("MATCHMADE_READY_LOCKED", "Matchmade room readiness is automatic")
	var result: Dictionary = app_runtime.room_session_controller.request_toggle_ready(int(app_runtime.local_peer_id))
	if bool(result.get("ok", false)) and room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		room_client_gateway.request_toggle_ready()
	return result


func start_match() -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return _fail("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	if RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return _fail("MATCH_ROOM_START_FORBIDDEN", "Match rooms must enter matchmaking queue")
	if room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
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


func update_match_room_config(match_format_id: String, selected_mode_ids: Array[String]) -> Dictionary:
	if not RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return _fail("NOT_MATCH_ROOM", "Match room config can only be updated in match rooms")
	if room_client_gateway == null or not RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		return _fail("ROOM_GATEWAY_MISSING", "Room gateway is not available")
	if not room_client_gateway.has_method("request_update_match_room_config"):
		return _fail("MATCH_ROOM_PROTOCOL_MISSING", "Match room protocol is not available")
	room_client_gateway.request_update_match_room_config(match_format_id, selected_mode_ids)
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


func enter_match_queue() -> Dictionary:
	_log_room("enter_match_queue_called", {
		"is_match_room": RoomUseCaseRuntimeStateScript.is_match_room(app_runtime),
		"is_online_room": RoomUseCaseRuntimeStateScript.is_online_room(app_runtime),
		"has_gateway": room_client_gateway != null,
		"has_method": room_client_gateway.has_method("request_enter_match_queue") if room_client_gateway != null else false,
	})
	if not RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return _fail("NOT_MATCH_ROOM", "Queue can only be entered from match rooms")
	if room_client_gateway == null or not RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		return _fail("ROOM_GATEWAY_MISSING", "Room gateway is not available")
	if not room_client_gateway.has_method("request_enter_match_queue"):
		return _fail("MATCH_ROOM_PROTOCOL_MISSING", "Match room protocol is not available")
	_log_room("enter_match_queue_sending", {})
	room_client_gateway.request_enter_match_queue()
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


func cancel_match_queue() -> Dictionary:
	if not RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return _fail("NOT_MATCH_ROOM", "Queue can only be cancelled from match rooms")
	if room_client_gateway == null or not RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		return _fail("ROOM_GATEWAY_MISSING", "Room gateway is not available")
	if not room_client_gateway.has_method("request_cancel_match_queue"):
		return _fail("MATCH_ROOM_PROTOCOL_MISSING", "Match room protocol is not available")
	room_client_gateway.request_cancel_match_queue()
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


func request_rematch() -> Dictionary:
	if app_runtime == null or room_client_gateway == null:
		return _fail("ROOM_USE_CASE_MISSING", "App runtime or gateway is not configured")
	if RoomUseCaseRuntimeStateScript.is_matchmade_room(app_runtime):
		return _fail("MATCHMADE_REMATCH_FORBIDDEN", "Matchmade rooms return to lobby after settlement")
	if not RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		return _fail("NOT_ONLINE_ROOM", "Rematch is only supported in online rooms")
	room_client_gateway.request_rematch()
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


func on_authoritative_snapshot(snapshot: RoomSnapshot) -> void:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return
	_sync_pending_state_from_orchestrator()
	if app_runtime.current_room_entry_context == null and _pending_online_entry_context == null:
		return
	app_runtime.room_session_controller.apply_authoritative_snapshot(snapshot)
	app_runtime.current_room_snapshot = snapshot.duplicate_deep() if snapshot != null else null
	_update_reconnect_state(snapshot)

func build_room_connection_config(entry_context: RoomEntryContext) -> ClientConnectionConfig:
	return _build_connection_config(entry_context)


func build_battle_entry_context(snapshot: RoomSnapshot = null):
	var target_snapshot := snapshot
	if target_snapshot == null and app_runtime != null:
		target_snapshot = app_runtime.current_room_snapshot
	var room_entry_context = app_runtime.current_room_entry_context if app_runtime != null else null
	var ctx = RoomBattleEntryBuilderScript.build(target_snapshot, room_entry_context)
	if ctx == null:
		return null
	_log_room("battle_entry_context_built", {
		"assignment_id": ctx.assignment_id,
		"battle_id": ctx.battle_id,
		"battle_server_host": ctx.battle_server_host,
		"battle_server_port": ctx.battle_server_port,
		"source_room_id": ctx.source_room_id,
	})
	return ctx


func _build_connection_config(entry_context: RoomEntryContext) -> ClientConnectionConfig:
	var result := RoomConnectionOrchestratorScript.build_connection_config(app_runtime, entry_context)
	var config = result.get("config", null)
	var changed_fields: Array = result.get("changed_fields", [])
	if not changed_fields.is_empty():
		_log_room("connection_loadout_normalized", {
			"entry_kind": String(entry_context.entry_kind),
			"room_kind": String(entry_context.room_kind),
			"changed_fields": changed_fields,
		})
	if config == null:
		return null
	_log_room("connection_selection_resolved", {
		"entry_kind": String(entry_context.entry_kind),
		"room_kind": String(entry_context.room_kind),
		"topology": String(entry_context.topology),
		"selected_map_id": config.selected_map_id,
		"selected_rule_set_id": config.selected_rule_set_id,
		"selected_mode_id": config.selected_mode_id,
		"target_room_id": String(entry_context.target_room_id),
	})
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


func _has_ready_transport_for(connection_config: ClientConnectionConfig) -> bool:
	return RoomConnectionOrchestratorScript.has_ready_transport_for(app_runtime, connection_config)


func _resolve_locked_team_id(fallback_team_id: int) -> int:
	if app_runtime == null:
		return fallback_team_id
	return RoomSelectionPolicyScript.resolve_locked_team_id(
		app_runtime.current_room_snapshot,
		app_runtime.current_room_entry_context,
		int(app_runtime.local_peer_id),
		fallback_team_id
	)


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
	if room_client_gateway.has_signal("room_member_session_received") and room_client_gateway.room_member_session_received.is_connected(_on_gateway_room_member_session_received):
		room_client_gateway.room_member_session_received.disconnect(_on_gateway_room_member_session_received)
	if room_client_gateway.has_signal("match_resume_accepted") and room_client_gateway.match_resume_accepted.is_connected(_on_gateway_match_resume_accepted):
		room_client_gateway.match_resume_accepted.disconnect(_on_gateway_match_resume_accepted)


func _on_gateway_transport_connected() -> void:
	if room_client_gateway == null:
		_log_room_anomaly("transport_connected_without_gateway", {})
		return
	_sync_pending_state_from_orchestrator()
	if _pending_online_entry_context == null or _pending_connection_config == null:
		_log_room_anomaly("transport_connected_without_pending_entry", {
			"has_pending_entry": _pending_online_entry_context != null,
			"has_pending_config": _pending_connection_config != null,
		})
		return
	if _connection_orchestrator.dispatch_transport_connected(room_client_gateway, self):
		return
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
		_log_room_anomaly("received_snapshot_without_room_id", RoomUseCaseRuntimeStateScript.build_snapshot_context(snapshot, _build_pending_connection_context()))
	if String(snapshot.topology) == FrontTopologyScript.DEDICATED_SERVER and snapshot.members.is_empty():
		_log_room_anomaly("received_snapshot_without_members", RoomUseCaseRuntimeStateScript.build_snapshot_context(snapshot, _build_pending_connection_context()))
	on_authoritative_snapshot(snapshot)
	_log_room("authoritative_room_snapshot_received", {
		"room_id": String(snapshot.room_id),
		"room_kind": String(snapshot.room_kind),
		"room_display_name": String(snapshot.room_display_name),
		"member_count": snapshot.members.size(),
		"match_active": bool(snapshot.match_active),
	})
	if _await_room_before_enter:
		if app_runtime == null or app_runtime.front_flow == null or not app_runtime.front_flow.has_method("enter_room"):
			_log_room_anomaly("awaiting_room_but_front_flow_missing", RoomUseCaseRuntimeStateScript.build_snapshot_context(snapshot, _build_pending_connection_context()))
		else:
			app_runtime.front_flow.enter_room()
	_clear_pending_online_entry_state()


func _update_reconnect_state(snapshot: RoomSnapshot) -> void:
	RoomReconnectCoordinatorScript.apply_authoritative_snapshot(app_runtime, snapshot)


func _on_gateway_canonical_start_config_received(config: BattleStartConfig) -> void:
	if app_runtime == null:
		return
	if app_runtime.has_method("apply_canonical_start_config"):
		app_runtime.apply_canonical_start_config(config)
	RoomReconnectCoordinatorScript.apply_canonical_start_config(app_runtime, config)
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


func _on_gateway_room_member_session_received(payload: Dictionary) -> void:
	RoomReconnectCoordinatorScript.apply_room_member_session(app_runtime, payload, self)


func _on_gateway_match_resume_accepted(config: BattleStartConfig, snapshot: MatchResumeSnapshot) -> void:
	if app_runtime == null:
		return
	RoomReconnectCoordinatorScript.apply_match_resume_accepted(app_runtime, config, snapshot, self)
	if app_runtime.front_flow != null:
		if app_runtime.front_flow.has_method("request_resume_match"):
			app_runtime.front_flow.request_resume_match()
		elif app_runtime.front_flow.has_method("request_start_match"):
			app_runtime.front_flow.request_start_match()


func _on_gateway_room_error(error_code: String, user_message: String) -> void:
	_sync_pending_state_from_orchestrator()
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


func _should_clear_pending_reconnect_ticket(error_code: String) -> bool:
	return RoomReconnectCoordinatorScript.should_clear_pending_reconnect_ticket(_pending_online_entry_context, error_code)


func _clear_reconnect_ticket_after_rejected_resume(error_code: String) -> void:
	RoomReconnectCoordinatorScript.clear_reconnect_ticket_after_rejected_resume(app_runtime, error_code, self)


func _schedule_pending_connection_watchdog(connection_config: ClientConnectionConfig) -> void:
	if connection_config == null:
		return
	_connection_orchestrator.schedule_pending_connection_watchdog(app_runtime, _on_pending_connection_timeout)


func _on_pending_connection_timeout(timeout_sec: float) -> void:
	_sync_pending_state_from_orchestrator()
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
	_connection_orchestrator.clear_pending_connection()
	_sync_pending_state_from_orchestrator()


func _sync_pending_state_from_orchestrator() -> void:
	_pending_online_entry_context = _connection_orchestrator.pending_online_entry_context
	_pending_connection_config = _connection_orchestrator.pending_connection_config
	_await_room_before_enter = bool(_connection_orchestrator.await_room_before_enter)


func _log_room_anomaly(event_name: String, details: Dictionary) -> void:
	LogNetScript.warn("%s %s %s" % [ROOM_ANOMALY_LOG_PREFIX, event_name, JSON.stringify(details)], "", 0, "front.room.anomaly")


func _log_room(event_name: String, details: Dictionary) -> void:
	LogFrontScript.debug("[room_use_case] %s %s" % [event_name, JSON.stringify(details)], "", 0, ROOM_USE_CASE_LOG_TAG)


func _build_pending_connection_context() -> Dictionary:
	_sync_pending_state_from_orchestrator()
	return _connection_orchestrator.build_pending_connection_context()
