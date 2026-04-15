extends Node

## Phase23: Battle-only Dedicated Server bootstrap.
## Reads battle manifest, creates ServerBattleRuntime, handles battle lifecycle.
## Does NOT create ServerRoomRegistry or handle room create/join.

const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const ServerBattleRuntimeScript = preload("res://network/battle/runtime/server_battle_runtime.gd")
const LogSystemInitializerScript = preload("res://app/logging/log_system_initializer.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")

@export var listen_port: int = 9000
@export var max_clients: int = 8
@export var authority_host: String = "127.0.0.1"
@export var battle_ticket_secret: String = "dev_battle_ticket_secret"

var _transport: ENetBattleTransport = null
var _battle_runtime: Node = null

# Phase23: Battle manifest fields from command line
var _battle_id: String = ""
var _assignment_id: String = ""
var _match_id: String = ""


func _ready() -> void:
	LogSystemInitializerScript.initialize_dedicated_server()
	_apply_command_line_overrides()

	if _battle_id.is_empty() and _assignment_id.is_empty():
		LogNetScript.warn("battle_ds started without --qqt-battle-id / --qqt-assignment-id, waiting for allocation", "", 0, "net.battle_ds_bootstrap")

	_battle_runtime = ServerBattleRuntimeScript.new()
	_battle_runtime.name = "ServerBattleRuntime"
	add_child(_battle_runtime)
	_battle_runtime.configure(authority_host, listen_port)
	_battle_runtime.battle_id = _battle_id
	_battle_runtime.assignment_id = _assignment_id
	_battle_runtime.match_id = _match_id
	_connect_battle_runtime_signals()

	_transport = ENetBattleTransportScript.new()
	add_child(_transport)
	_transport.initialize({
		"is_server": true,
		"port": listen_port,
		"max_clients": max_clients,
	})
	_connect_transport_signals()
	LogNetScript.info("battle_ds started on %s:%d battle_id=%s assignment_id=%s" % [authority_host, listen_port, _battle_id, _assignment_id], "", 0, "net.battle_ds_bootstrap")

	# Phase23: Report ready to game_service (placeholder — will be wired in Step 5)
	_report_battle_ready()


func _apply_command_line_overrides() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		var key := String(args[index])
		if key == "--qqt-ds-port" and index + 1 < args.size():
			var parsed_port := int(String(args[index + 1]).to_int())
			if parsed_port > 0:
				listen_port = parsed_port
		elif key == "--qqt-ds-host" and index + 1 < args.size():
			var parsed_host := String(args[index + 1]).strip_edges()
			if not parsed_host.is_empty():
				authority_host = parsed_host
		elif key == "--qqt-battle-id" and index + 1 < args.size():
			_battle_id = String(args[index + 1]).strip_edges()
		elif key == "--qqt-assignment-id" and index + 1 < args.size():
			_assignment_id = String(args[index + 1]).strip_edges()
		elif key == "--qqt-match-id" and index + 1 < args.size():
			_match_id = String(args[index + 1]).strip_edges()
		elif key == "--qqt-battle-ticket-secret" and index + 1 < args.size():
			var parsed_secret := String(args[index + 1]).strip_edges()
			if not parsed_secret.is_empty():
				battle_ticket_secret = parsed_secret


func _process(_delta: float) -> void:
	if _transport == null:
		return
	_transport.poll()
	for message in _transport.consume_incoming():
		_route_message(message)


func _exit_tree() -> void:
	if _transport != null:
		_transport.shutdown()


func _connect_battle_runtime_signals() -> void:
	if _battle_runtime == null:
		return
	if not _battle_runtime.send_to_peer.is_connected(_send_to_peer):
		_battle_runtime.send_to_peer.connect(_send_to_peer)
	if not _battle_runtime.broadcast_message.is_connected(_broadcast_message):
		_battle_runtime.broadcast_message.connect(_broadcast_message)
	if _battle_runtime.has_signal("match_finished") and not _battle_runtime.match_finished.is_connected(_on_match_finished):
		_battle_runtime.match_finished.connect(_on_match_finished)


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
	if _battle_runtime == null:
		return
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.BATTLE_ENTRY_REQUEST:
			_handle_battle_entry_request(message)
		TransportMessageTypesScript.BATTLE_RESUME_REQUEST:
			_handle_battle_resume_request(message)
		TransportMessageTypesScript.INPUT_FRAME:
			_battle_runtime.handle_battle_message(message)
		TransportMessageTypesScript.MATCH_LOADING_READY:
			_battle_runtime.handle_loading_message(message)
		_:
			# Phase23 compat: accept legacy room-based join during transition
			if message_type == TransportMessageTypesScript.ROOM_CREATE_REQUEST \
				or message_type == TransportMessageTypesScript.ROOM_JOIN_REQUEST:
				LogNetScript.warn("battle_ds received legacy room message: %s (rejected)" % message_type, "", 0, "net.battle_ds_bootstrap")
				var peer_id := int(message.get("sender_peer_id", 0))
				if peer_id > 0:
					_send_to_peer(peer_id, {
						"message_type": TransportMessageTypesScript.ROOM_CREATE_REJECTED if message_type == TransportMessageTypesScript.ROOM_CREATE_REQUEST else TransportMessageTypesScript.ROOM_JOIN_REJECTED,
						"error": "BATTLE_DS_ROOM_FORBIDDEN",
						"user_message": "This server is battle-only. Connect to room_service for room operations.",
					})


func _handle_battle_entry_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	# TODO Phase23: Validate battle-entry ticket here
	LogNetScript.info("battle_entry_request peer=%d battle_id=%s" % [peer_id, _battle_id], "", 0, "net.battle_ds_bootstrap")
	_send_to_peer(peer_id, {
		"message_type": TransportMessageTypesScript.BATTLE_ENTRY_ACCEPTED,
		"battle_id": _battle_id,
		"assignment_id": _assignment_id,
		"match_id": _match_id,
	})


func _handle_battle_resume_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	# TODO Phase23: Validate resume token and delegate to battle runtime
	LogNetScript.info("battle_resume_request peer=%d battle_id=%s" % [peer_id, _battle_id], "", 0, "net.battle_ds_bootstrap")
	_battle_runtime.handle_peer_disconnected(peer_id)


func _on_match_finished(_result) -> void:
	LogNetScript.info("battle finished battle_id=%s, shutting down" % _battle_id, "", 0, "net.battle_ds_bootstrap")
	# Phase23: In production, DS manager would reap this process.
	# For now, just log. The process stays alive for finalize reporting.


func _report_battle_ready() -> void:
	if _battle_id.is_empty():
		return
	# TODO Phase23 Step 5: HTTP call to game_service POST /internal/v1/battles/{battle_id}/ready
	LogNetScript.info("battle_ready reported (stub) battle_id=%s" % _battle_id, "", 0, "net.battle_ds_bootstrap")


func _send_to_peer(peer_id: int, message: Dictionary) -> void:
	if _transport == null:
		return
	_transport.send_to_peer(peer_id, message)


func _broadcast_message(message: Dictionary) -> void:
	if _transport == null:
		return
	_transport.broadcast(message)


func _on_transport_peer_connected(peer_id: int) -> void:
	LogNetScript.info("peer connected: %d" % peer_id, "", 0, "net.battle_ds_bootstrap")


func _on_transport_peer_disconnected(peer_id: int) -> void:
	LogNetScript.info("peer disconnected: %d" % peer_id, "", 0, "net.battle_ds_bootstrap")
	if _battle_runtime != null:
		_battle_runtime.handle_peer_disconnected(peer_id)


func _on_transport_error(code: int, message: String) -> void:
	LogNetScript.warn("transport error %d: %s" % [code, message], "", 0, "net.battle_ds_bootstrap")
