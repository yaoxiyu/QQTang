extends Node

## Standalone Room Service process bootstrap.
## Manages room registry, room create/join/resume, snapshot broadcast.
## Does NOT create any battle runtime.

const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const ServerRoomRegistryScript = preload("res://network/session/legacy/server_room_registry.gd")
const LogSystemInitializerScript = preload("res://app/logging/log_system_initializer.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")

@export var listen_port: int = 9100
@export var max_clients: int = 32
@export var authority_host: String = "127.0.0.1"
@export var room_ticket_secret: String = "dev_room_ticket_secret"

var _transport: ENetBattleTransport = null
var _room_registry: ServerRoomRegistry = null


func _ready() -> void:
	LogSystemInitializerScript.initialize_dedicated_server()
	_apply_command_line_overrides()

	_room_registry = ServerRoomRegistryScript.new()
	_room_registry.name = "ServerRoomRegistry"
	_room_registry.authority_host = authority_host
	_room_registry.authority_port = listen_port
	_room_registry.room_ticket_secret = room_ticket_secret
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
	LogNetScript.info("room_service started on %s:%d" % [authority_host, listen_port], "", 0, "net.room_service_bootstrap")


func _apply_command_line_overrides() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		var key := String(args[index])
		if key == "--qqt-room-port" and index + 1 < args.size():
			var parsed_port := int(String(args[index + 1]).to_int())
			if parsed_port > 0:
				listen_port = parsed_port
		elif key == "--qqt-room-host" and index + 1 < args.size():
			var parsed_host := String(args[index + 1]).strip_edges()
			if not parsed_host.is_empty():
				authority_host = parsed_host
		elif key == "--qqt-room-ticket-secret" and index + 1 < args.size():
			var parsed_secret := String(args[index + 1]).strip_edges()
			if not parsed_secret.is_empty():
				room_ticket_secret = parsed_secret


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
	LogNetScript.info("peer connected: %d peers=%s" % [
		peer_id,
		str(_transport.get_remote_peer_ids() if _transport != null else []),
	], "", 0, "net.room_service_bootstrap")


func _on_transport_peer_disconnected(peer_id: int) -> void:
	LogNetScript.info("peer disconnected: %d peers=%s" % [
		peer_id,
		str(_transport.get_remote_peer_ids() if _transport != null else []),
	], "", 0, "net.room_service_bootstrap")
	if _room_registry != null:
		_room_registry.handle_peer_disconnected(peer_id)


func _on_transport_error(code: int, message: String) -> void:
	LogNetScript.warn("transport error %d: %s | peers=%s" % [
		code,
		message,
		str(_transport.get_remote_peer_ids() if _transport != null else []),
	], "", 0, "net.room_service_bootstrap")

