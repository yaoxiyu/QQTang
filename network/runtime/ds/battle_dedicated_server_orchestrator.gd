extends Node

## Battle-only Dedicated Server bootstrap.
## Reads battle manifest, creates ServerBattleRuntime, handles battle lifecycle.
## Does NOT create ServerRoomRegistry or handle room create/join.

const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const ServerBattleRuntimeScript = preload("res://network/battle/runtime/server_battle_runtime.gd")
const GameServiceBattleManifestClientScript = preload("res://network/services/game_service_battle_manifest_client.gd")
const DsLaunchConfigScript = preload("res://network/runtime/ds_launch_config.gd")
const DsLifecycleReporterScript = preload("res://network/runtime/ds_lifecycle_reporter.gd")
const DsDevAiBridgeScript = preload("res://network/runtime/ds_dev_ai_bridge.gd")
const InternalServiceAuthConfigScript = preload("res://app/infra/http/internal_service_auth_config.gd")
const ServiceUrlBuilderScript = preload("res://app/infra/http/service_url_builder.gd")
const BattleTicketVerifierScript = preload("res://network/services/battle_ticket_verifier.gd")
const LogSystemInitializerScript = preload("res://app/logging/log_system_initializer.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const ResumeTokenUtilsScript = preload("res://network/session/runtime/resume_token_utils.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RuntimeShutdownCoordinatorScript = preload("res://app/runtime/runtime_shutdown_coordinator.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
# AiInputDriverScript, PlayerInputFrameScript, TickRunnerScript moved to ds_dev_ai_bridge.gd.

@export var listen_port: int = 9000
@export var max_clients: int = 8
@export var authority_host: String = "127.0.0.1"
@export var battle_ticket_secret: String = "dev_battle_ticket_secret"
@export var resume_window_sec: float = 20.0

var _transport: ENetBattleTransport = null
var _battle_runtime: Node = null
var _shutdown_coordinator: RefCounted = RuntimeShutdownCoordinatorScript.new()
var _shutdown_complete: bool = false
var _launch_config: RefCounted = null
var _lifecycle_reporter: RefCounted = null

# Manifest + peer gate.
var _manifest_client: GameServiceBattleManifestClient = null
var _manifest: Dictionary = {}
var _joined_peer_ids: Array[int] = []
var _member_sessions_by_id: Dictionary = {}  # member_id -> session payload
var _member_id_by_peer_id: Dictionary = {}   # transport_peer_id -> member_id
var _used_battle_ticket_ids: Dictionary = {}
var _loading_started: bool = false
var _battle_ticket_verifier: BattleTicketVerifier = null

const _DEV_TOGGLE_AI_MESSAGE_TYPE := "DEV_TOGGLE_AI"
var _dev_ai_bridge: RefCounted = null


func configure_bootstrap(options: Dictionary) -> void:
	if options == null:
		return
	listen_port = int(options.get("listen_port", listen_port))
	max_clients = int(options.get("max_clients", max_clients))
	authority_host = String(options.get("authority_host", authority_host))
	battle_ticket_secret = String(options.get("battle_ticket_secret", battle_ticket_secret))
	resume_window_sec = float(options.get("resume_window_sec", resume_window_sec))


func _ready() -> void:
	LogSystemInitializerScript.initialize_dedicated_server()
	_shutdown_coordinator.register_handle(self)

	_launch_config = DsLaunchConfigScript.new()
	_launch_config.parse(OS.get_cmdline_user_args(), {
		"listen_port": listen_port,
		"authority_host": authority_host,
		"battle_ticket_secret": battle_ticket_secret,
		"resume_window_sec": resume_window_sec,
	})
	if _launch_config.has_method("has_config_errors") and _launch_config.has_config_errors():
		var errors: Array = _launch_config.get_config_errors()
		for entry in errors:
			LogNetScript.error("battle_ds launch config invalid: %s" % String(entry), "", 0, "net.battle_ds_bootstrap")
		push_error("battle_ds launch config invalid")
		get_tree().quit(2)
		return

	var ticket_secret: String = _launch_config.battle_ticket_secret
	_battle_ticket_verifier = BattleTicketVerifierScript.new()
	if _launch_config.dev_mode:
		_battle_ticket_verifier.configure(ticket_secret, true)
		LogNetScript.warn("DEV MODE ENABLED: ticket verification relaxed, manifest constructed, DSM reporting disabled. This must NOT run in production.", "", 0, "net.battle_ds_bootstrap")
	else:
		_battle_ticket_verifier.configure(ticket_secret)

	_lifecycle_reporter = DsLifecycleReporterScript.new()
	_lifecycle_reporter.configure(null, _launch_config.ds_manager_http_client, _launch_config.ds_manager_auth_signer, _launch_config.battle_id, _launch_config.authority_host, _launch_config.listen_port, _launch_config.ds_manager_base_url, _launch_config.dev_mode)

	_dev_ai_bridge = DsDevAiBridgeScript.new()

	var cfg_battle_id: String = _launch_config.battle_id
	var cfg_assignment_id: String = _launch_config.assignment_id
	if cfg_battle_id.is_empty() and cfg_assignment_id.is_empty() and not _launch_config.dev_mode:
		LogNetScript.warn("battle_ds started without --qqt-battle-id / --qqt-assignment-id, waiting for allocation", "", 0, "net.battle_ds_bootstrap")

	_battle_runtime = ServerBattleRuntimeScript.new()
	_battle_runtime.name = "ServerBattleRuntime"
	add_child(_battle_runtime)
	_battle_runtime.configure(_launch_config.authority_host, _launch_config.listen_port)
	_battle_runtime.battle_id = cfg_battle_id
	_battle_runtime.assignment_id = cfg_assignment_id
	_battle_runtime.match_id = _launch_config.match_id
	_battle_runtime.room_kind = _launch_config.source_room_kind
	_battle_runtime.season_id = _launch_config.season_id
	_connect_battle_runtime_signals()
	if _battle_runtime.has_method("get_shutdown_name"):
		_shutdown_coordinator.register_handle(_battle_runtime)

	_dev_ai_bridge.configure(_battle_runtime, null, _launch_config.match_id, TransportMessageTypesScript)

	_transport = ENetBattleTransportScript.new()
	add_child(_transport)
	_transport.initialize({
		"is_server": true,
		"port": _launch_config.listen_port,
		"max_clients": max_clients,
	})
	_connect_transport_signals()
	_shutdown_coordinator.register_handle(_transport)
	LogNetScript.info("battle_ds started on %s:%d battle_id=%s assignment_id=%s" % [_launch_config.authority_host, _launch_config.listen_port, cfg_battle_id, cfg_assignment_id], "", 0, "net.battle_ds_bootstrap")

	if _launch_config.dev_mode:
		_construct_dev_manifest()
	else:
		await _fetch_manifest()


func _process(delta: float) -> void:
	if _transport == null:
		return
	_transport.poll()
	for message in _transport.consume_incoming():
		_route_message(message)

	if _launch_config.dev_mode and _loading_started and _battle_runtime != null:
		_dev_ai_bridge.process_tick(delta, _joined_peer_ids)


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
	var message_type := _message_type(message)
	# ------------------------------------------------------------------
	# DEV MODE ONLY: Handle DEV_TOGGLE_AI from the dev client and return
	# early so the message never reaches the production routing branches.
	# ------------------------------------------------------------------
	if _launch_config.dev_mode and message_type == _DEV_TOGGLE_AI_MESSAGE_TYPE:
		_dev_ai_bridge.toggle(message.get("enabled", false), message.has("enabled"))
		return
	# ------------------------------------------------------------------
	# END DEV MODE ONLY
	# ------------------------------------------------------------------
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
			# DEV MODE ONLY: Remap sender_peer_id from ENet ID to logical ID=1.
			if _launch_config.dev_mode:
				var msg_sender := int(message.get("sender_peer_id", 0))
				if msg_sender > 0:
					var dev_msg := message.duplicate(true)
					dev_msg["sender_peer_id"] = 1
					LogNetScript.info("battle_ds received MATCH_LOADING_READY from enet_peer=%d match_id=%s revision=%d -> remapped to logical_peer=1" % [msg_sender, String(dev_msg.get("match_id", "")), int(dev_msg.get("revision", 0))], "", 0, "net.battle_ds_bootstrap")
					_battle_runtime.handle_loading_message(dev_msg)
					return
			# END DEV MODE ONLY
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
	# DEV MODE ONLY: Skip ticket dedup (tickets are not used in dev mode).
	if not _launch_config.dev_mode and _used_battle_ticket_ids.has(ticket_id):
		_reject_peer(peer_id, TransportMessageTypesScript.BATTLE_ENTRY_REJECTED, "BATTLE_TICKET_ALREADY_CONSUMED", "Battle ticket is already consumed")
		return
	# END DEV MODE ONLY
	var resume_token := ResumeTokenUtilsScript.generate_resume_token()
	var existing_session: Dictionary = _member_sessions_by_id.get(member_id, {})
	if not existing_session.is_empty() and String(existing_session.get("connection_state", "connected")) == "connected":
		_reject_peer(peer_id, TransportMessageTypesScript.BATTLE_ENTRY_REJECTED, "BATTLE_MEMBER_ALREADY_CONNECTED", "Battle member is already connected")
		return
	var match_peer_id := int(existing_session.get("match_peer_id", peer_id))
	if match_peer_id <= 0:
		match_peer_id = peer_id
	var slot_index := int(validation.get("slot_index", int(existing_session.get("slot_index", 0))))
	# DEV MODE ONLY: Resolve account/profile from manifest when claim is null.
	var resolved_account_id := String(manifest_member.get("account_id", "dev_account_%d" % peer_id))
	var resolved_profile_id := String(manifest_member.get("profile_id", "dev_profile_%d" % peer_id))
	if claim != null:
		resolved_account_id = String(claim.account_id)
		resolved_profile_id = String(claim.profile_id)
	# END DEV MODE ONLY
	var session := {
		"member_id": member_id,
		"account_id": resolved_account_id,
		"profile_id": resolved_profile_id,
		"ticket_id": ticket_id,
		"device_session_id": String(claim.device_session_id) if claim != null else "dev_session_%d" % peer_id,
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
	# DEV MODE ONLY: Skip ticket ID tracking in dev mode (tickets are not verified).
	if not _launch_config.dev_mode:
		_used_battle_ticket_ids[ticket_id] = true
	# END DEV MODE ONLY
	_refresh_joined_peer_ids_from_sessions()
	_battle_runtime.set_member_bindings(_build_runtime_member_bindings())
	LogNetScript.info("battle_entry_request accepted peer=%d member_id=%s battle_id=%s" % [peer_id, member_id, _launch_config.battle_id], "", 0, "net.battle_ds_bootstrap")
	if not _joined_peer_ids.has(peer_id):
		_joined_peer_ids.append(peer_id)
		if _launch_config.dev_mode and slot_index > 0 and not _dev_ai_bridge.has_driver(peer_id):
			_dev_ai_bridge.create_ai_driver(peer_id)
	_send_to_peer(peer_id, {
		"message_type": TransportMessageTypesScript.BATTLE_ENTRY_ACCEPTED,
		"battle_id": _launch_config.battle_id,
		"assignment_id": _launch_config.assignment_id,
		"match_id": _launch_config.match_id,
		"member_id": member_id,
		"resume_token": resume_token,
		"resume_window_sec": _launch_config.resume_window_sec,
	})
	# Gate: once all expected peers have joined, begin match loading
	var expected := int(_manifest.get("expected_member_count", 0))
	# DEV MODE ONLY: Start as soon as the first (human) peer connects.
	# Remaining players are AI-controlled via _dev_ai_drivers injected in _process().
	if expected > 0 and not _loading_started:
		if _launch_config.dev_mode:
			# Create sessions and AI drivers for all non-first slots, then
			# begin loading immediately so the human can start playing.
			var manifest_members: Array = _manifest.get("members", [])
			for idx in range(manifest_members.size()):
				if idx == 0:
					continue  # Slot 0 is the human peer, already connected.
				var m: Dictionary = manifest_members[idx] if manifest_members[idx] is Dictionary else {}
				var ai_member_id := _member_identity_key(
					String(m.get("account_id", "dev_account_%d" % (idx + 1))),
					String(m.get("profile_id", "dev_profile_%d" % (idx + 1)))
				)
				var ai_peer_id := 100 + idx
				if not _member_sessions_by_id.has(ai_member_id):
					_member_sessions_by_id[ai_member_id] = {
						"member_id": ai_member_id,
						"account_id": String(m.get("account_id", "dev_account_%d" % (idx + 1))),
						"profile_id": String(m.get("profile_id", "dev_profile_%d" % (idx + 1))),
						"ticket_id": "",
						"device_session_id": "dev_ai_session_%d" % idx,
						"match_peer_id": ai_peer_id,
						"transport_peer_id": ai_peer_id,
						"slot_index": idx,
						"assigned_team_id": int(m.get("assigned_team_id", (idx % 2) + 1)),
						"connection_state": "connected",
						"disconnect_deadline_msec": 0,
						"resume_token_hash": "",
						"resume_issued_at_msec": 0,
					}
					_member_id_by_peer_id[ai_peer_id] = ai_member_id
				if not _dev_ai_bridge.has_driver(ai_peer_id):
					_dev_ai_bridge.create_ai_driver(ai_peer_id)
				if not _joined_peer_ids.has(ai_peer_id):
					_joined_peer_ids.append(ai_peer_id)
			_refresh_joined_peer_ids_from_sessions()
			_battle_runtime.set_member_bindings(_build_runtime_member_bindings())
			_loading_started = true
			await _begin_battle_loading()
		elif _joined_peer_ids.size() >= expected:
			_loading_started = true
			await _begin_battle_loading()
	# END DEV MODE ONLY


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
	LogNetScript.info("battle_resume_request accepted peer=%d member_id=%s battle_id=%s" % [peer_id, member_id, _launch_config.battle_id], "", 0, "net.battle_ds_bootstrap")


func _on_match_finished(_result) -> void:
	LogNetScript.info("battle finished battle_id=%s, shutting down" % _launch_config.battle_id, "", 0, "net.battle_ds_bootstrap")


func _validate_battle_entry_request(message: Dictionary) -> Dictionary:
	# ------------------------------------------------------------------
	# DEV MODE ONLY: Accept any entry request without ticket verification.
	# Peer identity is extracted from the message itself.
	# ------------------------------------------------------------------
	if _launch_config.dev_mode:
		return _validate_battle_entry_request_dev(message)
	# ------------------------------------------------------------------
	# END DEV MODE ONLY
	# ------------------------------------------------------------------

	if _battle_ticket_verifier == null:
		return _plain_json_fail("BATTLE_TICKET_VERIFIER_MISSING", "Battle ticket verifier is not configured")
	if _manifest.is_empty():
		return _plain_json_fail("BATTLE_MANIFEST_MISSING", "Battle manifest is missing")
	var verification := _battle_ticket_verifier.verify_entry_ticket(message, _launch_config.battle_id, _manifest)
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


# ------------------------------------------------------------------
# DEV MODE ONLY: Accept any entry request by constructing member identity
# from the message and matching against the dev-constructed manifest.
# ------------------------------------------------------------------
func _validate_battle_entry_request_dev(message: Dictionary) -> Dictionary:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return _plain_json_fail("BATTLE_ENTRY_INVALID_PEER", "Invalid peer id")

	# In dev mode, each connecting peer claims an available manifest slot.
	# The first peer (human) typically sends slot_index=0.
	# Additional peers get subsequent slots for AI control.
	var claimed_slot := int(message.get("slot_index", -1))
	var manifest_members: Array = _manifest.get("members", [])

	var matched_member: Dictionary = {}
	var matched_slot := -1
	for idx in range(manifest_members.size()):
		var m: Dictionary = manifest_members[idx] if manifest_members[idx] is Dictionary else {}
		if claimed_slot >= 0 and idx == claimed_slot:
			matched_member = m
			matched_slot = idx
			break
	if matched_member.is_empty():
		# Fallback: assign next available slot
		for idx in range(manifest_members.size()):
			var m: Dictionary = manifest_members[idx] if manifest_members[idx] is Dictionary else {}
			var member_id := _member_identity_key(String(m.get("account_id", "")), String(m.get("profile_id", "")))
			if not _member_sessions_by_id.has(member_id):
				matched_member = m
				matched_slot = idx
				break
	if matched_member.is_empty():
		return _plain_json_fail("BATTLE_DEV_SLOTS_FULL", "All dev battle slots are occupied")

	var member_id := _member_identity_key(
		String(matched_member.get("account_id", "dev_account_%d" % peer_id)),
		String(matched_member.get("profile_id", "dev_profile_%d" % peer_id))
	)
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"claim": null,
		"member_id": member_id,
		"manifest_member": matched_member,
		"slot_index": matched_slot,
	}
# ------------------------------------------------------------------
# END DEV MODE ONLY
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# DEV MODE ONLY: Accept any entry request by constructing member identity
# from the message and matching against the dev-constructed manifest.
# ------------------------------------------------------------------
func _validate_battle_resume_request(message: Dictionary) -> Dictionary:
	var requested_battle_id := String(message.get("battle_id", "")).strip_edges()
	if requested_battle_id.is_empty():
		requested_battle_id = _launch_config.battle_id
	if requested_battle_id != _launch_config.battle_id:
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

# ------------------------------------------------------------------
# DEV MODE ONLY: Construct a fake battle manifest in memory.
# This replaces the normal HTTP fetch from game_service.
# ------------------------------------------------------------------
func _construct_dev_manifest() -> void:
	# Resolve content IDs from catalogs or command-line overrides.
	var map_id: String = _launch_config.dev_map_id_override if not _launch_config.dev_map_id_override.is_empty() else MapCatalogScript.get_default_map_id()
	# ------------------------------------------------------------------
	# DEV MODE ONLY: prefer the map's canonical mode/rule binding so the
	# manifest agrees with BattleStartConfigBuilder's authoritative
	# binding lookup. Without this, dev manifests fall back to global
	# default mode/rule and trigger spurious "rule/mode mismatch" warnings
	# at battle start. The dev_battle_launcher follows the same logic.
	# ------------------------------------------------------------------
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	var binding_mode_id := String(binding.get("bound_mode_id", ""))
	var binding_rule_set_id := String(binding.get("bound_rule_set_id", ""))
	var rule_set_id: String = _launch_config.dev_rule_set_id_override
	if rule_set_id.is_empty():
		rule_set_id = binding_rule_set_id
	if rule_set_id.is_empty():
		rule_set_id = RuleSetCatalogScript.get_default_rule_id()
	var mode_id := binding_mode_id
	if mode_id.is_empty() or not ModeCatalogScript.has_mode(mode_id):
		mode_id = ModeCatalogScript.get_default_mode_id()
	# ------------------------------------------------------------------
	# END DEV MODE ONLY
	# ------------------------------------------------------------------

	# Fallback IDs for environments where content may not be fully loaded.
	if _launch_config.battle_id.is_empty():
		_launch_config.battle_id = "dev_battle_%d" % randi_range(10000, 99999)
	if _launch_config.assignment_id.is_empty():
		_launch_config.assignment_id = "dev_assignment_%s" % _launch_config.battle_id
	if _launch_config.match_id.is_empty():
		_launch_config.match_id = "dev_match_%s" % _launch_config.battle_id
	if _launch_config.source_room_id.is_empty():
		_launch_config.source_room_id = "dev_room_%s" % _launch_config.battle_id
	_launch_config.source_room_kind = "dedicated_server"
	_launch_config.season_id = "dev_season_1"

	if _battle_runtime != null:
		_battle_runtime.battle_id = _launch_config.battle_id
		_battle_runtime.assignment_id = _launch_config.assignment_id
		_battle_runtime.match_id = _launch_config.match_id
		_battle_runtime.room_kind = _launch_config.source_room_kind
		_battle_runtime.season_id = _launch_config.season_id

	# Build fake member list.
	var members: Array[Dictionary] = []
	var resolved_team_count: int = clampi(_launch_config.dev_team_count, 2, max(_launch_config.dev_player_count, 2))
	var character_ids := CharacterCatalogScript.get_character_ids()
	for i in range(_launch_config.dev_player_count):
		var character_id := character_ids[i % character_ids.size()] if not character_ids.is_empty() else ""
		members.append({
			"account_id": "dev_account_%d" % (i + 1),
			"profile_id": "dev_profile_%d" % (i + 1),
			"assigned_team_id": (i % resolved_team_count) + 1,
			"character_id": character_id,
		})

	_manifest = {
		"expected_member_count": _launch_config.dev_player_count,
		"map_id": map_id,
		"rule_set_id": rule_set_id,
		"mode_id": mode_id,
		"members": members,
		"assignment_id": _launch_config.assignment_id,
		"match_id": _launch_config.match_id,
		"source_room_id": _launch_config.source_room_id,
		"source_room_kind": _launch_config.source_room_kind,
		"season_id": _launch_config.season_id,
	}

	_member_sessions_by_id.clear()
	_member_id_by_peer_id.clear()
	_used_battle_ticket_ids.clear()
	_joined_peer_ids.clear()
	_loading_started = false
	_dev_ai_bridge.clear()

	LogNetScript.info("dev_manifest constructed: expected_member_count=%d map_id=%s mode_id=%s" % [_launch_config.dev_player_count, map_id, mode_id], "", 0, "net.battle_ds_bootstrap")
	await _lifecycle_reporter.report_battle_ready(_manifest_client)
# ------------------------------------------------------------------
# END DEV MODE ONLY
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# DEV MODE ONLY: Construct a fake battle manifest in memory.
# This replaces the normal HTTP fetch from game_service.
# ------------------------------------------------------------------
func _fetch_manifest() -> void:
	if _launch_config.battle_id.is_empty():
		LogNetScript.warn("battle_ds: no battle_id, skipping manifest fetch", "", 0, "net.battle_ds_bootstrap")
		return
	_manifest_client = GameServiceBattleManifestClientScript.new()
	var game_base_url := _normalize_game_service_base_url(_read_env("GAME_SERVICE_BASE_URL", ""))
	if game_base_url.is_empty():
		var game_host := _read_env("GAME_SERVICE_HOST", "127.0.0.1")
		var game_port := int(_read_env("GAME_SERVICE_PORT", "18081").to_int())
		if game_port <= 0:
			game_port = 18081
		game_base_url = ServiceUrlBuilderScript.build_game_base_url(game_host, game_port, 18081)
	var secret_config: Dictionary = InternalServiceAuthConfigScript.resolve_shared_secret("GAME_INTERNAL_AUTH_SHARED_SECRET", "GAME_INTERNAL_SHARED_SECRET")
	var secret := String(secret_config.get("shared_secret", ""))
	var key_id := InternalServiceAuthConfigScript.resolve_key_id("GAME_INTERNAL_AUTH_KEY_ID", "primary")
	_manifest_client.configure(game_base_url, secret, key_id)
	var result := await _manifest_client.fetch_manifest(_launch_config.battle_id)
	if not bool(result.get("ok", false)):
		LogNetScript.warn("battle_manifest fetch failed: %s %s" % [String(result.get("error_code", "")), String(result.get("user_message", ""))], "", 0, "net.battle_ds_bootstrap")
		return
	_manifest = result
	_launch_config.source_room_id = String(_manifest.get("source_room_id", "")).strip_edges()
	_launch_config.source_room_kind = String(_manifest.get("source_room_kind", "")).strip_edges()
	_launch_config.season_id = String(_manifest.get("season_id", "")).strip_edges()
	if _battle_runtime != null:
		_battle_runtime.room_kind = _launch_config.source_room_kind
		_battle_runtime.season_id = _launch_config.season_id
	_member_sessions_by_id.clear()
	_member_id_by_peer_id.clear()
	_used_battle_ticket_ids.clear()
	_joined_peer_ids.clear()
	_loading_started = false
	LogNetScript.info("battle_manifest fetched ok: expected_member_count=%d map_id=%s mode_id=%s" % [int(_manifest.get("expected_member_count", 0)), String(_manifest.get("map_id", "")), String(_manifest.get("mode_id", ""))], "", 0, "net.battle_ds_bootstrap")
	await _lifecycle_reporter.report_battle_ready(_manifest_client)


func _begin_battle_loading() -> void:
	if _manifest.is_empty():
		LogNetScript.warn("battle_ds: cannot begin loading, manifest is empty", "", 0, "net.battle_ds_bootstrap")
		return
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = _launch_config.source_room_id if not _launch_config.source_room_id.is_empty() else _launch_config.battle_id
	snapshot.room_kind = _launch_config.source_room_kind if not _launch_config.source_room_kind.is_empty() else "dedicated_server"
	snapshot.topology = "dedicated_server"
	snapshot.selected_map_id = String(_manifest.get("map_id", ""))
	snapshot.rule_set_id = String(_manifest.get("rule_set_id", ""))
	snapshot.mode_id = String(_manifest.get("mode_id", ""))
	snapshot.min_start_players = int(_manifest.get("expected_member_count", 2))
	snapshot.max_players = int(_manifest.get("expected_member_count", 8))
	snapshot.all_ready = true
	snapshot.match_active = false
	snapshot.current_assignment_id = _launch_config.assignment_id
	snapshot.current_battle_id = _launch_config.battle_id
	snapshot.current_match_id = _launch_config.match_id
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
		# DEV MODE ONLY: Use logical peer_id=1 for the human so INPUT_BATCH peer_id matches.
		var logical_peer_id := transport_peer_id
		if _launch_config.dev_mode and idx == 0:
			logical_peer_id = 1
		# END DEV MODE ONLY
		member.peer_id = logical_peer_id
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
			"match_peer_id": logical_peer_id,
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
	await _lifecycle_reporter.report_ds_instance_active()

	# DEV MODE ONLY: Flag to send fake MATCH_LOADING_READY on next frame.
	if _launch_config.dev_mode:
		var prepared_cfg = result.get("config", null)
		if prepared_cfg != null:
			var match_id_str := String(prepared_cfg.match_id)
			if not match_id_str.is_empty():
				_dev_ai_bridge.set_match_id(match_id_str)
		_dev_ai_bridge.flag_pending_ai_ready()
	# END DEV MODE ONLY


func _plain_json_fail(error_code: String, user_message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "user_message": user_message}


# --- Transport helpers ---

func _send_to_peer(peer_id: int, message: Dictionary) -> void:
	if _transport == null:
		return
	# ------------------------------------------------------------------
	# DEV MODE ONLY: Remap logical peer_ids to transport IDs.
	# The client uses _local_peer_id=1, but the DS sees the ENet
	# transport ID. Map peer_id=1 to the human's real transport ID.
	# ------------------------------------------------------------------
	if _launch_config.dev_mode:
		# Skip synthetic AI peers with no real transport.
		if peer_id >= 100:
			return
		# Map logical peer_id=1 to the human's ENet transport ID.
		if peer_id == 1:
			for member_id in _member_sessions_by_id.keys():
				var session: Dictionary = _member_sessions_by_id.get(String(member_id), {})
				if int(session.get("slot_index", -1)) == 0:
					var real_peer := int(session.get("transport_peer_id", 0))
					if real_peer > 0:
						_transport.send_to_peer(real_peer, message)
					return
	# ------------------------------------------------------------------
	# END DEV MODE ONLY
	# ------------------------------------------------------------------
	_transport.send_to_peer(peer_id, message)
func _broadcast_message(message: Dictionary) -> void:
	if _transport == null:
		return
	# DEV MODE ONLY: Broadcast only; synthetic AI peers are filtered in _send_to_peer.
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
			session["disconnect_deadline_msec"] = Time.get_ticks_msec() + int(_launch_config.resume_window_sec * 1000.0)
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


func _message_type(message: Dictionary) -> String:
	return String(message.get("message_type", ""))


func _normalize_game_service_base_url(raw_url: String) -> String:
	return ServiceUrlBuilderScript.normalize_service_base_url(raw_url, 18081, "QQT_GAME_SERVICE_SCHEME")


# ------------------------------------------------------------------
# DEV MODE ONLY: Apply DEV_TOGGLE_AI from the dev client. The payload
# may carry an explicit "enabled" boolean; otherwise the flag is just
# flipped. Has no effect outside _launch_config.dev_mode and is unreachable on
# Dev toggle AI, server session resolution, and authority tick moved to ds_dev_ai_bridge.gd.
# END DEV MODE ONLY
# ------------------------------------------------------------------
