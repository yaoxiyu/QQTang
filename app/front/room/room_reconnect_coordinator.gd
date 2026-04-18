extends RefCounted

const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")

const RESUME_TICKET_CLEAR_ERROR_CODES := [
	"ROOM_NOT_FOUND",
	"MEMBER_NOT_FOUND",
	"RECONNECT_TOKEN_INVALID",
	"RESUME_WINDOW_EXPIRED",
	"MATCH_NOT_ACTIVE",
	"MATCH_ID_MISMATCH",
	"ROOM_TICKET_ACCOUNT_MISMATCH",
	"ROOM_TICKET_PROFILE_MISMATCH",
	"ROOM_TICKET_EXPIRED",
	"ROOM_TICKET_ID_MISMATCH",
	"ROOM_TICKET_TARGET_INVALID",
]


static func apply_authoritative_snapshot(app_runtime: Object, snapshot: RoomSnapshot) -> void:
	if app_runtime == null or app_runtime.front_settings_state == null or snapshot == null:
		return
	if String(snapshot.topology) != FrontTopologyScript.DEDICATED_SERVER:
		return
	if snapshot.room_id.is_empty():
		return
	app_runtime.front_settings_state.last_room_id = snapshot.room_id
	app_runtime.front_settings_state.reconnect_room_id = snapshot.room_id
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
	_save_front_settings(app_runtime)


static func apply_canonical_start_config(app_runtime: Object, config: BattleStartConfig) -> void:
	if app_runtime == null or app_runtime.front_settings_state == null or config == null or config.match_id.is_empty():
		return
	app_runtime.front_settings_state.reconnect_match_id = config.match_id
	app_runtime.front_settings_state.reconnect_state = "active_match"
	_save_front_settings(app_runtime)


static func apply_room_member_session(app_runtime: Object, payload: Dictionary, log_sink: Object = null) -> void:
	if app_runtime == null or app_runtime.front_settings_state == null:
		return
	var room_id := String(payload.get("room_id", ""))
	var room_kind := String(payload.get("room_kind", ""))
	var room_display_name := String(payload.get("room_display_name", ""))
	var member_id := String(payload.get("member_id", ""))
	var reconnect_token := String(payload.get("reconnect_token", ""))
	_log(log_sink, "room_member_session_received", {
		"room_id": room_id,
		"room_kind": room_kind,
		"member_id": member_id,
	})
	app_runtime.front_settings_state.reconnect_room_id = room_id
	app_runtime.front_settings_state.reconnect_room_kind = room_kind
	app_runtime.front_settings_state.reconnect_room_display_name = room_display_name
	app_runtime.front_settings_state.reconnect_member_id = member_id
	app_runtime.front_settings_state.reconnect_token = reconnect_token
	app_runtime.front_settings_state.reconnect_state = "room_only"
	if app_runtime.current_room_entry_context != null:
		app_runtime.front_settings_state.reconnect_host = app_runtime.current_room_entry_context.server_host
		app_runtime.front_settings_state.reconnect_port = app_runtime.current_room_entry_context.server_port
		app_runtime.front_settings_state.reconnect_topology = app_runtime.current_room_entry_context.topology
	_save_front_settings(app_runtime)


static func apply_match_resume_accepted(app_runtime: Object, config: BattleStartConfig, snapshot: MatchResumeSnapshot, log_sink: Object = null) -> void:
	if app_runtime == null:
		return
	_log(log_sink, "match_resume_accepted", {
		"match_id": config.match_id if config != null else "",
		"controlled_peer_id": snapshot.controlled_peer_id if snapshot != null else 0,
	})
	if app_runtime.has_method("apply_match_resume_payload"):
		app_runtime.apply_match_resume_payload(config, snapshot)
	if app_runtime.front_settings_state != null:
		app_runtime.front_settings_state.reconnect_state = "active_match"
		_save_front_settings(app_runtime)


static func should_clear_pending_reconnect_ticket(pending_entry_context: RoomEntryContext, error_code: String) -> bool:
	if pending_entry_context == null or not pending_entry_context.use_resume_flow:
		return false
	return RESUME_TICKET_CLEAR_ERROR_CODES.has(error_code)


static func clear_reconnect_ticket_after_rejected_resume(app_runtime: Object, error_code: String, log_sink: Object = null) -> void:
	if app_runtime == null or app_runtime.front_settings_state == null:
		return
	if not app_runtime.front_settings_state.has_method("clear_reconnect_ticket"):
		return
	_log(log_sink, "clear_reconnect_ticket_after_rejected_resume", {
		"error_code": error_code,
		"room_id": String(app_runtime.front_settings_state.reconnect_room_id),
		"member_id": String(app_runtime.front_settings_state.reconnect_member_id),
		"match_id": String(app_runtime.front_settings_state.reconnect_match_id),
	})
	app_runtime.front_settings_state.clear_reconnect_ticket()
	_save_front_settings(app_runtime)


static func _save_front_settings(app_runtime: Object) -> void:
	if app_runtime == null or not ("front_settings_repository" in app_runtime) or not ("front_settings_state" in app_runtime):
		return
	if app_runtime.front_settings_repository == null or app_runtime.front_settings_state == null:
		return
	if app_runtime.front_settings_repository.has_method("save_settings"):
		app_runtime.front_settings_repository.save_settings(app_runtime.front_settings_state)


static func _log(log_sink: Object, event_name: String, payload: Dictionary) -> void:
	if log_sink != null and log_sink.has_method("_log_room"):
		log_sink._log_room(event_name, payload)
