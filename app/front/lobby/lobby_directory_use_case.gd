class_name LobbyDirectoryUseCase
extends RefCounted

const LOBBY_DIRECTORY_LOG_PREFIX := "[LOBBY_DIR]"
const RoomDefaultsScript = preload("res://app/front/room/room_defaults.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")

var client_room_runtime: Node = null
var front_settings_state: FrontSettingsState = null


func configure(p_client_room_runtime: Node, p_front_settings_state: FrontSettingsState) -> void:
	client_room_runtime = p_client_room_runtime
	front_settings_state = p_front_settings_state


func connect_directory(host: String, port: int) -> Dictionary:
	if client_room_runtime == null:
		_log_directory("directory_connect_failed", {
			"reason": "ROOM_RUNTIME_MISSING",
		})
		return _fail("ROOM_RUNTIME_MISSING", "Room runtime is not available")
	var normalized_host := _normalize_host(host)
	var normalized_port := _normalize_port(port)
	_store_last_server(normalized_host, normalized_port)
	_log_directory("directory_connect_requested", {
		"host": normalized_host,
		"port": normalized_port,
		"already_connected": client_room_runtime.has_method("is_connected_to") and client_room_runtime.is_connected_to(normalized_host, normalized_port),
	})
	var has_ready_transport: bool = client_room_runtime.has_method("is_connected_to") \
		and client_room_runtime.is_connected_to(normalized_host, normalized_port) \
		and client_room_runtime.has_method("is_transport_connected") \
		and client_room_runtime.is_transport_connected()
	if has_ready_transport:
		if client_room_runtime.has_method("subscribe_room_directory"):
			client_room_runtime.subscribe_room_directory()
		if client_room_runtime.has_method("request_room_directory_snapshot"):
			client_room_runtime.request_room_directory_snapshot()
		return _ok(true, "Refreshing room list...")
	if client_room_runtime.has_method("connect_to_server"):
		client_room_runtime.connect_to_server(normalized_host, normalized_port)
	return _ok(true, "Connecting...")


func refresh_directory(host: String, port: int) -> Dictionary:
	if client_room_runtime == null:
		_log_directory("directory_refresh_failed", {
			"reason": "ROOM_RUNTIME_MISSING",
		})
		return _fail("ROOM_RUNTIME_MISSING", "Room runtime is not available")
	var normalized_host := _normalize_host(host)
	var normalized_port := _normalize_port(port)
	_store_last_server(normalized_host, normalized_port)
	_log_directory("directory_refresh_requested", {
		"host": normalized_host,
		"port": normalized_port,
		"is_transport_connected": client_room_runtime.has_method("is_transport_connected") and client_room_runtime.is_transport_connected(),
	})
	if not (client_room_runtime.has_method("is_connected_to") and client_room_runtime.is_connected_to(normalized_host, normalized_port) and client_room_runtime.has_method("is_transport_connected") and client_room_runtime.is_transport_connected()):
		return connect_directory(normalized_host, normalized_port)
	if client_room_runtime.has_method("subscribe_room_directory"):
		client_room_runtime.subscribe_room_directory()
	if client_room_runtime.has_method("request_room_directory_snapshot"):
		client_room_runtime.request_room_directory_snapshot()
	return _ok(false, "Refreshing room list...")


func disconnect_directory() -> Dictionary:
	if client_room_runtime == null:
		_log_directory("directory_disconnect_failed", {
			"reason": "ROOM_RUNTIME_MISSING",
		})
		return _fail("ROOM_RUNTIME_MISSING", "Room runtime is not available")
	_log_directory("directory_disconnect_requested", {})
	if client_room_runtime.has_method("unsubscribe_room_directory"):
		client_room_runtime.unsubscribe_room_directory()
	return _ok(false, "")


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
	return RoomDefaultsScript.DEFAULT_PORT


func _store_last_server(host: String, port: int) -> void:
	if front_settings_state == null:
		return
	front_settings_state.last_server_host = host
	front_settings_state.last_server_port = port


func _ok(pending: bool, user_message: String) -> Dictionary:
	return {
		"ok": true,
		"pending": pending,
		"error_code": "",
		"user_message": user_message,
	}


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {
		"ok": false,
		"pending": false,
		"error_code": error_code,
		"user_message": user_message,
	}


func _log_directory(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[lobby_directory] %s %s" % [LOBBY_DIRECTORY_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.lobby.directory")
