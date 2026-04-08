class_name ClientRoomRuntime
extends Node

const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")

signal transport_connected()
signal transport_disconnected()
signal room_snapshot_received(snapshot: RoomSnapshot)
signal room_joined(snapshot: RoomSnapshot)
signal room_error(error_code: String, user_message: String)
signal canonical_start_config_received(config: BattleStartConfig)
signal battle_message_received(message: Dictionary)

var _transport: ENetBattleTransport = null
var _last_snapshot: RoomSnapshot = null
var _connected: bool = false
var _connecting: bool = false
var _pending_leave_disconnect: bool = false
var _leave_disconnect_deadline_msec: int = 0


func _process(_delta: float) -> void:
	if _transport == null:
		return
	_transport.poll()
	for message in _transport.consume_incoming():
		_route_message(message)
	if _pending_leave_disconnect and Time.get_ticks_msec() >= _leave_disconnect_deadline_msec:
		_shutdown_transport()


func connect_to_server(host: String, port: int, timeout_sec: float = 5.0) -> void:
	var normalized_host := host.strip_edges() if not host.strip_edges().is_empty() else "127.0.0.1"
	var normalized_port := port if port > 0 else 9000
	_shutdown_transport()
	_connecting = true
	_transport = ENetBattleTransportScript.new()
	add_child(_transport)
	_connect_transport_signals()
	_transport.initialize({
		"is_server": false,
		"host": normalized_host,
		"port": normalized_port,
		"connect_timeout_seconds": timeout_sec,
	})


func disconnect_from_server() -> void:
	_pending_leave_disconnect = false
	_leave_disconnect_deadline_msec = 0
	_shutdown_transport()


func is_transport_connected() -> bool:
	return _connected and _transport != null and _transport.is_transport_connected()


func request_create_room(
	room_id_hint: String,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = "",
	map_id: String = "",
	rule_set_id: String = "",
	mode_id: String = ""
) -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"room_id_hint": room_id_hint,
		"player_name": player_name,
		"character_id": character_id,
		"character_skin_id": character_skin_id,
		"bubble_style_id": bubble_style_id,
		"bubble_skin_id": bubble_skin_id,
		"map_id": map_id,
		"rule_set_id": rule_set_id,
		"mode_id": mode_id,
	})


func request_join_room(
	room_id_hint: String,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = ""
) -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"room_id_hint": room_id_hint,
		"player_name": player_name,
		"character_id": character_id,
		"character_skin_id": character_skin_id,
		"bubble_style_id": bubble_style_id,
		"bubble_skin_id": bubble_skin_id,
	})


func request_update_profile(
	player_name: String,
	character_id: String,
	character_skin_id: String,
	bubble_style_id: String,
	bubble_skin_id: String
) -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_UPDATE_PROFILE,
		"player_name": player_name,
		"character_id": character_id,
		"character_skin_id": character_skin_id,
		"bubble_style_id": bubble_style_id,
		"bubble_skin_id": bubble_skin_id,
	})


func request_update_selection(map_id: String, rule_set_id: String, mode_id: String) -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_UPDATE_SELECTION,
		"map_id": map_id,
		"rule_set_id": rule_set_id,
		"mode_id": mode_id,
	})


func request_toggle_ready() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY,
	})


func request_start_match() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_START_REQUEST,
	})


func request_leave_room() -> void:
	_send_to_server({
		"message_type": TransportMessageTypesScript.ROOM_LEAVE,
	})


func request_leave_room_and_disconnect() -> void:
	request_leave_room()
	if _transport == null or not _transport.is_transport_connected():
		_shutdown_transport()
		return
	_pending_leave_disconnect = true
	_leave_disconnect_deadline_msec = Time.get_ticks_msec() + 1500


func send_battle_input(message: Dictionary) -> void:
	_send_to_server(message)


func _connect_transport_signals() -> void:
	if _transport == null:
		return
	if not _transport.connected.is_connected(_on_transport_connected):
		_transport.connected.connect(_on_transport_connected)
	if not _transport.disconnected.is_connected(_on_transport_disconnected):
		_transport.disconnected.connect(_on_transport_disconnected)
	if not _transport.transport_error.is_connected(_on_transport_error):
		_transport.transport_error.connect(_on_transport_error)


func _route_message(message: Dictionary) -> void:
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.ROOM_CREATE_ACCEPTED:
			if _last_snapshot != null:
				room_joined.emit(_last_snapshot)
		TransportMessageTypesScript.ROOM_CREATE_REJECTED:
			room_error.emit("ROOM_CREATE_FAILED", String(message.get("user_message", "Room create failed")))
		TransportMessageTypesScript.ROOM_JOIN_ACCEPTED:
			if _last_snapshot != null:
				room_joined.emit(_last_snapshot)
		TransportMessageTypesScript.ROOM_JOIN_REJECTED:
			room_error.emit("ROOM_JOIN_FAILED", String(message.get("user_message", "Room join failed")))
		TransportMessageTypesScript.ROOM_LEAVE_ACCEPTED:
			if _pending_leave_disconnect:
				_shutdown_transport()
		TransportMessageTypesScript.ROOM_SNAPSHOT:
			var snapshot := RoomSnapshot.from_dict(message.get("snapshot", {}))
			_last_snapshot = snapshot
			room_snapshot_received.emit(snapshot)
			room_joined.emit(snapshot)
		TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED:
			var config := BattleStartConfig.from_dict(message.get("start_config", {}))
			canonical_start_config_received.emit(config)
		TransportMessageTypesScript.JOIN_BATTLE_REJECTED:
			room_error.emit(String(message.get("error", "MATCH_START_REJECTED")), String(message.get("user_message", "Match start rejected")))
		TransportMessageTypesScript.INPUT_ACK, \
		TransportMessageTypesScript.STATE_SUMMARY, \
		TransportMessageTypesScript.CHECKPOINT, \
		TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT, \
		TransportMessageTypesScript.MATCH_FINISHED:
			battle_message_received.emit(message)
		_:
			pass


func _send_to_server(message: Dictionary) -> void:
	if _transport == null or not _transport.is_transport_connected():
		room_error.emit("ROOM_CONNECT_FAILED", "Not connected to dedicated server")
		return
	_transport.send_to_peer(1, message)


func _on_transport_connected() -> void:
	_connected = true
	_connecting = false
	_pending_leave_disconnect = false
	_leave_disconnect_deadline_msec = 0
	var app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if app_runtime != null and app_runtime.has_method("set_local_peer_id"):
		app_runtime.set_local_peer_id(_transport.get_local_peer_id())
	transport_connected.emit()


func _on_transport_disconnected() -> void:
	_connected = false
	_connecting = false
	_pending_leave_disconnect = false
	_leave_disconnect_deadline_msec = 0
	var app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if app_runtime != null and app_runtime.has_method("set_local_peer_id"):
		app_runtime.set_local_peer_id(1)
	transport_disconnected.emit()


func _on_transport_error(_code: int, message: String) -> void:
	_connecting = false
	room_error.emit("ROOM_CONNECT_FAILED", message)


func _shutdown_transport() -> void:
	_connected = false
	_connecting = false
	_pending_leave_disconnect = false
	_leave_disconnect_deadline_msec = 0
	_last_snapshot = null
	if _transport != null:
		_transport.shutdown()
		if _transport.get_parent() == self:
			remove_child(_transport)
		_transport.queue_free()
	_transport = null
