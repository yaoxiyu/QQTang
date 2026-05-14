# LEGACY: 正式流程不再由客户端直接 enter queue。
# Retained for old tests and backend smoke only.
class_name MatchmakingUseCase
extends RefCounted

const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const MatchmakingQueueStateScript = preload("res://app/front/matchmaking/matchmaking_queue_state.gd")
const MatchmakingAssignmentStateScript = preload("res://app/front/matchmaking/matchmaking_assignment_state.gd")
const RoomTicketRequestScript = preload("res://app/front/auth/room_ticket_request.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const LoadoutNormalizerScript = preload("res://app/front/loadout/loadout_normalizer.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const LogSamplingPolicyScript = preload("res://app/logging/log_sampling_policy.gd")
const ServiceUrlBuilderScript = preload("res://app/infra/http/service_url_builder.gd")
const ONLINE_LOG_PREFIX := "[ONLINE]"
const MATCHMAKING_LOG_TAG := "front.matchmaking.use_case"

var auth_session_state: AuthSessionState = null
var player_profile_state: PlayerProfileState = null
var front_settings_state: FrontSettingsState = null
var matchmaking_gateway: RefCounted = null
var room_ticket_gateway: RefCounted = null

var _current_queue_state: MatchmakingQueueState = null
var _current_assignment_state: MatchmakingAssignmentState = null


func configure(
	p_auth_session_state: AuthSessionState,
	p_player_profile_state: PlayerProfileState,
	p_front_settings_state: FrontSettingsState,
	p_matchmaking_gateway: RefCounted,
	p_room_ticket_gateway: RefCounted
) -> void:
	auth_session_state = p_auth_session_state
	player_profile_state = p_player_profile_state
	front_settings_state = p_front_settings_state
	matchmaking_gateway = p_matchmaking_gateway
	room_ticket_gateway = p_room_ticket_gateway


func enter_queue(queue_type: String, match_format_id: String, mode_id: String, rule_set_id: String, selected_map_ids: Array[String]) -> Dictionary:
	if not _is_ready():
		return _fail("MATCHMAKING_USE_CASE_NOT_READY", "Matchmaking use case is not ready")
	_configure_gateways()
	_log_matchmaking("enter_queue_requested", {
		"queue_type": queue_type,
		"match_format_id": match_format_id,
		"mode_id": mode_id,
		"rule_set_id": rule_set_id,
		"selected_map_ids": selected_map_ids,
	})
	var response = await matchmaking_gateway.enter_queue(auth_session_state.access_token, queue_type, match_format_id, mode_id, rule_set_id, selected_map_ids)
	if not bool(response.get("ok", false)):
		_log_matchmaking("enter_queue_failed", response)
		return _fail(String(response.get("error_code", "MATCHMAKING_ENTER_FAILED")), String(response.get("user_message", "Failed to enter queue")))
	_current_queue_state = MatchmakingQueueStateScript.from_response(response, queue_type)
	if _current_queue_state != null:
		_current_queue_state.match_format_id = match_format_id
		_current_queue_state.mode_id = mode_id
		_current_queue_state.selected_map_ids = selected_map_ids.duplicate()
	_current_assignment_state = null
	if front_settings_state != null:
		front_settings_state.last_queue_type = queue_type
	_log_matchmaking("enter_queue_succeeded", {
		"queue_entry_id": _current_queue_state.queue_entry_id if _current_queue_state != null else "",
		"queue_state": _current_queue_state.queue_state if _current_queue_state != null else "",
	})
	return {"ok": true, "queue_state": _current_queue_state}


func cancel_queue() -> Dictionary:
	if not _is_ready():
		return _fail("MATCHMAKING_USE_CASE_NOT_READY", "Matchmaking use case is not ready")
	_configure_gateways()
	var queue_entry_id := _current_queue_state.queue_entry_id if _current_queue_state != null else ""
	_log_matchmaking("cancel_queue_requested", {
		"queue_entry_id": queue_entry_id,
	})
	var response = await matchmaking_gateway.cancel_queue(auth_session_state.access_token, queue_entry_id)
	if not bool(response.get("ok", false)):
		_log_matchmaking("cancel_queue_failed", response)
		return _fail(String(response.get("error_code", "MATCHMAKING_CANCEL_FAILED")), String(response.get("user_message", "Failed to cancel queue")))
	_current_queue_state = MatchmakingQueueStateScript.from_response(response)
	_current_assignment_state = null
	_log_matchmaking("cancel_queue_succeeded", {
		"queue_entry_id": _current_queue_state.queue_entry_id if _current_queue_state != null else queue_entry_id,
		"queue_state": _current_queue_state.queue_state if _current_queue_state != null else "",
	})
	return {"ok": true, "queue_state": _current_queue_state}


func poll_queue_status() -> Dictionary:
	if not _is_ready():
		return _fail("MATCHMAKING_USE_CASE_NOT_READY", "Matchmaking use case is not ready")
	_configure_gateways()
	var queue_entry_id := _current_queue_state.queue_entry_id if _current_queue_state != null else ""
	var response = await matchmaking_gateway.get_queue_status(auth_session_state.access_token, queue_entry_id)
	if not bool(response.get("ok", false)):
		_log_matchmaking("poll_queue_status_failed", response)
		return _fail(String(response.get("error_code", "MATCHMAKING_STATUS_FAILED")), String(response.get("user_message", "Failed to query queue status")))
	_current_queue_state = MatchmakingQueueStateScript.from_response(response, front_settings_state.last_queue_type if front_settings_state != null else "")
	_current_assignment_state = MatchmakingAssignmentStateScript.from_response(response) if _current_queue_state.queue_state == "assigned" else null
	_log_matchmaking("poll_queue_status_succeeded", {
		"queue_entry_id": _current_queue_state.queue_entry_id if _current_queue_state != null else queue_entry_id,
		"queue_state": _current_queue_state.queue_state if _current_queue_state != null else "",
		"assignment_id": _current_assignment_state.assignment_id if _current_assignment_state != null else "",
		"ticket_role": _current_assignment_state.ticket_role if _current_assignment_state != null else "",
	})
	return {
		"ok": true,
		"queue_state": _current_queue_state,
		"assignment_state": _current_assignment_state,
	}


func consume_assignment_and_build_room_entry_context() -> Dictionary:
	if not _is_ready():
		return _fail("MATCHMAKING_USE_CASE_NOT_READY", "Matchmaking use case is not ready")
	if _current_assignment_state == null or _current_assignment_state.assignment_id.is_empty():
		return _fail("MATCHMAKING_ASSIGNMENT_MISSING", "No assignment is ready")
	_configure_gateways()
	_log_matchmaking("consume_assignment_requested", {
		"assignment_id": _current_assignment_state.assignment_id,
		"ticket_role": _current_assignment_state.ticket_role,
		"room_id": _current_assignment_state.room_id,
	})
	var request = RoomTicketRequestScript.new()
	request.purpose = "create" if _current_assignment_state.ticket_role == "create" else "join"
	request.room_kind = _resolve_match_room_kind()
	request.room_id = _current_assignment_state.room_id
	request.assignment_id = _current_assignment_state.assignment_id
	var loadout_result = LoadoutNormalizerScript.apply_to_ticket_request(request, player_profile_state)
	if loadout_result != null and not loadout_result.changed_fields.is_empty():
		_log_matchmaking("ticket_loadout_normalized", {
			"assignment_id": _current_assignment_state.assignment_id,
			"changed_fields": loadout_result.changed_fields,
		})
	var ticket_result = await room_ticket_gateway.issue_room_ticket(auth_session_state.access_token, request)
	if ticket_result == null or not bool(ticket_result.ok):
		_log_matchmaking("consume_assignment_ticket_failed", {
			"assignment_id": _current_assignment_state.assignment_id,
			"error_code": String(ticket_result.error_code if ticket_result != null else "MATCH_ROOM_TICKET_FAILED"),
			"user_message": String(ticket_result.user_message if ticket_result != null else "Failed to issue room ticket"),
		})
		return _fail(
			String(ticket_result.error_code if ticket_result != null else "MATCH_ROOM_TICKET_FAILED"),
			String(ticket_result.user_message if ticket_result != null else "Failed to issue room ticket")
		)
	var entry_context := RoomEntryContextScript.new()
	entry_context.entry_kind = FrontEntryKindScript.ONLINE_CREATE if request.purpose == "create" else FrontEntryKindScript.ONLINE_JOIN
	entry_context.room_kind = _resolve_match_room_kind()
	entry_context.topology = FrontTopologyScript.DEDICATED_SERVER
	entry_context.server_host = _normalize_host(_current_assignment_state.server_host)
	entry_context.server_port = _normalize_port(_current_assignment_state.server_port, 9100)
	entry_context.target_room_id = ticket_result.room_id
	entry_context.room_display_name = "Match Room"
	entry_context.room_ticket = ticket_result.ticket
	entry_context.room_ticket_id = ticket_result.ticket_id
	entry_context.account_id = ticket_result.account_id
	entry_context.profile_id = ticket_result.profile_id
	entry_context.return_target = FrontReturnTargetScript.LOBBY
	entry_context.should_auto_connect = true
	entry_context.should_auto_join = true
	entry_context.assignment_id = ticket_result.assignment_id
	entry_context.match_source = ticket_result.match_source
	entry_context.locked_map_id = ticket_result.locked_map_id
	entry_context.locked_rule_set_id = ticket_result.locked_rule_set_id
	entry_context.locked_mode_id = ticket_result.locked_mode_id
	entry_context.assigned_team_id = ticket_result.assigned_team_id
	entry_context.auto_ready_on_join = ticket_result.auto_ready_on_join
	entry_context.return_to_lobby_after_settlement = true
	if front_settings_state != null:
		front_settings_state.last_server_host = entry_context.server_host
		front_settings_state.last_server_port = entry_context.server_port
		front_settings_state.last_room_id = entry_context.target_room_id
	_log_matchmaking("consume_assignment_succeeded", {
		"assignment_id": entry_context.assignment_id,
		"room_id": entry_context.target_room_id,
		"server_host": entry_context.server_host,
		"server_port": entry_context.server_port,
		"assigned_team_id": entry_context.assigned_team_id,
		"match_source": entry_context.match_source,
	})
	return {
		"ok": true,
		"entry_context": entry_context,
		"queue_state": _current_queue_state,
		"assignment_state": _current_assignment_state,
	}


func get_queue_state() -> MatchmakingQueueState:
	return _current_queue_state


func get_assignment_state() -> MatchmakingAssignmentState:
	return _current_assignment_state


func _resolve_match_room_kind() -> String:
	var queue_type := String(front_settings_state.last_queue_type if front_settings_state != null else "").strip_edges().to_lower()
	match queue_type:
		"ranked":
			return FrontRoomKindScript.RANKED_MATCH_ROOM
		_:
			return FrontRoomKindScript.CASUAL_MATCH_ROOM


func _configure_gateways() -> void:
	if front_settings_state == null:
		return
	if matchmaking_gateway != null and matchmaking_gateway.has_method("configure_base_url"):
		matchmaking_gateway.configure_base_url(ServiceUrlBuilderScript.build_game_base_url(_normalize_host(front_settings_state.game_service_host), _normalize_port(front_settings_state.game_service_port, 18081), 18081))
	if room_ticket_gateway != null and room_ticket_gateway.has_method("configure_base_url"):
		room_ticket_gateway.configure_base_url(ServiceUrlBuilderScript.build_account_base_url(_normalize_host(front_settings_state.account_service_host), _normalize_port(front_settings_state.account_service_port, 18080), 18080))


func _is_ready() -> bool:
	return auth_session_state != null \
		and not auth_session_state.access_token.strip_edges().is_empty() \
		and matchmaking_gateway != null \
		and room_ticket_gateway != null \
		and front_settings_state != null


func _normalize_host(host: String) -> String:
	var value := host.strip_edges()
	return value if not value.is_empty() else "127.0.0.1"


func _normalize_port(port: int, fallback: int) -> int:
	return port if port > 0 else fallback


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
	}


func _log_matchmaking(event_name: String, payload: Dictionary) -> void:
	if not LogSamplingPolicyScript.should_log("%s.%s" % [MATCHMAKING_LOG_TAG, event_name], _matchmaking_log_sample_every(event_name)):
		return
	var summary := _summarize_matchmaking_log_payload(event_name, payload)
	LogFrontScript.debug("%s[matchmaking_use_case] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(summary)], "", 0, MATCHMAKING_LOG_TAG)


func _matchmaking_log_sample_every(event_name: String) -> int:
	match event_name:
		"poll_queue_status_succeeded":
			return 10
		"poll_queue_status_failed":
			return 3
		_:
			return 1


func _summarize_matchmaking_log_payload(_event_name: String, payload: Dictionary) -> Dictionary:
	var summary := {}
	for key in [
		"queue_type",
		"match_format_id",
		"mode_id",
		"rule_set_id",
		"queue_entry_id",
		"queue_state",
		"assignment_id",
		"ticket_role",
		"room_id",
		"server_host",
		"server_port",
		"assigned_team_id",
		"match_source",
		"error_code",
		"user_message",
	]:
		if payload.has(key):
			summary[key] = payload[key]
	if payload.has("selected_map_ids"):
		var selected_map_ids = payload.get("selected_map_ids", [])
		summary["selected_map_count"] = selected_map_ids.size() if selected_map_ids is Array else 0
	if payload.has("changed_fields"):
		var changed_fields = payload.get("changed_fields", [])
		summary["changed_field_count"] = changed_fields.size() if changed_fields is Array else 0
		summary["changed_fields"] = changed_fields if changed_fields is Array and changed_fields.size() <= 4 else []
	return summary
