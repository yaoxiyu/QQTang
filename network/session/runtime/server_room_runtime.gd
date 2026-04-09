class_name ServerRoomRuntime
extends Node

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const ServerMatchServiceScript = preload("res://network/session/runtime/server_match_service.gd")
const RoomDirectoryEntryScript = preload("res://network/session/runtime/room_directory_entry.gd")

signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)

var authority_host: String = "127.0.0.1"
var authority_port: int = 9000

var _room_service: ServerRoomService = null
var _match_service: ServerMatchService = null


func _ready() -> void:
	_ensure_services()


func configure(next_authority_host: String, next_authority_port: int) -> void:
	authority_host = next_authority_host if not next_authority_host.strip_edges().is_empty() else "127.0.0.1"
	authority_port = next_authority_port if next_authority_port > 0 else 9000
	_ensure_services()
	if _match_service != null:
		_match_service.authority_host = authority_host
		_match_service.authority_port = authority_port


func create_room_from_request(message: Dictionary) -> Dictionary:
	_ensure_services()
	var previous_room_id := get_room_id()
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
	_room_service.handle_message(message)


func handle_battle_message(message: Dictionary) -> void:
	_ensure_services()
	if _match_service == null:
		return
	_match_service.ingest_runtime_message(message)


func handle_peer_disconnected(peer_id: int) -> void:
	_ensure_services()
	if _match_service != null and _match_service.is_match_active():
		_match_service.abort_match_due_to_disconnect(peer_id)
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
	entry.joinable = not room_state.match_active and entry.member_count < entry.max_players and not entry.room_id.is_empty()
	return entry


func is_empty() -> bool:
	_ensure_services()
	return _room_service == null or _room_service.room_state == null or _room_service.room_state.members.is_empty()


func is_match_active() -> bool:
	_ensure_services()
	return _match_service != null and _match_service.is_match_active()


func get_room_id() -> String:
	_ensure_services()
	if _room_service == null or _room_service.room_state == null:
		return ""
	return String(_room_service.room_state.room_id)


func has_peer(peer_id: int) -> bool:
	_ensure_services()
	if _room_service == null or _room_service.room_state == null:
		return false
	return _room_service.room_state.members.has(peer_id)


func _ensure_services() -> void:
	if _room_service == null:
		_room_service = ServerRoomServiceScript.new()
		_room_service.name = "ServerRoomService"
		add_child(_room_service)
		_connect_room_service_signals()
	if _match_service == null:
		_match_service = ServerMatchServiceScript.new()
		_match_service.name = "ServerMatchService"
		add_child(_match_service)
		_connect_match_service_signals()
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


func _connect_match_service_signals() -> void:
	if _match_service == null:
		return
	if not _match_service.send_to_peer.is_connected(_emit_send_to_peer):
		_match_service.send_to_peer.connect(_emit_send_to_peer)
	if not _match_service.broadcast_message.is_connected(_emit_broadcast_message):
		_match_service.broadcast_message.connect(_emit_broadcast_message)
	if not _match_service.match_finished.is_connected(_on_match_finished):
		_match_service.match_finished.connect(_on_match_finished)


func _on_start_match_requested(snapshot: RoomSnapshot) -> void:
	if _match_service == null:
		return
	var result: Dictionary = _match_service.start_match(snapshot)
	if bool(result.get("ok", false)):
		return
	_emit_broadcast_message({
		"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
		"user_message": String(result.get("validation", {}).get("error_message", "Server failed to start match")),
	})


func _on_match_finished(_result: BattleResult) -> void:
	if _room_service != null and _room_service.has_method("handle_match_finished"):
		_room_service.handle_match_finished()


func _emit_send_to_peer(peer_id: int, message: Dictionary) -> void:
	send_to_peer.emit(peer_id, message)


func _emit_broadcast_message(message: Dictionary) -> void:
	broadcast_message.emit(message)


func _resolve_owner_name(owner_peer_id: int) -> String:
	if _room_service == null or _room_service.room_state == null:
		return ""
	var profile: Dictionary = _room_service.room_state.members.get(owner_peer_id, {})
	return String(profile.get("player_name", ""))
