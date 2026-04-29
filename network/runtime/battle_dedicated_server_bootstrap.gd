extends Node

## Battle-only Dedicated Server bootstrap.
## Reads battle manifest, creates ServerBattleRuntime, handles battle lifecycle.
## Does NOT create ServerRoomRegistry or handle room create/join.

const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const ServerBattleRuntimeScript = preload("res://network/battle/runtime/server_battle_runtime.gd")
const GameServiceBattleManifestClientScript = preload("res://network/services/game_service_battle_manifest_client.gd")
const InternalAuthSignerScript = preload("res://network/services/internal_auth_signer.gd")
const InternalJsonServiceClientScript = preload("res://app/infra/http/internal_json_service_client.gd")
const InternalServiceAuthConfigScript = preload("res://app/infra/http/internal_service_auth_config.gd")
const BattleTicketVerifierScript = preload("res://network/services/battle_ticket_verifier.gd")
const LogSystemInitializerScript = preload("res://app/logging/log_system_initializer.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const ResumeTokenUtilsScript = preload("res://network/session/runtime/resume_token_utils.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RuntimeShutdownCoordinatorScript = preload("res://app/runtime/runtime_shutdown_coordinator.gd")

@export var listen_port: int = 9000
@export var max_clients: int = 8
@export var authority_host: String = "127.0.0.1"
@export var battle_ticket_secret: String = "dev_battle_ticket_secret"
@export var resume_window_sec: float = 20.0

var _transport: ENetBattleTransport = null
var _battle_runtime: Node = null
var _shutdown_coordinator: RefCounted = RuntimeShutdownCoordinatorScript.new()
var _shutdown_complete: bool = false

# Battle manifest fields from command line.
var _battle_id: String = ""
var _assignment_id: String = ""
var _match_id: String = ""
var _source_room_id: String = ""
var _source_room_kind: String = ""
var _season_id: String = ""

# Manifest + peer gate.
var _manifest_client: GameServiceBattleManifestClient = null
var _manifest: Dictionary = {}
var _joined_peer_ids: Array[int] = []
var _member_sessions_by_id: Dictionary = {}  # member_id -> session payload
var _member_id_by_peer_id: Dictionary = {}   # transport_peer_id -> member_id
var _used_battle_ticket_ids: Dictionary = {}
var _loading_started: bool = false
var _ds_manager_base_url: String = ""
var _ds_instance_active_reported: bool = false
var _ds_manager_auth_signer: InternalAuthSigner = null
var _ds_manager_http_client = null
var _battle_ticket_verifier: BattleTicketVerifier = null


func _ready() -> void:
	LogSystemInitializerScript.initialize_dedicated_server()
	_shutdown_coordinator.register_handle(self)
	_apply_command_line_overrides()
	battle_ticket_secret = _resolve_battle_ticket_secret()
	_ds_manager_base_url = _resolve_ds_manager_base_url()
	_ds_manager_auth_signer = _build_ds_manager_auth_signer()
	_ds_manager_http_client = _build_ds_manager_http_client(_ds_manager_base_url)
	_battle_ticket_verifier = BattleTicketVerifierScript.new()
	_battle_ticket_verifier.configure(battle_ticket_secret)

	if _battle_id.is_empty() and _assignment_id.is_empty():
		LogNetScript.warn("battle_ds started without --qqt-battle-id / --qqt-assignment-id, waiting for allocation", "", 0, "net.battle_ds_bootstrap")

	_battle_runtime = ServerBattleRuntimeScript.new()
	_battle_runtime.name = "ServerBattleRuntime"
	add_child(_battle_runtime)
	_battle_runtime.configure(authority_host, listen_port)
	_battle_runtime.battle_id = _battle_id
	_battle_runtime.assignment_id = _assignment_id
	_battle_runtime.match_id = _match_id
	_battle_runtime.room_kind = _source_room_kind
	_battle_runtime.season_id = _season_id
	_connect_battle_runtime_signals()
	if _battle_runtime.has_method("get_shutdown_name"):
		_shutdown_coordinator.register_handle(_battle_runtime)

	_transport = ENetBattleTransportScript.new()
	add_child(_transport)
	_transport.initialize({
		"is_server": true,
		"port": listen_port,
		"max_clients": max_clients,
	})
	_connect_transport_signals()
	_shutdown_coordinator.register_handle(_transport)
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
			LogNetScript.warn("--qqt-battle-ticket-secret is legacy/dev only; use QQT_BATTLE_TICKET_SECRET or QQT_BATTLE_TICKET_SECRET_FILE", "", 0, "net.battle_ds_bootstrap")
	if parsed.has("--qqt-resume-window-sec"):
		var parsed_resume_window := float(String(parsed["--qqt-resume-window-sec"]).to_float())
		if parsed_resume_window > 0.0:
			resume_window_sec = parsed_resume_window


func _process(_delta: float) -> void:
	if _transport == null:
		return
	_transport.poll()
	for message in _transport.consume_incoming():
		_route_message(message)


func _exit_tree() -> void:
	_shutdown_coordinator.shutdown_all("battle_ds_exit", false)


func get_shutdown_name() -> String:
	return "battle_dedicated_server_bootstrap"


func get_shutdown_priority() -> int:
	return 40


func shutdown(_context: Variant) -> void:
	if _shutdown_complete:
		return
	_disconnect_transport_signals()
	_disconnect_battle_runtime_signals()
	_shutdown_complete = true


func get_shutdown_metrics() -> Dictionary:
	return {
		"shutdown_failed": false,
		"shutdown_complete": _shutdown_complete,
		"has_transport": _transport != null,
		"has_battle_runtime": _battle_runtime != null,
	}


func _connect_battle_runtime_signals() -> void:
	if _battle_runtime == null:
		return
	if not _battle_runtime.send_to_peer.is_connected(_send_to_peer):
		_battle_runtime.send_to_peer.connect(_send_to_peer)
	if not _battle_runtime.broadcast_message.is_connected(_broadcast_message):
		_battle_runtime.broadcast_message.connect(_broadcast_message)
	if _battle_runtime.has_signal("match_finished") and not _battle_runtime.match_finished.is_connected(_on_match_finished):
		_battle_runtime.match_finished.connect(_on_match_finished)


func _disconnect_battle_runtime_signals() -> void:
	if _battle_runtime == null:
		return
	if _battle_runtime.send_to_peer.is_connected(_send_to_peer):
		_battle_runtime.send_to_peer.disconnect(_send_to_peer)
	if _battle_runtime.broadcast_message.is_connected(_broadcast_message):
		_battle_runtime.broadcast_message.disconnect(_broadcast_message)
	if _battle_runtime.has_signal("match_finished") and _battle_runtime.match_finished.is_connected(_on_match_finished):
		_battle_runtime.match_finished.disconnect(_on_match_finished)


func _connect_transport_signals() -> void:
	if _transport == null:
		return
	if not _transport.peer_connected.is_connected(_on_transport_peer_connected):
		_transport.peer_connected.connect(_on_transport_peer_connected)
	if not _transport.peer_disconnected.is_connected(_on_transport_peer_disconnected):
		_transport.peer_disconnected.connect(_on_transport_peer_disconnected)
	if not _transport.transport_error.is_connected(_on_transport_error):
		_transport.transport_error.connect(_on_transport_error)


func _disconnect_transport_signals() -> void:
	if _transport == null:
		return
	if _transport.peer_connected.is_connected(_on_transport_peer_connected):
		_transport.peer_connected.disconnect(_on_transport_peer_connected)
	if _transport.peer_disconnected.is_connected(_on_transport_peer_disconnected):
		_transport.peer_disconnected.disconnect(_on_transport_peer_disconnected)
	if _transport.transport_error.is_connected(_on_transport_error):
		_transport.transport_error.disconnect(_on_transport_error)


func _route_message(message: Dictionary) -> void:
	if _battle_runtime == null:
		return
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.BATTLE_ENTRY_REQUEST:
			_handle_battle_entry_request(message)
		TransportMessageTypesScript.BATTLE_RESUME_REQUEST:
			_handle_battle_resume_request(message)
		TransportMessageTypesScript.INPUT_BATCH:
			_battle_runtime.handle_battle_message(message)
		TransportMessageTypesScript.OPENING_SNAPSHOT_ACK, TransportMessageTypesScript.BATTLE_READY:
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
	var validation := _validate_battle_entry_request(message)
	if not bool(validation.get("ok", false)):
		_reject_peer(peer_id, TransportMessageTypesScript.BATTLE_ENTRY_REJECTED, String(validation.get("error_code", "BATTLE_ENTRY_REJECTED")), String(validation.get("user_message", "Battle entry rejected")))
		return
	var claim = validation.get("claim", null)
	var member_id := String(validation.get("member_id", ""))
	var manifest_member: Dictionary = validation.get("manifest_member", {})
	var ticket_id := String(claim.ticket_id) if claim != null else ""
	if _used_battle_ticket_ids.has(ticket_id):
		_reject_peer(peer_id, TransportMessageTypesScript.BATTLE_ENTRY_REJECTED, "BATTLE_TICKET_ALREADY_CONSUMED", "Battle ticket is already consumed")
		return
	var resume_token := ResumeTokenUtilsScript.generate_resume_token()
	var existing_session: Dictionary = _member_sessions_by_id.get(member_id, {})
	if not existing_session.is_empty() and String(existing_session.get("connection_state", "connected")) == "connected":
		_reject_peer(peer_id, TransportMessageTypesScript.BATTLE_ENTRY_REJECTED, "BATTLE_MEMBER_ALREADY_CONNECTED", "Battle member is already connected")
		return
	var match_peer_id := int(existing_session.get("match_peer_id", peer_id))
	if match_peer_id <= 0:
		match_peer_id = peer_id
	var slot_index := int(validation.get("slot_index", int(existing_session.get("slot_index", 0))))
	var session := {
		"member_id": member_id,
		"account_id": String(claim.account_id) if claim != null else "",
		"profile_id": String(claim.profile_id) if claim != null else "",
		"ticket_id": ticket_id,
		"device_session_id": String(claim.device_session_id) if claim != null else "",
		"match_peer_id": match_peer_id,
		"transport_peer_id": peer_id,
		"slot_index": slot_index,
		"assigned_team_id": int(manifest_member.get("assigned_team_id", 0)),
		"connection_state": "connected",
		"disconnect_deadline_msec": 0,
		"resume_token_hash": ResumeTokenUtilsScript.hash_resume_token(resume_token),
		"resume_issued_at_msec": Time.get_ticks_msec(),
	}
	_member_sessions_by_id[member_id] = session
	_member_id_by_peer_id[peer_id] = member_id
	_used_battle_ticket_ids[ticket_id] = true
	_refresh_joined_peer_ids_from_sessions()
	_battle_runtime.set_member_bindings(_build_runtime_member_bindings())
	LogNetScript.info("battle_entry_request accepted peer=%d member_id=%s battle_id=%s" % [peer_id, member_id, _battle_id], "", 0, "net.battle_ds_bootstrap")
	if not _joined_peer_ids.has(peer_id):
		_joined_peer_ids.append(peer_id)
	_send_to_peer(peer_id, {
		"message_type": TransportMessageTypesScript.BATTLE_ENTRY_ACCEPTED,
		"battle_id": _battle_id,
		"assignment_id": _assignment_id,
		"match_id": _match_id,
		"member_id": member_id,
		"resume_token": resume_token,
		"resume_window_sec": resume_window_sec,
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
	var validation := _validate_battle_resume_request(message)
	if not bool(validation.get("ok", false)):
		_reject_peer(peer_id, TransportMessageTypesScript.MATCH_RESUME_REJECTED, String(validation.get("error_code", "MATCH_RESUME_REJECTED")), String(validation.get("user_message", "Match resume rejected")))
		return
	var member_id := String(validation.get("member_id", ""))
	var requested_match_id := String(message.get("match_id", "")).strip_edges()
	var session: Dictionary = _member_sessions_by_id.get(member_id, {})
	var controlled_peer_id := int(session.get("match_peer_id", 0))
	if controlled_peer_id <= 0:
		_reject_peer(peer_id, TransportMessageTypesScript.MATCH_RESUME_REJECTED, "BATTLE_RESUME_MEMBER_INVALID", "Match resume member is invalid")
		return
	var previous_transport_peer_id := int(session.get("transport_peer_id", 0))
	if previous_transport_peer_id > 0 and _member_id_by_peer_id.get(previous_transport_peer_id, "") == member_id:
		_member_id_by_peer_id.erase(previous_transport_peer_id)
	session["transport_peer_id"] = peer_id
	session["connection_state"] = "connected"
	session["disconnect_deadline_msec"] = 0
	_member_sessions_by_id[member_id] = session
	_member_id_by_peer_id[peer_id] = member_id
	_refresh_joined_peer_ids_from_sessions()
	_battle_runtime.set_member_bindings(_build_runtime_member_bindings())
	var runtime_result: Dictionary = _battle_runtime.resume_member(member_id, peer_id, controlled_peer_id, requested_match_id)
	if not bool(runtime_result.get("ok", false)):
		session["connection_state"] = "disconnected"
		_member_sessions_by_id[member_id] = session
		_reject_peer(peer_id, TransportMessageTypesScript.MATCH_RESUME_REJECTED, String(runtime_result.get("error", "MATCH_RESUME_REJECTED")), "Match resume failed")
		return
	LogNetScript.info("battle_resume_request accepted peer=%d member_id=%s battle_id=%s" % [peer_id, member_id, _battle_id], "", 0, "net.battle_ds_bootstrap")


func _on_match_finished(_result) -> void:
	LogNetScript.info("battle finished battle_id=%s, shutting down" % _battle_id, "", 0, "net.battle_ds_bootstrap")


func _validate_battle_entry_request(message: Dictionary) -> Dictionary:
	if _battle_ticket_verifier == null:
		return _plain_json_fail("BATTLE_TICKET_VERIFIER_MISSING", "Battle ticket verifier is not configured")
	if _manifest.is_empty():
		return _plain_json_fail("BATTLE_MANIFEST_MISSING", "Battle manifest is missing")
	var verification := _battle_ticket_verifier.verify_entry_ticket(message, _battle_id, _manifest)
	if not bool(verification.get("ok", false)):
		return verification
	var claim = verification.get("claim", null)
	if claim == null:
		return _plain_json_fail("BATTLE_TICKET_INVALID", "Battle ticket claim is missing")
	var member_id := _member_identity_key(String(claim.account_id), String(claim.profile_id))
	var match := _find_manifest_member(String(claim.account_id), String(claim.profile_id))
	if match.is_empty():
		return _plain_json_fail("BATTLE_MEMBER_MISMATCH", "Battle member identity is invalid")
	var result := verification.duplicate(true)
	result["member_id"] = member_id
	result["manifest_member"] = match.get("member", {})
	result["slot_index"] = int(match.get("slot_index", 0))
	return result


func _validate_battle_resume_request(message: Dictionary) -> Dictionary:
	var requested_battle_id := String(message.get("battle_id", "")).strip_edges()
	if requested_battle_id.is_empty():
		requested_battle_id = _battle_id
	if requested_battle_id != _battle_id:
		return _plain_json_fail("BATTLE_ID_MISMATCH", "Battle id does not match")
	var member_id := String(message.get("member_id", "")).strip_edges()
	if member_id.is_empty():
		return _plain_json_fail("BATTLE_RESUME_MEMBER_ID_MISSING", "Resume member id is required")
	var resume_token := String(message.get("resume_token", "")).strip_edges()
	if resume_token.is_empty():
		return _plain_json_fail("BATTLE_RESUME_TOKEN_MISSING", "Resume token is required")
	var session: Dictionary = _member_sessions_by_id.get(member_id, {})
	if session.is_empty():
		return _plain_json_fail("BATTLE_RESUME_MEMBER_NOT_FOUND", "Resume member is invalid")
	var provided_account_id := String(message.get("account_id", "")).strip_edges()
	if not provided_account_id.is_empty() and provided_account_id != String(session.get("account_id", "")):
		return _plain_json_fail("BATTLE_RESUME_ACCOUNT_MISMATCH", "Resume account is invalid")
	var provided_profile_id := String(message.get("profile_id", "")).strip_edges()
	if not provided_profile_id.is_empty() and provided_profile_id != String(session.get("profile_id", "")):
		return _plain_json_fail("BATTLE_RESUME_PROFILE_MISMATCH", "Resume profile is invalid")
	if ResumeTokenUtilsScript.hash_resume_token(resume_token) != String(session.get("resume_token_hash", "")):
		return _plain_json_fail("BATTLE_RESUME_TOKEN_INVALID", "Resume token is invalid")
	var deadline_msec := int(session.get("disconnect_deadline_msec", 0))
	if deadline_msec <= 0:
		return _plain_json_fail("BATTLE_RESUME_WINDOW_INVALID", "Resume window is not active")
	if Time.get_ticks_msec() > deadline_msec:
		return _plain_json_fail("BATTLE_RESUME_WINDOW_EXPIRED", "Resume window has expired")
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"member_id": member_id,
	}


func _build_runtime_member_bindings() -> Dictionary:
	var bindings: Dictionary = {}
	for member_id in _member_sessions_by_id.keys():
		var member_key := String(member_id)
		var session: Dictionary = _member_sessions_by_id.get(member_key, {})
		if session.is_empty():
			continue
		bindings[member_key] = {
			"member_id": member_key,
			"account_id": String(session.get("account_id", "")),
			"profile_id": String(session.get("profile_id", "")),
			"match_peer_id": int(session.get("match_peer_id", 0)),
			"transport_peer_id": int(session.get("transport_peer_id", 0)),
			"connection_state": String(session.get("connection_state", "connected")),
			"disconnect_deadline_msec": int(session.get("disconnect_deadline_msec", 0)),
			"resume_token_hash": String(session.get("resume_token_hash", "")),
			"slot_index": int(session.get("slot_index", 0)),
			"assigned_team_id": int(session.get("assigned_team_id", 0)),
		}
	return bindings


func _refresh_joined_peer_ids_from_sessions() -> void:
	var peers: Array[int] = []
	for member_id in _member_sessions_by_id.keys():
		var session: Dictionary = _member_sessions_by_id.get(String(member_id), {})
		if String(session.get("connection_state", "")) != "connected":
			continue
		var peer_id := int(session.get("transport_peer_id", 0))
		if peer_id > 0 and not peers.has(peer_id):
			peers.append(peer_id)
	peers.sort()
	_joined_peer_ids = peers


func _find_manifest_member(account_id: String, profile_id: String) -> Dictionary:
	var members: Array = _manifest.get("members", [])
	for idx in range(members.size()):
		var member: Dictionary = members[idx] if members[idx] is Dictionary else {}
		if String(member.get("account_id", "")) == account_id and String(member.get("profile_id", "")) == profile_id:
			return {"member": member, "slot_index": idx}
	return {}


func _member_identity_key(account_id: String, profile_id: String) -> String:
	return "%s:%s" % [account_id.strip_edges(), profile_id.strip_edges()]


func _reject_peer(peer_id: int, message_type: String, error_code: String, user_message: String) -> void:
	if peer_id <= 0:
		return
	_send_to_peer(peer_id, {
		"message_type": message_type,
		"error": error_code,
		"user_message": user_message,
	})
	LogNetScript.warn("battle_request_rejected peer=%d type=%s code=%s" % [peer_id, message_type, error_code], "", 0, "net.battle_ds_bootstrap")


# --- Manifest fetch + begin_loading ---

func _fetch_manifest() -> void:
	if _battle_id.is_empty():
		LogNetScript.warn("battle_ds: no battle_id, skipping manifest fetch", "", 0, "net.battle_ds_bootstrap")
		return
	_manifest_client = GameServiceBattleManifestClientScript.new()
	var game_base_url := _normalize_http_base_url(_read_env("GAME_SERVICE_BASE_URL", ""))
	if game_base_url.is_empty():
		var game_host := _read_env("GAME_SERVICE_HOST", "127.0.0.1")
		var game_port := int(_read_env("GAME_SERVICE_PORT", "18081").to_int())
		if game_port <= 0:
			game_port = 18081
		game_base_url = "http://%s:%d" % [game_host, game_port]
	var secret_config: Dictionary = InternalServiceAuthConfigScript.resolve_shared_secret("GAME_INTERNAL_AUTH_SHARED_SECRET", "GAME_INTERNAL_SHARED_SECRET")
	var secret := String(secret_config.get("shared_secret", ""))
	var key_id := InternalServiceAuthConfigScript.resolve_key_id("GAME_INTERNAL_AUTH_KEY_ID", "primary")
	_manifest_client.configure(game_base_url, secret, key_id)
	var result := _manifest_client.fetch_manifest(_battle_id)
	if not bool(result.get("ok", false)):
		LogNetScript.warn("battle_manifest fetch failed: %s %s" % [String(result.get("error_code", "")), String(result.get("user_message", ""))], "", 0, "net.battle_ds_bootstrap")
		return
	_manifest = result
	_source_room_id = String(_manifest.get("source_room_id", "")).strip_edges()
	_source_room_kind = String(_manifest.get("source_room_kind", "")).strip_edges()
	_season_id = String(_manifest.get("season_id", "")).strip_edges()
	if _battle_runtime != null:
		_battle_runtime.room_kind = _source_room_kind
		_battle_runtime.season_id = _season_id
	_member_sessions_by_id.clear()
	_member_id_by_peer_id.clear()
	_used_battle_ticket_ids.clear()
	_joined_peer_ids.clear()
	_loading_started = false
	LogNetScript.info("battle_manifest fetched ok: expected_member_count=%d map_id=%s mode_id=%s" % [int(_manifest.get("expected_member_count", 0)), String(_manifest.get("map_id", "")), String(_manifest.get("mode_id", ""))], "", 0, "net.battle_ds_bootstrap")
	_report_battle_ready()


func _begin_battle_loading() -> void:
	if _manifest.is_empty():
		LogNetScript.warn("battle_ds: cannot begin loading, manifest is empty", "", 0, "net.battle_ds_bootstrap")
		return
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = _source_room_id if not _source_room_id.is_empty() else _battle_id
	snapshot.room_kind = _source_room_kind if not _source_room_kind.is_empty() else "dedicated_server"
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
	# Bind manifest members to validated member sessions.
	var manifest_members: Array = _manifest.get("members", [])
	var member_bindings: Dictionary = {}
	for idx in range(manifest_members.size()):
		var m: Dictionary = manifest_members[idx] if manifest_members[idx] is Dictionary else {}
		var member_id := _member_identity_key(String(m.get("account_id", "")), String(m.get("profile_id", "")))
		var session: Dictionary = _member_sessions_by_id.get(member_id, {})
		if session.is_empty():
			continue
		var transport_peer_id: int = int(session.get("transport_peer_id", 0))
		if transport_peer_id <= 0:
			continue
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
		member_bindings[member_id] = {
			"member_id": member_id,
			"account_id": String(m.get("account_id", "")),
			"profile_id": String(m.get("profile_id", "")),
			"match_peer_id": int(session.get("match_peer_id", transport_peer_id)),
			"transport_peer_id": transport_peer_id,
			"connection_state": "connected",
			"disconnect_deadline_msec": int(session.get("disconnect_deadline_msec", 0)),
			"resume_token_hash": String(session.get("resume_token_hash", "")),
			"slot_index": idx,
			"assigned_team_id": int(m.get("assigned_team_id", 0)),
		}
		_member_sessions_by_id[member_id]["slot_index"] = idx
	snapshot.owner_peer_id = _joined_peer_ids[0] if not _joined_peer_ids.is_empty() else 0
	# Inject member bindings for input validation / resume tracking
	_battle_runtime.set_member_bindings(member_bindings)
	LogNetScript.info("battle_ds begin_loading: members=%d map=%s mode=%s" % [snapshot.members.size(), snapshot.selected_map_id, snapshot.mode_id], "", 0, "net.battle_ds_bootstrap")
	var result: Dictionary = _battle_runtime.begin_loading(snapshot)
	if not bool(result.get("ok", false)):
		LogNetScript.warn("battle_ds begin_loading failed: %s" % String(result.get("user_message", "")), "", 0, "net.battle_ds_bootstrap")
		return
	_report_ds_instance_active()


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
	_report_ds_instance_ready()


func _report_ds_instance_ready() -> void:
	if _battle_id.is_empty() or _ds_manager_base_url.is_empty():
		return
	var path := "/internal/v1/battles/%s/ready" % _battle_id.uri_encode()
	var result := _send_plain_json_request(_ds_manager_base_url, path, {})
	if not bool(result.get("ok", false)):
		LogNetScript.warn("ds_manager ready report failed: %s %s" % [String(result.get("error_code", "")), String(result.get("user_message", ""))], "", 0, "net.battle_ds_bootstrap")
	else:
		LogNetScript.info("ds_manager ready reported ok battle_id=%s" % _battle_id, "", 0, "net.battle_ds_bootstrap")


func _report_ds_instance_active() -> void:
	if _ds_instance_active_reported or _battle_id.is_empty() or _ds_manager_base_url.is_empty():
		return
	var path := "/internal/v1/battles/%s/active" % _battle_id.uri_encode()
	var result := _send_plain_json_request(_ds_manager_base_url, path, {})
	if not bool(result.get("ok", false)):
		LogNetScript.warn("ds_manager active report failed: %s %s" % [String(result.get("error_code", "")), String(result.get("user_message", ""))], "", 0, "net.battle_ds_bootstrap")
		return
	_ds_instance_active_reported = true
	LogNetScript.info("ds_manager active reported ok battle_id=%s" % _battle_id, "", 0, "net.battle_ds_bootstrap")


func _send_plain_json_request(base_url: String, path: String, payload: Dictionary) -> Dictionary:
	if base_url.strip_edges().is_empty():
		return _plain_json_fail("PLAIN_JSON_URL_INVALID", "Target url is invalid")
	if _ds_manager_auth_signer == null or _ds_manager_http_client == null:
		return _plain_json_fail("PLAIN_JSON_AUTH_MISSING", "DSM internal auth signer is missing")
	var result: Dictionary = _ds_manager_http_client.post_json(path, payload)
	if bool(result.get("ok", false)):
		return result
	match String(result.get("error_code", "")):
		"INTERNAL_JSON_URL_INVALID", "INTERNAL_JSON_URL_MISSING":
			return _plain_json_fail("PLAIN_JSON_URL_INVALID", "Target url is invalid")
		"INTERNAL_JSON_CONNECT_FAILED":
			return _plain_json_fail("PLAIN_JSON_CONNECT_FAILED", "Failed to connect target service")
		"INTERNAL_JSON_REQUEST_FAILED":
			return _plain_json_fail("PLAIN_JSON_REQUEST_FAILED", "Failed to send request")
		"INTERNAL_JSON_EMPTY_RESPONSE":
			return _plain_json_fail("PLAIN_JSON_EMPTY_RESPONSE", "Target service returned empty response")
		"INTERNAL_JSON_RESPONSE_INVALID":
			return _plain_json_fail("PLAIN_JSON_RESPONSE_INVALID", "Target service returned invalid response")
		_:
			return result


func _plain_json_fail(error_code: String, user_message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "user_message": user_message}


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
	var member_id := String(_member_id_by_peer_id.get(peer_id, ""))
	if not member_id.is_empty():
		var session: Dictionary = _member_sessions_by_id.get(member_id, {})
		if not session.is_empty():
			session["connection_state"] = "disconnected"
			session["disconnect_deadline_msec"] = Time.get_ticks_msec() + int(resume_window_sec * 1000.0)
			session["transport_peer_id"] = 0
			_member_sessions_by_id[member_id] = session
		_member_id_by_peer_id.erase(peer_id)
		_refresh_joined_peer_ids_from_sessions()
		_battle_runtime.set_member_bindings(_build_runtime_member_bindings())
	if _battle_runtime != null:
		_battle_runtime.handle_peer_disconnected(peer_id)


func _on_transport_error(code: int, message: String) -> void:
	LogNetScript.warn("transport error %d: %s" % [code, message], "", 0, "net.battle_ds_bootstrap")


func _read_env(env_name: String, fallback: String) -> String:
	var value := OS.get_environment(env_name).strip_edges()
	return value if not value.is_empty() else fallback


func _resolve_battle_ticket_secret() -> String:
	var direct_secret := OS.get_environment("QQT_BATTLE_TICKET_SECRET").strip_edges()
	if not direct_secret.is_empty():
		return direct_secret
	var secret_file := OS.get_environment("QQT_BATTLE_TICKET_SECRET_FILE").strip_edges()
	if not secret_file.is_empty():
		var file_secret := _read_text_file(secret_file).strip_edges()
		if not file_secret.is_empty():
			return file_secret
	if battle_ticket_secret.strip_edges().is_empty():
		return "dev_battle_ticket_secret"
	return battle_ticket_secret


func _read_text_file(path: String) -> String:
	if path.strip_edges().is_empty():
		return ""
	if not FileAccess.file_exists(path):
		LogNetScript.warn("battle ticket secret file not found: %s" % path, "", 0, "net.battle_ds_bootstrap")
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		LogNetScript.warn("battle ticket secret file cannot be opened: %s" % path, "", 0, "net.battle_ds_bootstrap")
		return ""
	return file.get_as_text()


func _build_ds_manager_auth_signer() -> InternalAuthSigner:
	var auth := _resolve_ds_manager_auth()
	var shared_secret := String(auth.get("shared_secret", ""))
	if shared_secret.is_empty():
		LogNetScript.warn("dsm internal auth secret missing; ready/active control reports disabled", "", 0, "net.battle_ds_bootstrap")
		return null
	var key_id := String(auth.get("key_id", "primary"))
	var signer := InternalAuthSignerScript.new()
	signer.configure(key_id, shared_secret)
	return signer


func _build_ds_manager_http_client(base_url: String):
	if base_url.strip_edges().is_empty():
		return null
	var auth := _resolve_ds_manager_auth()
	var shared_secret := String(auth.get("shared_secret", ""))
	if shared_secret.is_empty():
		return null
	var key_id := String(auth.get("key_id", "primary"))
	var client := InternalJsonServiceClientScript.new()
	client.configure(base_url, key_id, shared_secret, "net.battle_ds_bootstrap")
	return client


func _resolve_ds_manager_auth() -> Dictionary:
	var shared_secret_config: Dictionary = InternalServiceAuthConfigScript.resolve_shared_secret("DSM_INTERNAL_AUTH_SHARED_SECRET", "DSM_INTERNAL_SHARED_SECRET")
	var shared_secret := String(shared_secret_config.get("shared_secret", ""))
	if shared_secret.is_empty():
		var game_auth_secret_config: Dictionary = InternalServiceAuthConfigScript.resolve_shared_secret("GAME_INTERNAL_AUTH_SHARED_SECRET", "GAME_INTERNAL_SHARED_SECRET")
		shared_secret = String(game_auth_secret_config.get("shared_secret", ""))
	var key_id := _read_env("DSM_INTERNAL_AUTH_KEY_ID", "")
	if key_id.is_empty():
		key_id = InternalServiceAuthConfigScript.resolve_key_id("GAME_INTERNAL_AUTH_KEY_ID", "primary")
	return {
		"shared_secret": shared_secret,
		"key_id": key_id,
	}


func _resolve_ds_manager_base_url() -> String:
	var candidates := [
		_read_env("DSM_BASE_URL", ""),
		_read_env("DS_MANAGER_URL", ""),
		_read_env("GAME_DS_MANAGER_URL", ""),
		_read_env("DSM_HTTP_ADDR", "127.0.0.1:18090"),
	]
	for raw in candidates:
		var normalized := _normalize_http_base_url(String(raw))
		if not normalized.is_empty():
			LogNetScript.info("ds_manager url resolved: %s" % normalized, "", 0, "net.battle_ds_bootstrap")
			return normalized
	LogNetScript.warn("ds_manager url missing; ready/active control reports disabled", "", 0, "net.battle_ds_bootstrap")
	return ""


func _normalize_http_base_url(raw_url: String) -> String:
	var value := raw_url.strip_edges().trim_suffix("/")
	if value.is_empty():
		return ""
	if value.begins_with(":"):
		value = "127.0.0.1" + value
	if not value.begins_with("http://"):
		value = "http://" + value
	var parsed := _parse_http_url(value)
	if parsed.is_empty():
		return ""
	return value


func _parse_http_url(url: String) -> Dictionary:
	var normalized := url.strip_edges()
	if not normalized.begins_with("http://"):
		return {}
	var without_scheme := normalized.substr(7)
	var slash_index := without_scheme.find("/")
	var host_port := without_scheme
	var path := "/"
	if slash_index >= 0:
		host_port = without_scheme.substr(0, slash_index)
		path = without_scheme.substr(slash_index, without_scheme.length() - slash_index)
	var colon_index := host_port.rfind(":")
	if colon_index <= 0 or colon_index >= host_port.length() - 1:
		return {}
	var port := int(host_port.substr(colon_index + 1, host_port.length() - colon_index - 1))
	if port <= 0:
		return {}
	return {
		"host": host_port.substr(0, colon_index),
		"port": port,
		"path": path,
	}
