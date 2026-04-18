extends Node

## DEPRECATED (LegacyMigration): This is a compatibility wrapper.
## New code should use RoomAuthorityRuntime (room-only) or ServerBattleRuntime (battle-only).
## This file is kept only to avoid breaking existing references during migration.

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const ServerMatchServiceScript = preload("res://network/session/runtime/server_match_service.gd")
const ServerMatchLoadingCoordinatorScript = preload("res://network/session/runtime/server_match_loading_coordinator.gd")
const ServerMatchFinalizeReporterScript = preload("res://network/session/runtime/server_match_finalize_reporter.gd")
const ServerMatchResumeCoordinatorScript = preload("res://network/session/runtime/server_match_resume_coordinator.gd")
const GameServicePartyQueueClientScript = preload("res://network/services/game_service_party_queue_client.gd")
const InternalServiceAuthConfigScript = preload("res://app/infra/http/internal_service_auth_config.gd")
const RoomDirectoryEntryScript = preload("res://network/session/runtime/room_directory_entry.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const ONLINE_LOG_PREFIX := "[QQT_ONLINE]"

signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)

var authority_host: String = "127.0.0.1"
var authority_port: int = 9000
var room_ticket_secret: String = "dev_room_ticket_secret"
var game_service_host: String = "127.0.0.1"
var game_service_port: int = 18081
var game_internal_shared_secret: String = ""

var _room_service: ServerRoomService = null
var _match_service: ServerMatchService = null
var _loading_coordinator: ServerMatchLoadingCoordinator = null
var _match_finalize_reporter: ServerMatchFinalizeReporter = null
var _resume_coordinator: ServerMatchResumeCoordinator = null  # LegacyMigration
var _party_queue_client: GameServicePartyQueueClient = null


func _ready() -> void:
	_ensure_services()


func _process(_delta: float) -> void:
	# LegacyMigration: Poll resume window expiration
	if _resume_coordinator != null:
		_resume_coordinator.poll_expired()
	if _room_service != null and _room_service.has_method("poll_idle_resume_expired"):
		_room_service.poll_idle_resume_expired()


func configure(next_authority_host: String, next_authority_port: int, next_room_ticket_secret: String = "dev_room_ticket_secret") -> void:
	authority_host = next_authority_host if not next_authority_host.strip_edges().is_empty() else "127.0.0.1"
	authority_port = next_authority_port if next_authority_port > 0 else 9000
	room_ticket_secret = next_room_ticket_secret if not next_room_ticket_secret.strip_edges().is_empty() else "dev_room_ticket_secret"
	game_service_host = _read_env("GAME_SERVICE_HOST", game_service_host)
	game_service_port = int(_read_env("GAME_SERVICE_PORT", str(game_service_port)).to_int())
	if game_service_port <= 0:
		game_service_port = 18081
	var secret_config: Dictionary = InternalServiceAuthConfigScript.resolve_shared_secret("GAME_INTERNAL_AUTH_SHARED_SECRET", "GAME_INTERNAL_SHARED_SECRET")
	game_internal_shared_secret = String(secret_config.get("shared_secret", game_internal_shared_secret))
	_ensure_services()
	if _match_service != null:
		_match_service.authority_host = authority_host
		_match_service.authority_port = authority_port
	if _room_service != null and _room_service.has_method("configure_room_ticket_verifier"):
		_room_service.configure_room_ticket_verifier(room_ticket_secret)
	if _room_service != null and _party_queue_client != null and _room_service.has_method("configure_party_queue_client"):
		_room_service.configure_party_queue_client(_party_queue_client)


func create_room_from_request(message: Dictionary) -> Dictionary:
	_ensure_services()
	var previous_room_id := get_room_id()
	_log_online_room_runtime("create_room_from_request", {
		"previous_room_id": previous_room_id,
		"requested_room_kind": String(message.get("room_kind", "")),
		"requested_room_id_hint": String(message.get("room_id_hint", "")),
		"sender_peer_id": int(message.get("sender_peer_id", 0)),
	})
	_room_service.handle_message(message)
	var resolved_room_id := get_room_id()
	return {
		"ok": not resolved_room_id.is_empty(),
		"previous_room_id": previous_room_id,
		"room_id": resolved_room_id,
		"owner_peer_id": _room_service.room_state.owner_peer_id if _room_service != null and _room_service.room_state != null else 0,
		"room_kind": _room_service.room_state.room_kind if _room_service != null and _room_service.room_state != null else "",
	}


func handle_room_message(message: Dictionary) -> void:
	_ensure_services()
	if _room_service == null:
		return
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	if message_type == TransportMessageTypesScript.ROOM_REMATCH_REQUEST and _loading_coordinator != null and _loading_coordinator.is_loading_active():
		var peer_id := int(message.get("sender_peer_id", 0))
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_REMATCH_REJECTED,
			"error": "ROOM_LOADING_ACTIVE",
			"user_message": "Room is already in loading",
		})
		return
	if message_type == TransportMessageTypesScript.ROOM_CREATE_REQUEST or message_type == TransportMessageTypesScript.ROOM_JOIN_REQUEST:
		_log_online_room_runtime("handle_room_message", {
			"message_type": message_type,
			"sender_peer_id": int(message.get("sender_peer_id", 0)),
			"room_id_hint": String(message.get("room_id_hint", "")),
		})
	_room_service.handle_message(message)


func handle_battle_message(message: Dictionary) -> void:
	_ensure_services()
	if _match_service == null:
		return
	
	# LegacyMigration: Validate battle input sender
	if _room_service != null and _room_service.room_state != null and _room_service.room_state.match_active:
		var sender_transport_peer_id := int(message.get("sender_peer_id", 0))
		var frame: Dictionary = Dictionary(message.get("frame", {}))
		var frame_peer_id := int(frame.get("peer_id", message.get("peer_id", 0)))
		
		# Get member binding for this transport
		var binding := _room_service.room_state.get_member_binding_by_transport_peer(sender_transport_peer_id)
		if binding == null:
			# Unknown sender - reject
			LogNetScript.warn("battle_input_rejected unknown_transport sender=%d" % sender_transport_peer_id, "", 0, "net.room_runtime.input_guard")
			return
		
		# Validate frame.peer_id matches allowed match_peer_id
		var allowed_match_peer_id := binding.match_peer_id
		if frame_peer_id != allowed_match_peer_id:
			# Frame peer_id mismatch - reject
			LogNetScript.warn("battle_input_rejected frame_peer_mismatch sender=%d frame=%d allowed=%d" % [sender_transport_peer_id, frame_peer_id, allowed_match_peer_id], "", 0, "net.room_runtime.input_guard")
			return
	
	_match_service.ingest_runtime_message(message)


func handle_loading_message(message: Dictionary) -> void:
	_ensure_services()
	if _loading_coordinator == null:
		return
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	if message_type == TransportMessageTypesScript.MATCH_LOADING_READY:
		var peer_id := int(message.get("sender_peer_id", 0))
		var match_id := String(message.get("match_id", ""))
		var revision := int(message.get("revision", 0))
		_loading_coordinator.mark_peer_ready(peer_id, match_id, revision)


func handle_peer_disconnected(peer_id: int) -> void:
	_ensure_services()
	
	# Loading phase disconnect - still abort immediately
	if _loading_coordinator != null and _loading_coordinator.is_loading_active():
		_loading_coordinator.handle_peer_disconnected(peer_id)
		if _room_service != null:
			_room_service.handle_peer_disconnected(peer_id)
		return
	
	# LegacyMigration: Active match disconnect - enter resume window instead of immediate abort
	if _match_service != null and _match_service.is_match_active():
		var binding := _room_service.room_state.get_member_binding_by_transport_peer(peer_id)
		if binding != null:
			# Mark member as disconnected and create resume window
			_resume_coordinator.on_member_disconnected(binding.member_id)
			# Broadcast updated snapshot with disconnected state
			if _room_service != null and _room_service.has_method("_broadcast_snapshot"):
				_room_service.call("_broadcast_snapshot")
			return
		# If no binding found, fall through to remove member
	
	# Room idle phase - remove member normally
	if _room_service != null:
		_room_service.handle_peer_disconnected(peer_id)


func build_directory_entry() -> RoomDirectoryEntry:
	_ensure_services()
	if _room_service == null or _room_service.room_state == null:
		return null
	var room_state := _room_service.room_state
	if not room_state.is_public_room:
		return null
	var entry := RoomDirectoryEntryScript.new()
	entry.room_id = room_state.room_id
	entry.room_display_name = room_state.room_display_name
	entry.room_kind = room_state.room_kind
	entry.owner_peer_id = room_state.owner_peer_id
	entry.owner_name = _resolve_owner_name(room_state.owner_peer_id)
	entry.selected_map_id = room_state.selected_map_id
	entry.rule_set_id = room_state.selected_rule_id
	entry.mode_id = room_state.selected_mode_id
	entry.member_count = room_state.members.size()
	entry.max_players = room_state.max_players
	entry.match_active = room_state.match_active
	var loading_active := _loading_coordinator != null and _loading_coordinator.is_loading_active()
	entry.joinable = not room_state.match_active and not loading_active and entry.member_count < entry.max_players and not entry.room_id.is_empty()
	return entry


func is_empty() -> bool:
	_ensure_services()
	return _room_service == null or _room_service.room_state == null or _room_service.room_state.members.is_empty()


func is_match_active() -> bool:
	_ensure_services()
	return _match_service != null and _match_service.is_match_active()


func get_room_state():
	_ensure_services()
	return _room_service.room_state if _room_service != null else null


func get_match_service() -> ServerMatchService:
	_ensure_services()
	return _match_service


func get_room_id() -> String:
	_ensure_services()
	if _room_service == null or _room_service.room_state == null:
		return ""
	return String(_room_service.room_state.room_id)


func has_peer(peer_id: int) -> bool:
	_ensure_services()
	if _room_service == null or _room_service.room_state == null:
		return false
	if _room_service.room_state.members.has(peer_id):
		return true
	return _room_service.room_state.get_member_binding_by_transport_peer(peer_id) != null


func can_route_resume_request(member_id: String, reconnect_token: String) -> bool:
	_ensure_services()
	if _room_service == null or _room_service.room_state == null:
		return false
	var normalized_member_id := member_id.strip_edges()
	var normalized_token := reconnect_token.strip_edges()
	if normalized_member_id.is_empty() or normalized_token.is_empty():
		return false
	var binding := _room_service.room_state.get_member_binding_by_member_id(normalized_member_id)
	return binding != null and binding.is_reconnect_token_valid(normalized_token)


func _ensure_services() -> void:
	if _room_service == null:
		_room_service = ServerRoomServiceScript.new()
		_room_service.name = "ServerRoomService"
		add_child(_room_service)
		if _room_service.has_method("configure_room_ticket_verifier"):
			_room_service.configure_room_ticket_verifier(room_ticket_secret)
		_connect_room_service_signals()
	if _match_service == null:
		_match_service = ServerMatchServiceScript.new()
		_match_service.name = "ServerMatchService"
		add_child(_match_service)
		_connect_match_service_signals()
	if _loading_coordinator == null:
		_loading_coordinator = ServerMatchLoadingCoordinatorScript.new()
		_loading_coordinator.configure(
			_prepare_match_callable(),
			_commit_match_callable(),
			_send_to_peer_callable(),
			_broadcast_message_callable(),
			_loading_started_callable(),
			_loading_aborted_callable(),
			_loading_committed_callable()
		)
	# LegacyMigration: Initialize resume coordinator
	if _resume_coordinator == null:
		_resume_coordinator = ServerMatchResumeCoordinatorScript.new()
		_resume_coordinator.name = "ServerMatchResumeCoordinator"
		add_child(_resume_coordinator)
		_connect_resume_coordinator_signals()
		if _room_service != null and _match_service != null:
			_resume_coordinator.configure(_room_service.room_state, _match_service)
	if _match_finalize_reporter == null:
		_match_finalize_reporter = ServerMatchFinalizeReporterScript.new()
		_match_finalize_reporter.configure()
	if _party_queue_client == null:
		_party_queue_client = GameServicePartyQueueClientScript.new()
		var resolved_game_host := _read_env("GAME_SERVICE_HOST", game_service_host)
		var resolved_game_port := int(_read_env("GAME_SERVICE_PORT", str(game_service_port)).to_int())
		if resolved_game_port <= 0:
			resolved_game_port = 18081
		var resolved_secret_config: Dictionary = InternalServiceAuthConfigScript.resolve_shared_secret("GAME_INTERNAL_AUTH_SHARED_SECRET", "GAME_INTERNAL_SHARED_SECRET")
		var resolved_secret := String(resolved_secret_config.get("shared_secret", game_internal_shared_secret))
		var resolved_key_id := InternalServiceAuthConfigScript.resolve_key_id("GAME_INTERNAL_AUTH_KEY_ID", "primary")
		_party_queue_client.configure("http://%s:%d" % [resolved_game_host, resolved_game_port], resolved_secret, resolved_key_id)
		if _room_service != null and _room_service.has_method("configure_party_queue_client"):
			_room_service.configure_party_queue_client(_party_queue_client)
	if _match_service != null:
		_match_service.authority_host = authority_host
		_match_service.authority_port = authority_port


func _connect_room_service_signals() -> void:
	if _room_service == null:
		return
	if not _room_service.send_to_peer.is_connected(_emit_send_to_peer):
		_room_service.send_to_peer.connect(_emit_send_to_peer)
	if not _room_service.broadcast_message.is_connected(_emit_broadcast_message):
		_room_service.broadcast_message.connect(_emit_broadcast_message)
	if not _room_service.start_match_requested.is_connected(_on_start_match_requested):
		_room_service.start_match_requested.connect(_on_start_match_requested)
	# LegacyMigration: Connect resume request signal
	if _room_service.has_signal("resume_request_received") and not _room_service.resume_request_received.is_connected(_on_resume_request_received):
		_room_service.resume_request_received.connect(_on_resume_request_received)
	if _room_service.has_signal("assignment_commit_requested") and not _room_service.assignment_commit_requested.is_connected(_on_assignment_commit_requested):
		_room_service.assignment_commit_requested.connect(_on_assignment_commit_requested)


func _connect_match_service_signals() -> void:
	if _match_service == null:
		return
	if not _match_service.send_to_peer.is_connected(_emit_send_to_peer):
		_match_service.send_to_peer.connect(_emit_send_to_peer)
	if not _match_service.broadcast_message.is_connected(_emit_match_broadcast_message):
		_match_service.broadcast_message.connect(_emit_match_broadcast_message)
	if not _match_service.match_finished.is_connected(_on_match_finished):
		_match_service.match_finished.connect(_on_match_finished)


# LegacyMigration: Connect resume coordinator signals
func _connect_resume_coordinator_signals() -> void:
	if _resume_coordinator == null:
		return
	if not _resume_coordinator.send_to_peer.is_connected(_emit_send_to_peer):
		_resume_coordinator.send_to_peer.connect(_emit_send_to_peer)
	if not _resume_coordinator.match_abort_requested.is_connected(_on_match_resume_timeout_abort_requested):
		_resume_coordinator.match_abort_requested.connect(_on_match_resume_timeout_abort_requested)


func _on_start_match_requested(snapshot: RoomSnapshot) -> void:
	if _loading_coordinator == null:
		_ensure_services()
	var result: Dictionary = _loading_coordinator.begin_loading(snapshot)
	if bool(result.get("ok", false)):
		return
	_emit_broadcast_message({
		"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
		"user_message": String(result.get("user_message", "Server failed to start match")),
	})


func _on_match_finished(_result: BattleResult) -> void:
	if _room_service != null and _room_service.has_method("handle_match_finished"):
		_room_service.handle_match_finished()
	_log_online_room_runtime("match_finished", _build_online_runtime_context())
	if _match_finalize_reporter != null and _match_finalize_reporter.has_method("report_match_result_async"):
		_match_finalize_reporter.report_match_result_async(self, _result)
	# LegacyMigration: Clear resume state on match finish
	if _resume_coordinator != null:
		_resume_coordinator.clear_match_state()


func _on_assignment_commit_requested(payload: Dictionary) -> void:
	_log_online_room_runtime("assignment_commit_requested", payload)
	if _match_finalize_reporter != null and _match_finalize_reporter.has_method("report_assignment_commit_async"):
		_match_finalize_reporter.report_assignment_commit_async(payload)


# LegacyMigration: Handle resume timeout abort request
func _on_match_resume_timeout_abort_requested(reason: String, member_id: String) -> void:
	if _match_service != null and _match_service.is_match_active():
		_match_service.abort_match_due_to_resume_timeout(member_id)


# LegacyMigration: Handle resume request from ServerRoomService
func _on_resume_request_received(message: Dictionary) -> void:
	if _resume_coordinator == null:
		return
	
	var peer_id := int(message.get("sender_peer_id", 0))
	var member_id := String(message.get("member_id", ""))
	var reconnect_token := String(message.get("reconnect_token", ""))
	var match_id := String(message.get("match_id", ""))
	
	var result := _resume_coordinator.try_resume(member_id, reconnect_token, peer_id, match_id)
	
	if not result.get("ok", false):
		if _room_service != null and _room_service.room_state != null:
			var binding := _room_service.room_state.get_member_binding_by_member_id(member_id)
			if binding != null and binding.connection_state == "resuming":
				binding.connection_state = "disconnected"
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.MATCH_RESUME_REJECTED,
			"error": result.get("error", "RESUME_FAILED"),
			"user_message": "Match resume failed: " + str(result.get("error", "unknown")),
		})
		return
	if _room_service != null and _room_service.room_state != null:
		var binding := _room_service.room_state.get_member_binding_by_member_id(member_id)
		var ticket_claim: Dictionary = Dictionary(message.get("ticket_claim", {}))
		if binding != null and not ticket_claim.is_empty():
			binding.device_session_id = String(ticket_claim.get("device_session_id", binding.device_session_id))
			binding.ticket_id = String(ticket_claim.get("ticket_id", binding.ticket_id))
			binding.auth_claim_version = 1
			binding.display_name_source = "profile"


func _emit_send_to_peer(peer_id: int, message: Dictionary) -> void:
	send_to_peer.emit(peer_id, message)


func _emit_broadcast_message(message: Dictionary) -> void:
	broadcast_message.emit(message)


func _emit_match_broadcast_message(message: Dictionary) -> void:
	if _room_service == null or _room_service.room_state == null:
		broadcast_message.emit(message)
		return
	var target_peer_ids := _resolve_connected_match_transport_peer_ids()
	if target_peer_ids.is_empty():
		LogNetScript.warn(
			"match_broadcast_no_connected_targets type=%s" % String(message.get("message_type", message.get("msg_type", ""))),
			"",
			0,
			"net.room_runtime.match_broadcast"
		)
		return
	for peer_id in target_peer_ids:
		send_to_peer.emit(peer_id, message)


func _resolve_connected_match_transport_peer_ids() -> Array[int]:
	var target_peer_ids: Array[int] = []
	if _room_service == null or _room_service.room_state == null:
		return target_peer_ids
	for member_id_variant in _room_service.room_state.member_bindings_by_member_id.keys():
		var member_id := String(member_id_variant)
		var binding := _room_service.room_state.get_member_binding_by_member_id(member_id)
		if binding == null:
			continue
		if String(binding.connection_state) != "connected":
			continue
		var transport_peer_id := int(binding.transport_peer_id)
		if transport_peer_id <= 0:
			continue
		if target_peer_ids.has(transport_peer_id):
			continue
		target_peer_ids.append(transport_peer_id)
	target_peer_ids.sort()
	return target_peer_ids


func _resolve_owner_name(owner_peer_id: int) -> String:
	if _room_service == null or _room_service.room_state == null:
		return ""
	var profile: Dictionary = _room_service.room_state.members.get(owner_peer_id, {})
	return String(profile.get("player_name", ""))


func _prepare_match_callable() -> Callable:
	return Callable(self, "_do_prepare_match")


func _commit_match_callable() -> Callable:
	return Callable(self, "_do_commit_match")


func _send_to_peer_callable() -> Callable:
	return Callable(self, "_do_send_to_peer")


func _broadcast_message_callable() -> Callable:
	return Callable(self, "_do_broadcast_message")


func _loading_started_callable() -> Callable:
	return Callable(self, "_on_loading_started")


func _loading_aborted_callable() -> Callable:
	return Callable(self, "_on_loading_aborted")


func _loading_committed_callable() -> Callable:
	return Callable(self, "_on_loading_committed")


func _do_prepare_match(snapshot: RoomSnapshot) -> Dictionary:
	if _match_service == null:
		_ensure_services()
	return _match_service.prepare_match(snapshot)


func _do_commit_match(config: BattleStartConfig) -> Dictionary:
	if _match_service == null:
		_ensure_services()
	return _match_service.commit_prepared_match(config)


func _do_send_to_peer(peer_id: int, message: Dictionary) -> void:
	send_to_peer.emit(peer_id, message)


func _do_broadcast_message(message: Dictionary) -> void:
	broadcast_message.emit(message)


func _on_loading_started(_snapshot: MatchLoadingSnapshot) -> void:
	if _room_service != null and _room_service.has_method("handle_loading_started"):
		_room_service.handle_loading_started()


func _on_loading_aborted(_error_code: String, _user_message: String, _snapshot: MatchLoadingSnapshot) -> void:
	if _room_service != null and _room_service.has_method("handle_loading_aborted"):
		_room_service.handle_loading_aborted()


func _on_loading_committed(_config: BattleStartConfig, _snapshot: MatchLoadingSnapshot) -> void:
	if _room_service != null and _room_service.has_method("handle_match_committed"):
		_room_service.handle_match_committed()
	if _resume_coordinator != null:
		_resume_coordinator.on_match_committed(_config)
	_log_online_room_runtime("loading_committed", _build_online_runtime_context())


func _build_online_runtime_context() -> Dictionary:
	var room_state = _room_service.room_state if _room_service != null else null
	return {
		"room_id": String(room_state.room_id) if room_state != null else "",
		"room_kind": String(room_state.room_kind) if room_state != null else "",
		"assignment_id": String(room_state.assignment_id) if room_state != null else "",
		"assignment_revision": int(room_state.assignment_revision) if room_state != null else 0,
		"season_id": String(room_state.season_id) if room_state != null else "",
		"expected_member_count": int(room_state.expected_member_count) if room_state != null else 0,
		"member_count": room_state.members.size() if room_state != null else 0,
		"match_active": bool(room_state.match_active) if room_state != null else false,
	}


func _log_online_room_runtime(event_name: String, payload: Dictionary) -> void:
	LogNetScript.debug("%s[server_room_runtime] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "net.online.room_runtime")


func _read_env(name: String, fallback: String) -> String:
	var value := OS.get_environment(name).strip_edges()
	return value if not value.is_empty() else fallback
