extends Node

## Phase23: Battle-only Dedicated Server bootstrap.
## Reads battle manifest, creates ServerBattleRuntime, handles battle lifecycle.
## Does NOT create ServerRoomRegistry or handle room create/join.

const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const ServerBattleRuntimeScript = preload("res://network/battle/runtime/server_battle_runtime.gd")
const GameServiceBattleManifestClientScript = preload("res://network/services/game_service_battle_manifest_client.gd")
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

# Phase23: Manifest + peer gate
var _manifest_client: GameServiceBattleManifestClient = null
var _manifest: Dictionary = {}
var _joined_peer_ids: Array[int] = []
var _loading_started: bool = false


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

	_fetch_manifest()


func _apply_command_line_overrides() -> void:
	var args := OS.get_cmdline_user_args()
	# Support both "--key value" (two tokens) and "--key=value" (single token) formats.
	var parsed: Dictionary = {}
	for index in range(args.size()):
		var arg := String(args[index])
		if arg.begins_with("--qqt-") and arg.contains("="):
			var eq_pos := arg.find("=")
			parsed[arg.substr(0, eq_pos)] = arg.substr(eq_pos + 1)
		elif arg.begins_with("--qqt-") and index + 1 < args.size():
			parsed[arg] = String(args[index + 1])
	if parsed.has("--qqt-ds-port"):
		var parsed_port := int(String(parsed["--qqt-ds-port"]).to_int())
		if parsed_port > 0:
			listen_port = parsed_port
	if parsed.has("--qqt-ds-host"):
		var parsed_host := String(parsed["--qqt-ds-host"]).strip_edges()
		if not parsed_host.is_empty():
			authority_host = parsed_host
	if parsed.has("--qqt-battle-id"):
		_battle_id = String(parsed["--qqt-battle-id"]).strip_edges()
	if parsed.has("--qqt-assignment-id"):
		_assignment_id = String(parsed["--qqt-assignment-id"]).strip_edges()
	if parsed.has("--qqt-match-id"):
		_match_id = String(parsed["--qqt-match-id"]).strip_edges()
	if parsed.has("--qqt-battle-ticket-secret"):
		var parsed_secret := String(parsed["--qqt-battle-ticket-secret"]).strip_edges()
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
	if not _joined_peer_ids.has(peer_id):
		_joined_peer_ids.append(peer_id)
	_send_to_peer(peer_id, {
		"message_type": TransportMessageTypesScript.BATTLE_ENTRY_ACCEPTED,
		"battle_id": _battle_id,
		"assignment_id": _assignment_id,
		"match_id": _match_id,
	})
	# Gate: once all expected peers have joined, begin match loading
	var expected := int(_manifest.get("expected_member_count", 0))
	if expected > 0 and _joined_peer_ids.size() >= expected and not _loading_started:
		_loading_started = true
		_begin_battle_loading()


func _handle_battle_resume_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	# TODO Phase23: Validate resume token and delegate to battle runtime
	LogNetScript.info("battle_resume_request peer=%d battle_id=%s" % [peer_id, _battle_id], "", 0, "net.battle_ds_bootstrap")
	_battle_runtime.handle_peer_disconnected(peer_id)


func _on_match_finished(_result) -> void:
	LogNetScript.info("battle finished battle_id=%s, shutting down" % _battle_id, "", 0, "net.battle_ds_bootstrap")


# --- Manifest fetch + begin_loading ---

func _fetch_manifest() -> void:
	if _battle_id.is_empty():
		LogNetScript.warn("battle_ds: no battle_id, skipping manifest fetch", "", 0, "net.battle_ds_bootstrap")
		return
	_manifest_client = GameServiceBattleManifestClientScript.new()
	var game_host := _read_env("GAME_SERVICE_HOST", "127.0.0.1")
	var game_port := int(_read_env("GAME_SERVICE_PORT", "18081").to_int())
	if game_port <= 0:
		game_port = 18081
	var secret := _read_env("GAME_INTERNAL_SHARED_SECRET", "")
	var key_id := _read_env("GAME_INTERNAL_AUTH_KEY_ID", "primary")
	_manifest_client.configure("http://%s:%d" % [game_host, game_port], secret, key_id)
	var result := _manifest_client.fetch_manifest(_battle_id)
	if not bool(result.get("ok", false)):
		LogNetScript.warn("battle_manifest fetch failed: %s %s" % [String(result.get("error_code", "")), String(result.get("user_message", ""))], "", 0, "net.battle_ds_bootstrap")
		return
	_manifest = result
	LogNetScript.info("battle_manifest fetched ok: expected_member_count=%d map_id=%s mode_id=%s" % [int(_manifest.get("expected_member_count", 0)), String(_manifest.get("map_id", "")), String(_manifest.get("mode_id", ""))], "", 0, "net.battle_ds_bootstrap")
	_report_battle_ready()


func _begin_battle_loading() -> void:
	if _manifest.is_empty():
		LogNetScript.warn("battle_ds: cannot begin loading, manifest is empty", "", 0, "net.battle_ds_bootstrap")
		return
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = _battle_id
	snapshot.room_kind = "dedicated_server"
	snapshot.topology = "dedicated_server"
	snapshot.selected_map_id = String(_manifest.get("map_id", ""))
	snapshot.rule_set_id = String(_manifest.get("rule_set_id", ""))
	snapshot.mode_id = String(_manifest.get("mode_id", ""))
	snapshot.min_start_players = int(_manifest.get("expected_member_count", 2))
	snapshot.max_players = int(_manifest.get("expected_member_count", 8))
	snapshot.all_ready = true
	snapshot.match_active = false
	snapshot.current_assignment_id = _assignment_id
	snapshot.current_battle_id = _battle_id
	snapshot.current_match_id = _match_id
	# Bind manifest members to transport peer IDs
	var manifest_members: Array = _manifest.get("members", [])
	var member_bindings: Dictionary = {}
	for idx in range(mini(manifest_members.size(), _joined_peer_ids.size())):
		var m: Dictionary = manifest_members[idx] if manifest_members[idx] is Dictionary else {}
		var transport_peer_id: int = _joined_peer_ids[idx]
		var member := RoomMemberState.new()
		member.peer_id = transport_peer_id
		member.player_name = String(m.get("profile_id", "Player%d" % transport_peer_id))
		member.ready = true
		member.slot_index = idx
		member.team_id = int(m.get("assigned_team_id", (idx % 2) + 1))
		member.character_id = String(m.get("character_id", ""))
		member.is_owner = idx == 0
		member.connection_state = "connected"
		snapshot.members.append(member)
		member_bindings[String(m.get("account_id", "member_%d" % idx))] = {
			"match_peer_id": transport_peer_id,
			"transport_peer_id": transport_peer_id,
			"connection_state": "connected",
		}
	snapshot.owner_peer_id = _joined_peer_ids[0] if not _joined_peer_ids.is_empty() else 0
	# Inject member bindings for input validation / resume tracking
	_battle_runtime.set_member_bindings(member_bindings)
	LogNetScript.info("battle_ds begin_loading: members=%d map=%s mode=%s" % [snapshot.members.size(), snapshot.selected_map_id, snapshot.mode_id], "", 0, "net.battle_ds_bootstrap")
	var result: Dictionary = _battle_runtime.begin_loading(snapshot)
	if not bool(result.get("ok", false)):
		LogNetScript.warn("battle_ds begin_loading failed: %s" % String(result.get("user_message", "")), "", 0, "net.battle_ds_bootstrap")


func _report_battle_ready() -> void:
	if _battle_id.is_empty():
		return
	if _manifest_client == null:
		LogNetScript.info("battle_ready reported (stub, no client) battle_id=%s" % _battle_id, "", 0, "net.battle_ds_bootstrap")
		return
	var result := _manifest_client.post_ready(_battle_id, authority_host, listen_port)
	if not bool(result.get("ok", false)):
		LogNetScript.warn("battle_ready report failed: %s %s" % [String(result.get("error_code", "")), String(result.get("user_message", ""))], "", 0, "net.battle_ds_bootstrap")
	else:
		LogNetScript.info("battle_ready reported ok battle_id=%s" % _battle_id, "", 0, "net.battle_ds_bootstrap")


# --- Transport helpers ---

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


func _read_env(env_name: String, fallback: String) -> String:
	var value := OS.get_environment(env_name).strip_edges()
	return value if not value.is_empty() else fallback
