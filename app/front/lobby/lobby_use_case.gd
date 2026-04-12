class_name LobbyUseCase
extends RefCounted

const PHASE15_LOG_PREFIX := "[QQT_P15]"

const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontReturnTargetScript = preload("res://app/front/navigation/front_return_target.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const LobbyViewStateScript = preload("res://app/front/lobby/lobby_view_state.gd")
const RoomTicketRequestScript = preload("res://app/front/auth/room_ticket_request.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")

var auth_session_state: AuthSessionState = null
var player_profile_state: PlayerProfileState = null
var front_settings_state: FrontSettingsState = null
var practice_room_factory: PracticeRoomFactory = null
var auth_session_repository: RefCounted = null
var logout_use_case: RefCounted = null
var profile_gateway: RefCounted = null
var room_ticket_gateway: RefCounted = null
var app_runtime: Node = null


func configure(
	p_app_runtime: Node,
	p_auth_session_state: AuthSessionState,
	p_player_profile_state: PlayerProfileState,
	p_front_settings_state: FrontSettingsState,
	p_practice_room_factory: PracticeRoomFactory,
	p_auth_session_repository: RefCounted = null,
	p_logout_use_case: RefCounted = null,
	p_profile_gateway: RefCounted = null,
	p_room_ticket_gateway: RefCounted = null
) -> void:
	app_runtime = p_app_runtime
	auth_session_state = p_auth_session_state
	player_profile_state = p_player_profile_state
	front_settings_state = p_front_settings_state
	practice_room_factory = p_practice_room_factory
	auth_session_repository = p_auth_session_repository
	logout_use_case = p_logout_use_case
	profile_gateway = p_profile_gateway
	room_ticket_gateway = p_room_ticket_gateway


func enter_lobby() -> Dictionary:
	var view_state := LobbyViewStateScript.new()
	if auth_session_state != null:
		view_state.account_id = auth_session_state.account_id
		view_state.profile_id = auth_session_state.profile_id
		view_state.auth_mode = auth_session_state.auth_mode
		view_state.session_state = auth_session_state.session_state
	if player_profile_state != null:
		view_state.account_id = player_profile_state.account_id if not player_profile_state.account_id.is_empty() else view_state.account_id
		view_state.profile_source = String(player_profile_state.get("profile_source")) if _has_object_property(player_profile_state, "profile_source") else ""
		view_state.last_sync_msec = int(player_profile_state.get("last_sync_msec")) if _has_object_property(player_profile_state, "last_sync_msec") else 0
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
	var entry_context := _build_online_entry_context(
		FrontEntryKindScript.ONLINE_CREATE,
		FrontRoomKindScript.PRIVATE_ROOM,
		normalized_host,
		normalized_port,
		"",
		true,
		false
	)
	return _attach_room_ticket(entry_context, "create")


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
	var entry_context := _build_online_entry_context(
		FrontEntryKindScript.ONLINE_JOIN,
		FrontRoomKindScript.PRIVATE_ROOM,
		normalized_host,
		normalized_port,
		normalized_room_id,
		true,
		true
	)
	return _attach_room_ticket(entry_context, "join")


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
	var entry_context := _build_online_entry_context(
		FrontEntryKindScript.ONLINE_CREATE,
		FrontRoomKindScript.PUBLIC_ROOM,
		normalized_host,
		normalized_port,
		"",
		true,
		false,
		normalized_room_display_name
	)
	return _attach_room_ticket(entry_context, "create")


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
	var entry_context := _build_online_entry_context(
		FrontEntryKindScript.ONLINE_JOIN,
		FrontRoomKindScript.PUBLIC_ROOM,
		normalized_host,
		normalized_port,
		normalized_room_id,
		true,
		true
	)
	return _attach_room_ticket(entry_context, "join")


func logout() -> Dictionary:
	var logout_result := {
		"ok": true,
		"error_code": "",
		"user_message": "",
	}
	if logout_use_case != null and logout_use_case.has_method("logout"):
		logout_result = logout_use_case.logout()
	if auth_session_state != null:
		auth_session_state.clear()
	if auth_session_repository != null and auth_session_repository.has_method("clear_session"):
		auth_session_repository.clear_session()
	if front_settings_state != null:
		front_settings_state.clear_reconnect_ticket()
		if app_runtime != null and app_runtime.front_settings_repository != null and app_runtime.front_settings_repository.has_method("save_settings"):
			app_runtime.front_settings_repository.save_settings(front_settings_state)
	if app_runtime != null:
		app_runtime.current_room_entry_context = null
	return {
		"ok": bool(logout_result.get("ok", true)),
		"error_code": String(logout_result.get("error_code", "")),
		"user_message": String(logout_result.get("user_message", "")),
		"entry_context": null,
	}


func refresh_profile() -> Dictionary:
	if profile_gateway == null or not profile_gateway.has_method("fetch_my_profile"):
		return _fail("PROFILE_GATEWAY_MISSING", "Profile gateway is not available")
	if auth_session_state == null or auth_session_state.access_token.strip_edges().is_empty():
		return _fail("AUTH_SESSION_INVALID", "Access session is not available")
	var result = profile_gateway.fetch_my_profile(auth_session_state.access_token)
	if result == null:
		return _fail("PROFILE_FETCH_RESULT_MISSING", "Profile fetch result is missing")
	if not bool(result.get("ok", false)):
		return _fail(String(result.get("error_code", "PROFILE_FETCH_FAILED")), String(result.get("user_message", "Failed to fetch profile")))
	if player_profile_state != null:
		player_profile_state.profile_id = String(result.get("profile_id", player_profile_state.profile_id))
		player_profile_state.account_id = String(result.get("account_id", player_profile_state.account_id))
		player_profile_state.nickname = String(result.get("nickname", player_profile_state.nickname))
		player_profile_state.default_character_id = String(result.get("default_character_id", player_profile_state.default_character_id))
		player_profile_state.default_character_skin_id = String(result.get("default_character_skin_id", player_profile_state.default_character_skin_id))
		player_profile_state.default_bubble_style_id = String(result.get("default_bubble_style_id", player_profile_state.default_bubble_style_id))
		player_profile_state.default_bubble_skin_id = String(result.get("default_bubble_skin_id", player_profile_state.default_bubble_skin_id))
		player_profile_state.preferred_map_id = String(result.get("preferred_map_id", player_profile_state.preferred_map_id))
		player_profile_state.preferred_rule_set_id = String(result.get("preferred_rule_set_id", player_profile_state.preferred_rule_set_id))
		player_profile_state.preferred_mode_id = String(result.get("preferred_mode_id", player_profile_state.preferred_mode_id))
		if _has_object_property(player_profile_state, "owned_character_ids"):
			player_profile_state.owned_character_ids = PlayerProfileState._to_string_array(result.get("owned_character_ids", []))
		if _has_object_property(player_profile_state, "owned_character_skin_ids"):
			player_profile_state.owned_character_skin_ids = PlayerProfileState._to_string_array(result.get("owned_character_skin_ids", []))
		if _has_object_property(player_profile_state, "owned_bubble_style_ids"):
			player_profile_state.owned_bubble_style_ids = PlayerProfileState._to_string_array(result.get("owned_bubble_style_ids", []))
		if _has_object_property(player_profile_state, "owned_bubble_skin_ids"):
			player_profile_state.owned_bubble_skin_ids = PlayerProfileState._to_string_array(result.get("owned_bubble_skin_ids", []))
		if _has_object_property(player_profile_state, "profile_version"):
			player_profile_state.profile_version = int(result.get("profile_version", player_profile_state.profile_version))
		if _has_object_property(player_profile_state, "owned_asset_revision"):
			player_profile_state.owned_asset_revision = int(result.get("owned_asset_revision", player_profile_state.owned_asset_revision))
		if _has_object_property(player_profile_state, "profile_source"):
			player_profile_state.profile_source = "cloud_cache"
		if _has_object_property(player_profile_state, "last_sync_msec"):
			player_profile_state.last_sync_msec = Time.get_ticks_msec()
	if app_runtime != null and app_runtime.profile_repository != null and app_runtime.profile_repository.has_method("save_profile"):
		app_runtime.profile_repository.save_profile(player_profile_state)
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"view_state": enter_lobby().get("view_state", null),
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
	
	return _attach_room_ticket(entry_context, "resume")


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


func _attach_room_ticket(entry_context: RoomEntryContext, purpose: String) -> Dictionary:
	if entry_context == null:
		return _fail("ROOM_ENTRY_CONTEXT_MISSING", "Room entry context is missing")
	if room_ticket_gateway == null or not room_ticket_gateway.has_method("issue_room_ticket"):
		return _fail("ROOM_TICKET_GATEWAY_MISSING", "Room ticket gateway is not available")
	if auth_session_state == null or auth_session_state.access_token.strip_edges().is_empty():
		return _fail("AUTH_SESSION_INVALID", "Access session is not available")
	_configure_remote_gateways(entry_context.server_host, entry_context.server_port)
	var request := RoomTicketRequestScript.new()
	request.purpose = purpose
	request.room_id = entry_context.target_room_id
	request.room_kind = entry_context.room_kind
	request.requested_match_id = entry_context.reconnect_match_id if purpose == "resume" else ""
	if player_profile_state != null:
		request.selected_character_id = player_profile_state.default_character_id
		request.selected_character_skin_id = player_profile_state.default_character_skin_id
		request.selected_bubble_style_id = player_profile_state.default_bubble_style_id
		request.selected_bubble_skin_id = player_profile_state.default_bubble_skin_id
	var result = room_ticket_gateway.issue_room_ticket(auth_session_state.access_token, request)
	if result == null or not result.ok:
		return _fail(
			String(result.error_code if result != null else "ROOM_TICKET_RESULT_MISSING"),
			String(result.user_message if result != null else "Room ticket result is missing")
		)
	entry_context.room_ticket = result.ticket
	entry_context.room_ticket_id = result.ticket_id
	entry_context.account_id = result.account_id
	entry_context.profile_id = result.profile_id
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"entry_context": entry_context,
	}


func _configure_remote_gateways(host: String, port: int) -> void:
	var normalized_host := host.strip_edges() if not host.strip_edges().is_empty() else "127.0.0.1"
	var normalized_port := port if port > 0 else 8080
	var base_url := "http://%s:%d" % [normalized_host, normalized_port]
	if profile_gateway != null and profile_gateway.has_method("configure_base_url"):
		profile_gateway.configure_base_url(base_url)
	if room_ticket_gateway != null and room_ticket_gateway.has_method("configure_base_url"):
		room_ticket_gateway.configure_base_url(base_url)


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


func _has_object_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false
	for entry in target.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false
