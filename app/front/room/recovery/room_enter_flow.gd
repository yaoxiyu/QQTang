class_name RoomEnterFlow
extends RefCounted

const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const RoomConnectionOrchestratorScript = preload("res://app/front/room/room_connection_orchestrator.gd")
const RoomEnterCommandScript = preload("res://app/front/room/commands/room_enter_command.gd")
const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")

var _enter_command: RefCounted = RoomEnterCommandScript.new()


func enter_room(
	app_runtime: Object,
	room_client_gateway: RefCounted,
	orchestrator: RefCounted,
	entry_context: RoomEntryContext,
	log_sink: Object,
	pending_timeout_callback: Callable,
	transport_connected_callback: Callable
) -> Dictionary:
	var enter_check: Dictionary = _enter_command.can_enter(app_runtime, entry_context)
	if not bool(enter_check.get("ok", false)):
		_log_anomaly(log_sink, "enter_room_rejected", enter_check)
		return enter_check
	_apply_matchmade_return_policy(app_runtime, entry_context)
	app_runtime.current_room_entry_context = entry_context.duplicate_deep() if entry_context != null else RoomEntryContext.new()

	if not _enter_command.should_use_online_dedicated_room(entry_context):
		if app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_room"):
			app_runtime.front_flow.enter_room()
		return {"ok": true, "error_code": "", "user_message": ""}

	if app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("reset_room_state"):
		app_runtime.room_session_controller.reset_room_state()
	var connection_config := _build_connection_config(app_runtime, entry_context, log_sink)
	if connection_config == null:
		_log_anomaly(log_sink, "enter_room_connection_config_missing", RoomUseCaseRuntimeStateScript.build_entry_context_context(entry_context))
		return {"ok": false, "error_code": "ROOM_CONNECTION_CONFIG_MISSING", "user_message": "Room connection config is missing"}
	_log(log_sink, "enter_dedicated_room_requested", {
		"entry_kind": String(entry_context.entry_kind),
		"room_kind": String(entry_context.room_kind),
		"server_host": String(connection_config.server_host),
		"server_port": int(connection_config.server_port),
		"room_id_hint": String(connection_config.room_id_hint),
		"room_display_name": String(connection_config.room_display_name),
		"match_format_id": String(connection_config.match_format_id),
		"selected_mode_ids": connection_config.selected_mode_ids,
	})
	if room_client_gateway == null:
		_log_anomaly(log_sink, "enter_room_missing_gateway", RoomUseCaseRuntimeStateScript.build_entry_context_context(entry_context))
		return {"ok": true, "error_code": "", "user_message": "", "pending": true}
	orchestrator.begin_pending_connection(entry_context, connection_config)
	_schedule_pending_connection_watchdog(orchestrator, app_runtime, pending_timeout_callback)
	if RoomConnectionOrchestratorScript.has_ready_transport_for(app_runtime, connection_config):
		_log(log_sink, "enter_room_reusing_connected_transport", {
			"server_host": String(connection_config.server_host),
			"server_port": int(connection_config.server_port),
			"entry_kind": String(entry_context.entry_kind),
			"room_kind": String(entry_context.room_kind),
		})
		if transport_connected_callback.is_valid():
			transport_connected_callback.call()
	else:
		room_client_gateway.connect_to_server(connection_config)
	return {"ok": true, "error_code": "", "user_message": "", "pending": true}


func dispatch_transport_connected(
	app_runtime: Object,
	room_client_gateway: RefCounted,
	orchestrator: RefCounted,
	runtime_state: RoomUseCaseRuntimeState,
	log_sink: Object
) -> void:
	if room_client_gateway == null:
		_log_anomaly(log_sink, "transport_connected_without_gateway", {})
		return
	runtime_state.sync_pending_connection(orchestrator)
	if runtime_state.pending_online_entry_context == null or runtime_state.pending_connection_config == null:
		_log_anomaly(log_sink, "transport_connected_without_pending_entry", {
			"has_pending_entry": runtime_state.pending_online_entry_context != null,
			"has_pending_config": runtime_state.pending_connection_config != null,
		})
		return
	if orchestrator.dispatch_transport_connected(room_client_gateway, log_sink):
		return
	_log_anomaly(log_sink, "transport_connected_with_unknown_entry_kind", {
		"entry_kind": String(runtime_state.pending_online_entry_context.entry_kind),
		"topology": String(runtime_state.pending_online_entry_context.topology),
		"room_id_hint": String(runtime_state.pending_connection_config.room_id_hint),
	})


func _apply_matchmade_return_policy(app_runtime: Object, entry_context: RoomEntryContext) -> void:
	if not RoomUseCaseRuntimeStateScript.is_matchmade_room(app_runtime, entry_context):
		return
	if RoomUseCaseRuntimeStateScript.has_source_room_return_policy(app_runtime, entry_context):
		return
	entry_context.return_target = FrontReturnTargetScript.LOBBY
	entry_context.return_to_lobby_after_settlement = true


func _build_connection_config(app_runtime: Object, entry_context: RoomEntryContext, log_sink: Object) -> ClientConnectionConfig:
	var result := RoomConnectionOrchestratorScript.build_connection_config(app_runtime, entry_context)
	var config = result.get("config", null)
	var changed_fields: Array = result.get("changed_fields", [])
	if not changed_fields.is_empty():
		_log(log_sink, "connection_loadout_normalized", {
			"entry_kind": String(entry_context.entry_kind),
			"room_kind": String(entry_context.room_kind),
			"changed_fields": changed_fields,
		})
	if config == null:
		return null
	_log(log_sink, "connection_selection_resolved", {
		"entry_kind": String(entry_context.entry_kind),
		"room_kind": String(entry_context.room_kind),
		"topology": String(entry_context.topology),
		"selected_map_id": config.selected_map_id,
		"selected_rule_set_id": config.selected_rule_set_id,
		"selected_mode_id": config.selected_mode_id,
		"match_format_id": String(config.match_format_id),
		"selected_mode_ids": config.selected_mode_ids,
		"target_room_id": String(entry_context.target_room_id),
	})
	if config.server_host.strip_edges().is_empty() or config.server_port <= 0:
		_log_anomaly(log_sink, "invalid_connection_config", {
			"entry_kind": String(entry_context.entry_kind),
			"room_kind": String(entry_context.room_kind),
			"topology": String(entry_context.topology),
			"server_host": config.server_host,
			"server_port": config.server_port,
			"room_id_hint": config.room_id_hint,
		})
	return config


func _schedule_pending_connection_watchdog(orchestrator: RefCounted, app_runtime: Object, pending_timeout_callback: Callable) -> void:
	if orchestrator == null or orchestrator.pending_connection_config == null:
		return
	orchestrator.schedule_pending_connection_watchdog(app_runtime, pending_timeout_callback)


func _log(log_sink: Object, event_name: String, payload: Dictionary) -> void:
	if log_sink != null and log_sink.has_method("_log_room"):
		log_sink._log_room(event_name, payload)


func _log_anomaly(log_sink: Object, event_name: String, payload: Dictionary) -> void:
	if log_sink != null and log_sink.has_method("_log_room_anomaly"):
		log_sink._log_room_anomaly(event_name, payload)
