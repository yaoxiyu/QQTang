extends RefCounted

const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const ClientConnectionConfigScript = preload("res://network/runtime/client_connection_config.gd")
const LoadoutNormalizerScript = preload("res://app/front/loadout/loadout_normalizer.gd")
const RoomSelectionPolicyScript = preload("res://app/front/room/room_selection_policy.gd")

const PENDING_CONNECTION_WATCHDOG_GRACE_SEC := 1.0

var pending_online_entry_context: RoomEntryContext = null
var pending_connection_config: ClientConnectionConfig = null
var await_room_before_enter: bool = false
var _pending_connection_watchdog_token: int = 0


static func build_connection_config(app_runtime: Object, entry_context: RoomEntryContext) -> Dictionary:
	if entry_context == null:
		return {
			"config": null,
			"changed_fields": [],
		}
	var config := ClientConnectionConfigScript.new()
	config.server_host = entry_context.server_host
	config.server_port = entry_context.server_port
	config.room_id_hint = entry_context.target_room_id
	config.room_kind = entry_context.room_kind
	config.room_display_name = entry_context.room_display_name
	config.room_ticket = entry_context.room_ticket
	config.room_ticket_id = entry_context.room_ticket_id
	config.account_id = entry_context.account_id
	config.profile_id = entry_context.profile_id
	if app_runtime != null and app_runtime.auth_session_state != null:
		config.device_session_id = app_runtime.auth_session_state.device_session_id
	var changed_fields: Array = []
	if app_runtime != null and app_runtime.player_profile_state != null:
		config.player_name = app_runtime.player_profile_state.nickname
		var loadout_result = LoadoutNormalizerScript.apply_to_connection_config(config, app_runtime.player_profile_state)
		if loadout_result != null:
			changed_fields = loadout_result.changed_fields.duplicate()
	if FrontRoomKindScript.is_match_room(String(entry_context.room_kind)):
		config.selected_map_id = ""
		config.selected_rule_set_id = ""
		config.selected_mode_id = ""
	else:
		var default_selection := RoomSelectionPolicyScript.resolve_default_selection(entry_context, _get_preferred_map_id(app_runtime))
		config.selected_map_id = String(default_selection.get("map_id", ""))
		config.selected_rule_set_id = String(default_selection.get("rule_set_id", ""))
		config.selected_mode_id = String(default_selection.get("mode_id", _get_preferred_mode_id(app_runtime)))
	RoomSelectionPolicyScript.sanitize_connection_selection(config, not FrontRoomKindScript.is_match_room(String(entry_context.room_kind)))
	return {
		"config": config,
		"changed_fields": changed_fields,
	}


static func has_ready_transport_for(app_runtime: Object, connection_config: ClientConnectionConfig) -> bool:
	if connection_config == null or app_runtime == null or app_runtime.client_room_runtime == null:
		return false
	var client_room_runtime = app_runtime.client_room_runtime
	return client_room_runtime.has_method("is_connected_to") \
		and client_room_runtime.is_connected_to(String(connection_config.server_host), int(connection_config.server_port)) \
		and client_room_runtime.has_method("is_transport_connected") \
		and client_room_runtime.is_transport_connected()


func begin_pending_connection(entry_context: RoomEntryContext, connection_config: ClientConnectionConfig) -> void:
	pending_online_entry_context = entry_context.duplicate_deep() if entry_context != null else null
	pending_connection_config = connection_config.duplicate_deep() if connection_config != null else null
	await_room_before_enter = true


func clear_pending_connection() -> void:
	_pending_connection_watchdog_token += 1
	pending_online_entry_context = null
	pending_connection_config = null
	await_room_before_enter = false


func build_pending_connection_context() -> Dictionary:
	return {
		"await_room_before_enter": await_room_before_enter,
		"pending_entry_kind": String(pending_online_entry_context.entry_kind) if pending_online_entry_context != null else "",
		"pending_topology": String(pending_online_entry_context.topology) if pending_online_entry_context != null else "",
		"pending_server_host": String(pending_connection_config.server_host) if pending_connection_config != null else "",
		"pending_server_port": int(pending_connection_config.server_port) if pending_connection_config != null else 0,
		"pending_room_id_hint": String(pending_connection_config.room_id_hint) if pending_connection_config != null else "",
	}


func dispatch_transport_connected(gateway: Object, log_sink: Object = null) -> bool:
	if gateway == null or pending_online_entry_context == null or pending_connection_config == null:
		return false
	if pending_online_entry_context.use_resume_flow:
		_log(log_sink, "transport_connected_dispatch_resume", {
			"room_id": String(pending_online_entry_context.target_room_id),
			"member_id": String(pending_online_entry_context.reconnect_member_id),
			"match_id": String(pending_online_entry_context.reconnect_match_id),
		})
		gateway.request_resume_room(
			pending_connection_config,
			pending_online_entry_context.reconnect_member_id,
			pending_online_entry_context.reconnect_token,
			pending_online_entry_context.reconnect_match_id
		)
		return true
	match String(pending_online_entry_context.entry_kind):
		FrontEntryKindScript.ONLINE_CREATE:
			_log(log_sink, "transport_connected_dispatch_create", {
				"room_kind": String(pending_connection_config.room_kind),
				"room_display_name": String(pending_connection_config.room_display_name),
			})
			gateway.request_create_room(pending_connection_config)
			return true
		FrontEntryKindScript.ONLINE_JOIN:
			_log(log_sink, "transport_connected_dispatch_join", {
				"room_kind": String(pending_connection_config.room_kind),
				"room_id_hint": String(pending_connection_config.room_id_hint),
			})
			gateway.request_join_room(pending_connection_config)
			return true
	return false


func schedule_pending_connection_watchdog(app_runtime: Node, timeout_callback: Callable) -> void:
	_pending_connection_watchdog_token += 1
	var token := _pending_connection_watchdog_token
	if pending_connection_config == null or app_runtime == null or not is_instance_valid(app_runtime) or not app_runtime.is_inside_tree():
		return
	var timeout_sec: float = max(float(pending_connection_config.connect_timeout_sec), 0.5) + PENDING_CONNECTION_WATCHDOG_GRACE_SEC
	_await_pending_connection_watchdog(app_runtime, token, timeout_sec, timeout_callback)


static func _get_preferred_map_id(app_runtime: Object) -> String:
	if app_runtime != null and app_runtime.player_profile_state != null:
		return String(app_runtime.player_profile_state.preferred_map_id)
	return ""


func _await_pending_connection_watchdog(app_runtime: Node, token: int, timeout_sec: float, timeout_callback: Callable) -> void:
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
	if not await_room_before_enter or pending_online_entry_context == null or pending_connection_config == null:
		return
	if timeout_callback.is_valid():
		timeout_callback.call(timeout_sec)


func _log(log_sink: Object, event_name: String, payload: Dictionary) -> void:
	if log_sink != null and log_sink.has_method("_log_room"):
		log_sink._log_room(event_name, payload)


static func _get_preferred_mode_id(app_runtime: Object) -> String:
	if app_runtime != null and app_runtime.player_profile_state != null:
		return String(app_runtime.player_profile_state.preferred_mode_id)
	return ""
