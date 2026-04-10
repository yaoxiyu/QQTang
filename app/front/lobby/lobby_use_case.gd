class_name LobbyUseCase
extends RefCounted

const PHASE15_LOG_PREFIX := "[QQT_P15]"

const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const LobbyViewStateScript = preload("res://app/front/lobby/lobby_view_state.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")

var auth_session_state: AuthSessionState = null
var player_profile_state: PlayerProfileState = null
var front_settings_state: FrontSettingsState = null
var practice_room_factory: PracticeRoomFactory = null


func configure(
	p_auth_session_state: AuthSessionState,
	p_player_profile_state: PlayerProfileState,
	p_front_settings_state: FrontSettingsState,
	p_practice_room_factory: PracticeRoomFactory
) -> void:
	auth_session_state = p_auth_session_state
	player_profile_state = p_player_profile_state
	front_settings_state = p_front_settings_state
	practice_room_factory = p_practice_room_factory


func enter_lobby() -> Dictionary:
	var view_state := LobbyViewStateScript.new()
	if player_profile_state != null:
		view_state.profile_name = player_profile_state.nickname
		view_state.default_character_id = player_profile_state.default_character_id
		view_state.default_character_skin_id = player_profile_state.default_character_skin_id
		view_state.default_bubble_style_id = player_profile_state.default_bubble_style_id
		view_state.default_bubble_skin_id = player_profile_state.default_bubble_skin_id
		view_state.preferred_map_id = player_profile_state.preferred_map_id
		view_state.preferred_rule_id = player_profile_state.preferred_rule_set_id
		view_state.preferred_mode_id = player_profile_state.preferred_mode_id
	if front_settings_state != null:
		view_state.last_server_host = front_settings_state.last_server_host
		view_state.last_server_port = front_settings_state.last_server_port
		view_state.last_room_id = front_settings_state.last_room_id
		view_state.reconnect_room_id = front_settings_state.reconnect_room_id
		view_state.reconnect_host = front_settings_state.reconnect_host
		view_state.reconnect_port = front_settings_state.reconnect_port
		view_state.reconnect_room_kind = front_settings_state.reconnect_room_kind
		view_state.reconnect_room_display_name = front_settings_state.reconnect_room_display_name
		view_state.reconnect_topology = front_settings_state.reconnect_topology
		view_state.reconnect_match_id = front_settings_state.reconnect_match_id
		# Phase17: Member session fields
		view_state.reconnect_member_id = front_settings_state.reconnect_member_id
		view_state.reconnect_token = front_settings_state.reconnect_token
		view_state.reconnect_state = front_settings_state.reconnect_state
		view_state.reconnect_resume_deadline_msec = front_settings_state.reconnect_resume_deadline_msec
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"view_state": view_state,
	}


func start_practice(map_id: String, rule_id: String, mode_id: String) -> Dictionary:
	if practice_room_factory == null:
		return _fail("PRACTICE_ROOM_FACTORY_MISSING", "Practice room factory is not configured")
	return practice_room_factory.create_practice_room(
		player_profile_state,
		map_id,
		rule_id,
		mode_id
	)


func create_private_room(host: String, port: int) -> Dictionary:
	var normalized_host := _normalize_host(host)
	var normalized_port := _normalize_port(port)
	_update_last_server(normalized_host, normalized_port)
	_log_phase15("create_private_room", {
		"host": normalized_host,
		"port": normalized_port,
	})
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"entry_context": _build_online_entry_context(
			FrontEntryKindScript.ONLINE_CREATE,
			FrontRoomKindScript.PRIVATE_ROOM,
			normalized_host,
			normalized_port,
			"",
			true,
			false
		),
	}


func join_private_room(host: String, port: int, room_id: String) -> Dictionary:
	var normalized_room_id := room_id.strip_edges()
	if normalized_room_id.is_empty():
		_log_phase15("join_private_room_failed", {
			"reason": "ROOM_ID_REQUIRED",
		})
		return _fail("ROOM_ID_REQUIRED", "Room id is required")
	var normalized_host := _normalize_host(host)
	var normalized_port := _normalize_port(port)
	_update_last_server(normalized_host, normalized_port)
	_log_phase15("join_private_room", {
		"host": normalized_host,
		"port": normalized_port,
		"room_id": normalized_room_id,
	})
	if front_settings_state != null:
		front_settings_state.last_room_id = normalized_room_id
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"entry_context": _build_online_entry_context(
			FrontEntryKindScript.ONLINE_JOIN,
			FrontRoomKindScript.PRIVATE_ROOM,
			normalized_host,
			normalized_port,
			normalized_room_id,
			true,
			true
		),
	}


func create_public_room(host: String, port: int, room_display_name: String) -> Dictionary:
	var normalized_room_display_name := room_display_name.strip_edges()
	if normalized_room_display_name.is_empty():
		_log_phase15("create_public_room_failed", {
			"reason": "ROOM_DISPLAY_NAME_REQUIRED",
		})
		return _fail("ROOM_DISPLAY_NAME_REQUIRED", "Public room name is required")
	var normalized_host := _normalize_host(host)
	var normalized_port := _normalize_port(port)
	_update_last_server(normalized_host, normalized_port)
	_log_phase15("create_public_room", {
		"host": normalized_host,
		"port": normalized_port,
		"room_display_name": normalized_room_display_name,
	})
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"entry_context": _build_online_entry_context(
			FrontEntryKindScript.ONLINE_CREATE,
			FrontRoomKindScript.PUBLIC_ROOM,
			normalized_host,
			normalized_port,
			"",
			true,
			false,
			normalized_room_display_name
		),
	}


func join_public_room(host: String, port: int, room_id: String) -> Dictionary:
	var normalized_room_id := room_id.strip_edges()
	if normalized_room_id.is_empty():
		_log_phase15("join_public_room_failed", {
			"reason": "ROOM_ID_REQUIRED",
		})
		return _fail("ROOM_ID_REQUIRED", "Room id is required")
	var normalized_host := _normalize_host(host)
	var normalized_port := _normalize_port(port)
	_update_last_server(normalized_host, normalized_port)
	_log_phase15("join_public_room", {
		"host": normalized_host,
		"port": normalized_port,
		"room_id": normalized_room_id,
	})
	if front_settings_state != null:
		front_settings_state.last_room_id = normalized_room_id
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"entry_context": _build_online_entry_context(
			FrontEntryKindScript.ONLINE_JOIN,
			FrontRoomKindScript.PUBLIC_ROOM,
			normalized_host,
			normalized_port,
			normalized_room_id,
			true,
			true
		),
	}


func logout() -> Dictionary:
	if auth_session_state != null:
		auth_session_state.clear()
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"entry_context": null,
	}


# Phase17: Resume recent room with member session
func resume_recent_room() -> Dictionary:
	if front_settings_state == null:
		return _fail("RECONNECT_STATE_MISSING", "Reconnect state is not available")
	if front_settings_state.reconnect_room_id.strip_edges().is_empty():
		return _fail("RECONNECT_ROOM_MISSING", "No reconnect room is available")
	if front_settings_state.reconnect_member_id.strip_edges().is_empty():
		return _fail("RECONNECT_MEMBER_MISSING", "Reconnect member session is missing")
	if front_settings_state.reconnect_token.strip_edges().is_empty():
		return _fail("RECONNECT_TOKEN_MISSING", "Reconnect token is missing")
	
	var entry_context := _build_online_entry_context(
		FrontEntryKindScript.ONLINE_JOIN,
		front_settings_state.reconnect_room_kind,
		front_settings_state.reconnect_host,
		front_settings_state.reconnect_port,
		front_settings_state.reconnect_room_id,
		true,
		false,
		front_settings_state.reconnect_room_display_name
	)
	# Phase17: Enable resume flow
	entry_context.use_resume_flow = true
	entry_context.reconnect_member_id = front_settings_state.reconnect_member_id
	entry_context.reconnect_token = front_settings_state.reconnect_token
	entry_context.reconnect_match_id = front_settings_state.reconnect_match_id
	
	_log_phase15("resume_recent_room", {
		"room_id": front_settings_state.reconnect_room_id,
		"room_kind": front_settings_state.reconnect_room_kind,
		"member_id": front_settings_state.reconnect_member_id,
		"match_id": front_settings_state.reconnect_match_id,
	})
	
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"entry_context": entry_context,
	}


func _build_online_entry_context(
	entry_kind: String,
	room_kind: String,
	host: String,
	port: int,
	room_id: String,
	should_auto_connect: bool,
	should_auto_join: bool,
	room_display_name: String = ""
) -> RoomEntryContext:
	var entry_context := RoomEntryContextScript.new()
	entry_context.entry_kind = entry_kind
	entry_context.room_kind = room_kind
	entry_context.topology = FrontTopologyScript.DEDICATED_SERVER
	entry_context.server_host = host
	entry_context.server_port = port
	entry_context.target_room_id = room_id
	entry_context.room_display_name = room_display_name
	entry_context.return_target = FrontReturnTargetScript.LOBBY
	entry_context.should_auto_connect = should_auto_connect
	entry_context.should_auto_join = should_auto_join
	return entry_context


func _normalize_host(host: String) -> String:
	var trimmed := host.strip_edges()
	if not trimmed.is_empty():
		return trimmed
	if front_settings_state != null and not front_settings_state.last_server_host.strip_edges().is_empty():
		return front_settings_state.last_server_host.strip_edges()
	return "127.0.0.1"


func _normalize_port(port: int) -> int:
	if port > 0:
		return port
	if front_settings_state != null and front_settings_state.last_server_port > 0:
		return front_settings_state.last_server_port
	return 9000


func _update_last_server(host: String, port: int) -> void:
	if front_settings_state == null:
		return
	front_settings_state.last_server_host = host
	front_settings_state.last_server_port = port


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
		"entry_context": null,
	}


func _log_phase15(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[lobby_use_case] %s %s" % [PHASE15_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.lobby.use_case")
