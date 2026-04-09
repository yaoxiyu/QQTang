extends Node

const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const ServerRoomRegistryScript = preload("res://network/session/runtime/server_room_registry.gd")

@export var listen_port: int = 9000
@export var max_clients: int = 8
@export var authority_host: String = "127.0.0.1"

var _transport: ENetBattleTransport = null
var _room_registry: ServerRoomRegistry = null


func _ready() -> void:
	_room_registry = ServerRoomRegistryScript.new()
	_room_registry.name = "ServerRoomRegistry"
	_room_registry.authority_host = authority_host
	_room_registry.authority_port = listen_port
	add_child(_room_registry)
	_connect_registry()
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
	if _transport != null:
		_transport.shutdown()


func _connect_registry() -> void:
	if _room_registry == null:
		return
	if not _room_registry.broadcast_message.is_connected(_broadcast_message):
		_room_registry.broadcast_message.connect(_broadcast_message)
	if not _room_registry.send_to_peer.is_connected(_send_to_peer):
		_room_registry.send_to_peer.connect(_send_to_peer)


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
	if _room_registry == null:
		return
	_room_registry.route_message(message)


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
	if _room_registry != null:
		_room_registry.handle_peer_disconnected(peer_id)


func _on_transport_error(code: int, message: String) -> void:
	push_warning("[DedicatedServerBootstrap] transport error %d: %s | peers=%s" % [
		code,
		message,
		str(_transport.get_remote_peer_ids() if _transport != null else []),
	])
