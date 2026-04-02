extends Node

const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const ServerMatchServiceScript = preload("res://network/session/runtime/server_match_service.gd")

@export var listen_port: int = 9000
@export var max_clients: int = 8
@export var authority_host: String = "127.0.0.1"

var _transport: ENetBattleTransport = null
var _room_service: ServerRoomService = null
var _match_service: ServerMatchService = null


func _ready() -> void:
	_room_service = ServerRoomServiceScript.new()
	add_child(_room_service)
	_match_service = ServerMatchServiceScript.new()
	_match_service.authority_host = authority_host
	_match_service.authority_port = listen_port
	add_child(_match_service)
	_connect_services()
	_transport = ENetBattleTransportScript.new()
	add_child(_transport)
	_transport.initialize({
		"is_server": true,
		"port": listen_port,
		"max_clients": max_clients,
	})
	_connect_transport_signals()
	print("[DedicatedServerBootstrap] started on %s:%d" % [authority_host, listen_port])


func _process(_delta: float) -> void:
	if _transport == null:
		return
	_transport.poll()
	for message in _transport.consume_incoming():
		_route_message(message)


func _exit_tree() -> void:
	if _match_service != null:
		_match_service.shutdown_match()
	if _transport != null:
		_transport.shutdown()


func _connect_services() -> void:
	if not _room_service.broadcast_message.is_connected(_broadcast_message):
		_room_service.broadcast_message.connect(_broadcast_message)
	if not _room_service.send_to_peer.is_connected(_send_to_peer):
		_room_service.send_to_peer.connect(_send_to_peer)
	if not _room_service.start_match_requested.is_connected(_on_start_match_requested):
		_room_service.start_match_requested.connect(_on_start_match_requested)
	if not _match_service.broadcast_message.is_connected(_broadcast_message):
		_match_service.broadcast_message.connect(_broadcast_message)
	if not _match_service.send_to_peer.is_connected(_send_to_peer):
		_match_service.send_to_peer.connect(_send_to_peer)
	if not _match_service.match_finished.is_connected(_on_match_finished):
		_match_service.match_finished.connect(_on_match_finished)


func _connect_transport_signals() -> void:
	if _transport == null:
		return
	if not _transport.peer_connected.is_connected(_on_transport_peer_connected):
		_transport.peer_connected.connect(_on_transport_peer_connected)
	if not _transport.peer_disconnected.is_connected(_on_transport_peer_disconnected):
		_transport.peer_disconnected.connect(_on_transport_peer_disconnected)
	if not _transport.transport_error.is_connected(_on_transport_error):
		_transport.transport_error.connect(_on_transport_error)


func _route_message(message: Dictionary) -> void:
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.INPUT_FRAME:
			_match_service.ingest_runtime_message(message)
		TransportMessageTypesScript.ROOM_JOIN_REQUEST, \
		TransportMessageTypesScript.ROOM_UPDATE_PROFILE, \
		TransportMessageTypesScript.ROOM_UPDATE_SELECTION, \
		TransportMessageTypesScript.ROOM_TOGGLE_READY, \
		TransportMessageTypesScript.ROOM_START_REQUEST, \
		TransportMessageTypesScript.ROOM_LEAVE:
			_room_service.handle_message(message)
		_:
			pass


func _on_start_match_requested(snapshot: RoomSnapshot) -> void:
	var result: Dictionary = _match_service.start_match(snapshot)
	if not bool(result.get("ok", false)):
		_broadcast_message({
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"user_message": String(result.get("validation", {}).get("error_message", "Server failed to start match")),
		})


func _send_to_peer(peer_id: int, message: Dictionary) -> void:
	if _transport == null:
		return
	_transport.send_to_peer(peer_id, message)


func _broadcast_message(message: Dictionary) -> void:
	if _transport == null:
		return
	_transport.broadcast(message)


func _on_transport_peer_connected(peer_id: int) -> void:
	print("[DedicatedServerBootstrap] peer connected: %d" % peer_id)


func _on_transport_peer_disconnected(peer_id: int) -> void:
	print("[DedicatedServerBootstrap] peer disconnected: %d" % peer_id)
	if _match_service != null and _match_service.has_method("is_match_active") and _match_service.is_match_active():
		_match_service.abort_match_due_to_disconnect(peer_id)
	_room_service.handle_peer_disconnected(peer_id)


func _on_transport_error(code: int, message: String) -> void:
	push_warning("[DedicatedServerBootstrap] transport error %d: %s" % [code, message])


func _on_match_finished(_result: BattleResult) -> void:
	if _room_service != null and _room_service.has_method("handle_match_finished"):
		_room_service.handle_match_finished()
