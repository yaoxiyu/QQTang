class_name RoomAuthorityRuntime
extends Node

## Phase23: Room-only runtime. Extracted from ServerRoomRuntime.
## Handles room create/join/leave/resume, snapshot broadcast, directory entry,
## party queue client. Does NOT handle battle input, match service, loading,
## finalize, or resume coordinator.

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const GameServicePartyQueueClientScript = preload("res://network/services/game_service_party_queue_client.gd")
const RoomDirectoryEntryScript = preload("res://network/session/runtime/room_directory_entry.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const ONLINE_LOG_PREFIX := "[QQT_ONLINE]"

signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)
signal battle_start_requested(snapshot: RoomSnapshot)

var authority_host: String = "127.0.0.1"
var authority_port: int = 9100
var room_ticket_secret: String = "dev_room_ticket_secret"
var game_service_host: String = "127.0.0.1"
var game_service_port: int = 18081
var game_internal_shared_secret: String = ""

var _room_service: ServerRoomService = null
var _party_queue_client: GameServicePartyQueueClient = null


func _ready() -> void:
	_ensure_services()


func _process(_delta: float) -> void:
	if _room_service != null and _room_service.has_method("poll_idle_resume_expired"):
		_room_service.poll_idle_resume_expired()


func configure(next_authority_host: String, next_authority_port: int, next_room_ticket_secret: String = "dev_room_ticket_secret") -> void:
	authority_host = next_authority_host if not next_authority_host.strip_edges().is_empty() else "127.0.0.1"
	authority_port = next_authority_port if next_authority_port > 0 else 9100
	room_ticket_secret = next_room_ticket_secret if not next_room_ticket_secret.strip_edges().is_empty() else "dev_room_ticket_secret"
	game_service_host = _read_env("GAME_SERVICE_HOST", game_service_host)
	game_service_port = int(_read_env("GAME_SERVICE_PORT", str(game_service_port)).to_int())
	if game_service_port <= 0:
		game_service_port = 18081
	game_internal_shared_secret = _read_env("GAME_INTERNAL_SHARED_SECRET", game_internal_shared_secret)
	_ensure_services()
	if _room_service != null and _room_service.has_method("configure_room_ticket_verifier"):
		_room_service.configure_room_ticket_verifier(room_ticket_secret)
	if _room_service != null and _party_queue_client != null and _room_service.has_method("configure_party_queue_client"):
		_room_service.configure_party_queue_client(_party_queue_client)


func create_room_from_request(message: Dictionary) -> Dictionary:
	_ensure_services()
	var previous_room_id := get_room_id()
	_log("create_room_from_request", {
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
	if message_type == TransportMessageTypesScript.ROOM_CREATE_REQUEST or message_type == TransportMessageTypesScript.ROOM_JOIN_REQUEST:
		_log("handle_room_message", {
			"message_type": message_type,
			"sender_peer_id": int(message.get("sender_peer_id", 0)),
			"room_id_hint": String(message.get("room_id_hint", "")),
		})
	_room_service.handle_message(message)


func handle_peer_disconnected(peer_id: int) -> void:
	_ensure_services()
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
	var is_frozen := room_state.room_lifecycle_state == "in_battle_frozen" or room_state.room_lifecycle_state == "allocating_battle" or room_state.room_lifecycle_state == "battle_ready"
	entry.joinable = not room_state.match_active and not is_frozen and entry.member_count < entry.max_players and not entry.room_id.is_empty()
	return entry


func is_empty() -> bool:
	_ensure_services()
	return _room_service == null or _room_service.room_state == null or _room_service.room_state.members.is_empty()


func get_room_state():
	_ensure_services()
	return _room_service.room_state if _room_service != null else null


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


## Phase23: Notify room that battle has finished (called by external orchestration)
func notify_battle_finished() -> void:
	if _room_service != null and _room_service.has_method("handle_match_finished"):
		_room_service.handle_match_finished()
	if _room_service != null and _room_service.room_state != null:
		_room_service.room_state.room_lifecycle_state = "awaiting_return"
		_room_service.room_state.battle_allocation_state = ""
		_room_service.room_state.current_battle_id = ""


## Phase23: Freeze room when battle allocation begins
func freeze_for_battle(assignment_id: String, battle_id: String, allocation_state: String = "allocating_battle") -> void:
	if _room_service == null or _room_service.room_state == null:
		return
	var rs := _room_service.room_state
	rs.room_lifecycle_state = allocation_state
	rs.current_assignment_id = assignment_id
	rs.current_battle_id = battle_id
	rs.battle_allocation_state = "allocating"


## Phase23: Update battle endpoint when DS is ready
func set_battle_ready(battle_server_host: String, battle_server_port: int) -> void:
	if _room_service == null or _room_service.room_state == null:
		return
	var rs := _room_service.room_state
	rs.room_lifecycle_state = "battle_ready"
	rs.battle_allocation_state = "battle_ready"
	rs.battle_server_host = battle_server_host
	rs.battle_server_port = battle_server_port


## Phase23: Transition to in_battle_frozen when clients enter battle
func enter_battle_frozen() -> void:
	if _room_service == null or _room_service.room_state == null:
		return
	_room_service.room_state.room_lifecycle_state = "in_battle_frozen"
	_room_service.room_state.match_active = true


## Phase23: Restore room to idle after battle return
func restore_after_battle() -> void:
	if _room_service == null or _room_service.room_state == null:
		return
	var rs := _room_service.room_state
	rs.room_lifecycle_state = "idle"
	rs.current_assignment_id = ""
	rs.current_battle_id = ""
	rs.battle_allocation_state = ""
	rs.battle_server_host = ""
	rs.battle_server_port = 0
	rs.match_active = false
	rs.reset_ready_state()


func _ensure_services() -> void:
	if _room_service == null:
		_room_service = ServerRoomServiceScript.new()
		_room_service.name = "ServerRoomService"
		add_child(_room_service)
		if _room_service.has_method("configure_room_ticket_verifier"):
			_room_service.configure_room_ticket_verifier(room_ticket_secret)
		_connect_room_service_signals()
	if _party_queue_client == null:
		_party_queue_client = GameServicePartyQueueClientScript.new()
		var resolved_game_host := _read_env("GAME_SERVICE_HOST", game_service_host)
		var resolved_game_port := int(_read_env("GAME_SERVICE_PORT", str(game_service_port)).to_int())
		if resolved_game_port <= 0:
			resolved_game_port = 18081
		var resolved_secret := _read_env("GAME_INTERNAL_SHARED_SECRET", game_internal_shared_secret)
		_party_queue_client.configure("http://%s:%d" % [resolved_game_host, resolved_game_port], resolved_secret)
		if _room_service != null and _room_service.has_method("configure_party_queue_client"):
			_room_service.configure_party_queue_client(_party_queue_client)


func _connect_room_service_signals() -> void:
	if _room_service == null:
		return
	if not _room_service.send_to_peer.is_connected(_emit_send_to_peer):
		_room_service.send_to_peer.connect(_emit_send_to_peer)
	if not _room_service.broadcast_message.is_connected(_emit_broadcast_message):
		_room_service.broadcast_message.connect(_emit_broadcast_message)
	if not _room_service.start_match_requested.is_connected(_on_start_match_requested):
		_room_service.start_match_requested.connect(_on_start_match_requested)
	if _room_service.has_signal("assignment_commit_requested") and not _room_service.assignment_commit_requested.is_connected(_on_assignment_commit_requested):
		_room_service.assignment_commit_requested.connect(_on_assignment_commit_requested)


func _on_start_match_requested(snapshot: RoomSnapshot) -> void:
	battle_start_requested.emit(snapshot)


func _on_assignment_commit_requested(payload: Dictionary) -> void:
	_log("assignment_commit_requested", payload)


func _emit_send_to_peer(peer_id: int, message: Dictionary) -> void:
	send_to_peer.emit(peer_id, message)


func _emit_broadcast_message(message: Dictionary) -> void:
	broadcast_message.emit(message)


func _resolve_owner_name(owner_peer_id: int) -> String:
	if _room_service == null or _room_service.room_state == null:
		return ""
	var profile: Dictionary = _room_service.room_state.members.get(owner_peer_id, {})
	return String(profile.get("player_name", ""))


func _log(event_name: String, payload: Dictionary) -> void:
	LogNetScript.debug("%s[room_authority_runtime] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "net.online.room_authority_runtime")


func _read_env(env_name: String, fallback: String) -> String:
	var value := OS.get_environment(env_name).strip_edges()
	return value if not value.is_empty() else fallback
