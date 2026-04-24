class_name RoomUseCase
extends RefCounted

const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const RoomClientGatewayScript = preload("res://network/runtime/room_client/room_client_gateway.gd")
const RoomConnectionOrchestratorScript = preload("res://app/front/room/room_connection_orchestrator.gd")
const RoomBattleEntryBuilderScript = preload("res://app/front/room/room_battle_entry_builder.gd")
const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")
const RoomLeaveCommandScript = preload("res://app/front/room/commands/room_leave_command.gd")
const RoomReadyCommandScript = preload("res://app/front/room/commands/room_ready_command.gd")
const RoomSelectionCommandScript = preload("res://app/front/room/commands/room_selection_command.gd")
const RoomQueueCommandScript = preload("res://app/front/room/commands/room_queue_command.gd")
const RoomBattleEntryCommandScript = preload("res://app/front/room/commands/room_battle_entry_command.gd")
const RoomProfileCommandScript = preload("res://app/front/room/commands/room_profile_command.gd")
const RoomMatchCommandScript = preload("res://app/front/room/commands/room_match_command.gd")
const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")
const RoomSnapshotFlowScript = preload("res://app/front/room/projection/room_snapshot_flow.gd")
const RoomEnterFlowScript = preload("res://app/front/room/recovery/room_enter_flow.gd")
const RoomReconnectFlowScript = preload("res://app/front/room/recovery/room_reconnect_flow.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const LogPayloadSummarizerScript = preload("res://app/logging/log_payload_summarizer.gd")
const LogSamplingPolicyScript = preload("res://app/logging/log_sampling_policy.gd")
const ROOM_USE_CASE_LOG_TAG := "front.room.flow"
const ROOM_ANOMALY_LOG_PREFIX := "[QQT_ROOM_ANOM]"

var app_runtime: Node = null
var room_client_gateway: RoomClientGateway = null
var _connection_orchestrator: RefCounted = RoomConnectionOrchestratorScript.new()
var _runtime_state: RoomUseCaseRuntimeState = RoomUseCaseRuntimeStateScript.new()
var _leave_command: RefCounted = RoomLeaveCommandScript.new()
var _ready_command: RefCounted = RoomReadyCommandScript.new()
var _selection_command: RefCounted = RoomSelectionCommandScript.new()
var _queue_command: RefCounted = RoomQueueCommandScript.new()
var _battle_entry_command: RefCounted = RoomBattleEntryCommandScript.new()
var _profile_command: RefCounted = RoomProfileCommandScript.new()
var _match_command: RefCounted = RoomMatchCommandScript.new()
var _snapshot_flow: RefCounted = RoomSnapshotFlowScript.new()
var _enter_flow: RefCounted = RoomEnterFlowScript.new()
var _reconnect_flow: RefCounted = RoomReconnectFlowScript.new()
var _last_projected_room_view_state: Dictionary = {}
var _last_room_resume_context: Dictionary = {}

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
	_last_projected_room_view_state.clear()
	_last_room_resume_context.clear()
	_snapshot_flow.reset_revision_guard()
	_clear_enter_match_queue_pending("dispose")
	_clear_pending_online_entry_state()


func enter_room(entry_context: RoomEntryContext) -> Dictionary:
	var result: Dictionary = _enter_flow.enter_room(
		app_runtime,
		room_client_gateway,
		_connection_orchestrator,
		entry_context,
		self,
		_on_pending_connection_timeout,
		_on_gateway_transport_connected
	)
	_sync_pending_state_from_orchestrator()
	return result


func leave_room() -> Dictionary:
	_clear_enter_match_queue_pending("leave_room")
	var result: Dictionary = _leave_command.leave_room(app_runtime, room_client_gateway)
	if not bool(result.get("ok", false)):
		return result
	_last_projected_room_view_state.clear()
	_last_room_resume_context.clear()
	_snapshot_flow.reset_revision_guard()
	_clear_pending_online_entry_state()
	return result


func update_local_profile(
	player_name: String,
	character_id: String,
	character_skin_id: String,
	bubble_style_id: String,
	bubble_skin_id: String,
	team_id: int = 1
) -> Dictionary:
	return _profile_command.update_local_profile(
		app_runtime,
		room_client_gateway,
		player_name,
		character_id,
		character_skin_id,
		bubble_style_id,
		bubble_skin_id,
		team_id
	)


func update_selection(map_id: String, rule_id: String, mode_id: String) -> Dictionary:
	return _selection_command.update_selection(app_runtime, room_client_gateway, map_id, rule_id, mode_id)


func toggle_ready() -> Dictionary:
	return _ready_command.toggle_ready(app_runtime, room_client_gateway)


func start_match() -> Dictionary:
	return _match_command.start_match(app_runtime, room_client_gateway)


func update_match_room_config(match_format_id: String, selected_mode_ids: Array[String]) -> Dictionary:
	return _match_command.update_match_room_config(app_runtime, room_client_gateway, match_format_id, selected_mode_ids)


func enter_match_queue() -> Dictionary:
	_log_room("enter_match_queue_called", {
		"is_match_room": RoomUseCaseRuntimeStateScript.is_match_room(app_runtime),
		"is_online_room": RoomUseCaseRuntimeStateScript.is_online_room(app_runtime),
		"has_gateway": room_client_gateway != null,
		"has_method": room_client_gateway.has_method("request_enter_match_queue") if room_client_gateway != null else false,
		"pending": _runtime_state.enter_match_queue_pending,
		"pending_room_id": _runtime_state.enter_match_queue_pending_room_id,
	})
	var queue_check: Dictionary = _queue_command.can_enter_match_queue(app_runtime, room_client_gateway)
	if not bool(queue_check.get("ok", false)):
		return queue_check
	if _runtime_state.enter_match_queue_pending:
		_log_room("enter_match_queue_duplicate_ignored", {
			"pending_room_id": _runtime_state.enter_match_queue_pending_room_id,
		})
		return {"ok": true, "error_code": "", "user_message": "Entering match queue...", "pending": true}
	_mark_enter_match_queue_pending()
	_log_room("enter_match_queue_sending", {})
	return _queue_command.request_enter_match_queue(app_runtime, room_client_gateway)


func cancel_match_queue() -> Dictionary:
	return _queue_command.request_cancel_match_queue(app_runtime, room_client_gateway)


func request_rematch() -> Dictionary:
	return _match_command.request_rematch(app_runtime, room_client_gateway)


func on_authoritative_snapshot(snapshot: RoomSnapshot) -> void:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return
	_sync_pending_state_from_orchestrator()
	if app_runtime.current_room_entry_context == null and _runtime_state.pending_online_entry_context == null:
		return
	var queue_ack_reason: String = _queue_command.acknowledge_enter_match_queue_pending(_runtime_state, snapshot)
	if not queue_ack_reason.is_empty():
		_clear_enter_match_queue_pending(queue_ack_reason)
	var flow_result: Dictionary = _snapshot_flow.consume_authoritative_snapshot(app_runtime, snapshot, _last_projected_room_view_state)
	_last_projected_room_view_state = flow_result.get("view_state", {}) if flow_result.has("view_state") else {}
	_last_room_resume_context = flow_result.get("resume_context", {}) if flow_result.has("resume_context") else {}


func get_projected_room_view_state() -> Dictionary:
	return _last_projected_room_view_state.duplicate(true)


func get_room_resume_context() -> Dictionary:
	return _last_room_resume_context.duplicate(true)

func build_room_connection_config(entry_context: RoomEntryContext) -> ClientConnectionConfig:
	var result := RoomConnectionOrchestratorScript.build_connection_config(app_runtime, entry_context)
	return result.get("config", null)


func build_battle_entry_context(snapshot: RoomSnapshot = null):
	var target_snapshot := snapshot
	if target_snapshot == null and app_runtime != null:
		target_snapshot = app_runtime.current_room_snapshot
	var room_entry_context = app_runtime.current_room_entry_context if app_runtime != null else null
	var ctx = RoomBattleEntryBuilderScript.build(target_snapshot, room_entry_context)
	var battle_entry_check: Dictionary = _battle_entry_command.can_use_battle_entry_context(app_runtime, ctx)
	if not bool(battle_entry_check.get("ok", false)):
		return null
	_log_room("battle_entry_context_built", {
		"assignment_id": ctx.assignment_id,
		"battle_id": ctx.battle_id,
		"battle_server_host": ctx.battle_server_host,
		"battle_server_port": ctx.battle_server_port,
		"source_room_id": ctx.source_room_id,
	})
	return ctx


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
	_enter_flow.dispatch_transport_connected(app_runtime, room_client_gateway, _connection_orchestrator, _runtime_state, self)


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
	if _runtime_state.await_room_before_enter:
		if app_runtime == null or app_runtime.front_flow == null or not app_runtime.front_flow.has_method("enter_room"):
			_log_room_anomaly("awaiting_room_but_front_flow_missing", RoomUseCaseRuntimeStateScript.build_snapshot_context(snapshot, _build_pending_connection_context()))
		else:
			app_runtime.front_flow.enter_room()
	_clear_pending_online_entry_state()


func _on_gateway_canonical_start_config_received(config: BattleStartConfig) -> void:
	if app_runtime == null:
		return
	if app_runtime.has_method("apply_canonical_start_config"):
		app_runtime.apply_canonical_start_config(config)
	_reconnect_flow.apply_canonical_start_config(app_runtime, config)
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
	_reconnect_flow.apply_room_member_session(app_runtime, payload, self)


func _on_gateway_match_resume_accepted(config: BattleStartConfig, snapshot: MatchResumeSnapshot) -> void:
	if app_runtime == null:
		return
	_reconnect_flow.apply_match_resume_accepted(app_runtime, config, snapshot, self)
	if app_runtime.front_flow != null:
		if app_runtime.front_flow.has_method("request_resume_match"):
			app_runtime.front_flow.request_resume_match()
		elif app_runtime.front_flow.has_method("request_start_match"):
			app_runtime.front_flow.request_start_match()


func _on_gateway_room_error(error_code: String, user_message: String) -> void:
	_sync_pending_state_from_orchestrator()
	_clear_enter_match_queue_pending("room_error:%s" % error_code)
	_log_room_anomaly("gateway_room_error", {
		"error_code": error_code,
		"user_message": user_message,
		"await_room_before_enter": _runtime_state.await_room_before_enter,
		"pending_entry_kind": String(_runtime_state.pending_online_entry_context.entry_kind) if _runtime_state.pending_online_entry_context != null else "",
		"pending_topology": String(_runtime_state.pending_online_entry_context.topology) if _runtime_state.pending_online_entry_context != null else "",
		"pending_server_host": String(_runtime_state.pending_connection_config.server_host) if _runtime_state.pending_connection_config != null else "",
		"pending_server_port": int(_runtime_state.pending_connection_config.server_port) if _runtime_state.pending_connection_config != null else 0,
		"pending_room_id_hint": String(_runtime_state.pending_connection_config.room_id_hint) if _runtime_state.pending_connection_config != null else "",
	})
	if _should_clear_pending_reconnect_ticket(error_code):
		_clear_reconnect_ticket_after_rejected_resume(error_code)
	_clear_pending_online_entry_state()
	if app_runtime != null and app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("set_last_error"):
		app_runtime.room_session_controller.set_last_error(error_code, user_message, {})


func _fail(error_code: String, user_message: String) -> Dictionary:
	return RoomErrorMapperScript.to_front_error(error_code, user_message)


func _should_clear_pending_reconnect_ticket(error_code: String) -> bool:
	return _reconnect_flow.should_clear_pending_reconnect_ticket(
		_runtime_state.pending_online_entry_context,
		error_code,
		app_runtime.front_settings_state if app_runtime != null else null
	)


func _clear_reconnect_ticket_after_rejected_resume(error_code: String) -> void:
	_reconnect_flow.clear_reconnect_ticket_after_rejected_resume(app_runtime, error_code, self)


func _on_pending_connection_timeout(timeout_sec: float) -> void:
	_sync_pending_state_from_orchestrator()
	var user_message := "Connection timed out while entering room"
	var timeout_details := _build_pending_connection_context()
	timeout_details["timeout_sec"] = timeout_sec
	timeout_details["room_kind"] = String(_runtime_state.pending_connection_config.room_kind) if _runtime_state.pending_connection_config != null else ""
	timeout_details["room_display_name"] = String(_runtime_state.pending_connection_config.room_display_name) if _runtime_state.pending_connection_config != null else ""
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


func _mark_enter_match_queue_pending() -> void:
	_runtime_state.mark_enter_match_queue_pending(_current_room_id())
	_log_room("enter_match_queue_pending_marked", {
		"room_id": _runtime_state.enter_match_queue_pending_room_id,
	})


func _clear_enter_match_queue_pending(reason: String) -> void:
	if not _runtime_state.enter_match_queue_pending and _runtime_state.enter_match_queue_pending_room_id.is_empty():
		return
	_log_room("enter_match_queue_pending_cleared", {
		"reason": reason,
		"room_id": _runtime_state.enter_match_queue_pending_room_id,
	})
	_runtime_state.clear_enter_match_queue_pending()


func _current_room_id() -> String:
	if app_runtime != null and app_runtime.current_room_snapshot != null:
		return String(app_runtime.current_room_snapshot.room_id)
	if app_runtime != null and app_runtime.current_room_entry_context != null:
		return String(app_runtime.current_room_entry_context.target_room_id)
	return ""


func _sync_pending_state_from_orchestrator() -> void:
	_runtime_state.sync_pending_connection(_connection_orchestrator)


func _log_room_anomaly(event_name: String, details: Dictionary) -> void:
	var summary := _summarize_room_log_payload(event_name, details)
	LogNetScript.warn("%s %s %s" % [ROOM_ANOMALY_LOG_PREFIX, event_name, JSON.stringify(summary)], "", 0, "front.room.anomaly")


func _log_room(event_name: String, details: Dictionary) -> void:
	if not LogSamplingPolicyScript.should_log("%s.%s" % [ROOM_USE_CASE_LOG_TAG, event_name], _room_log_sample_every(event_name)):
		return
	var summary := _summarize_room_log_payload(event_name, details)
	LogFrontScript.debug("[room_use_case] %s %s" % [event_name, JSON.stringify(summary)], "", 0, ROOM_USE_CASE_LOG_TAG)


func _build_pending_connection_context() -> Dictionary:
	_sync_pending_state_from_orchestrator()
	return _connection_orchestrator.build_pending_connection_context()


func _room_log_sample_every(event_name: String) -> int:
	match event_name:
		"authoritative_room_snapshot_received", "enter_match_queue_called":
			return 10
		_:
			return 1


func _summarize_room_log_payload(event_name: String, details: Dictionary) -> Dictionary:
	if event_name.find("snapshot") >= 0 or details.has("snapshot_revision") or details.has("member_count"):
		var summary := LogPayloadSummarizerScript.summarize_room_snapshot(details)
		if summary.is_empty():
			return details
		for key in ["room_kind", "queue_type", "match_format_id", "entry_kind", "room_id_hint", "error_code"]:
			if details.has(key):
				summary[key] = details[key]
		return summary
	var result := details.duplicate(false)
	for key in ["members", "selected_match_mode_ids", "payload", "snapshot"]:
		if result.has(key):
			result.erase(key)
	return result
