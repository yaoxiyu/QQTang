class_name RoomAuthorityRuntime
extends Node

## Phase23: Room-only runtime. Extracted from ServerRoomRuntime.
## Handles room create/join/leave/resume, snapshot broadcast, directory entry,
## party queue client. Does NOT handle battle input, match service, loading,
## finalize, or resume coordinator.

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const GameServicePartyQueueClientScript = preload("res://network/services/game_service_party_queue_client.gd")
const GameServiceBattleAllocClientScript = preload("res://network/services/game_service_battle_alloc_client.gd")
const RoomDirectoryEntryScript = preload("res://network/session/runtime/room_directory_entry.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const ROOM_AUTHORITY_LOG_TAG := "net.room_authority_runtime"

signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)

var authority_host: String = "127.0.0.1"
var authority_port: int = 9100
var room_ticket_secret: String = "dev_room_ticket_secret"
var game_service_host: String = "127.0.0.1"
var game_service_port: int = 18081
var game_internal_shared_secret: String = ""

var _room_service: ServerRoomService = null
var _party_queue_client: GameServicePartyQueueClient = null
var _battle_alloc_client: GameServiceBattleAllocClient = null


func _ready() -> void:
	_ensure_services()


func _process(_delta: float) -> void:
	if _room_service != null and _room_service.has_method("poll_idle_resume_expired"):
		_room_service.poll_idle_resume_expired()
	if _room_service != null and _room_service.has_method("poll_queue_status"):
		_room_service.poll_queue_status()


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
	rs.current_match_id = ""
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
		var resolved_key_id := _read_env("GAME_INTERNAL_AUTH_KEY_ID", "primary")
		_party_queue_client.configure("http://%s:%d" % [resolved_game_host, resolved_game_port], resolved_secret, resolved_key_id)
		if _room_service != null and _room_service.has_method("configure_party_queue_client"):
			_room_service.configure_party_queue_client(_party_queue_client)
	if _battle_alloc_client == null:
		_battle_alloc_client = GameServiceBattleAllocClientScript.new()
		var alloc_game_host := _read_env("GAME_SERVICE_HOST", game_service_host)
		var alloc_game_port := int(_read_env("GAME_SERVICE_PORT", str(game_service_port)).to_int())
		if alloc_game_port <= 0:
			alloc_game_port = 18081
		var alloc_secret := _read_env("GAME_INTERNAL_SHARED_SECRET", game_internal_shared_secret)
		var alloc_key_id := _read_env("GAME_INTERNAL_AUTH_KEY_ID", "primary")
		_battle_alloc_client.configure("http://%s:%d" % [alloc_game_host, alloc_game_port], alloc_secret, alloc_key_id)


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


func _on_start_match_requested(_snapshot: RoomSnapshot) -> void:
	_ensure_services()
	if _room_service == null or _room_service.room_state == null:
		return
	var rs := _room_service.room_state
	var assignment_id := "custom_%s_%d" % [rs.room_id, Time.get_ticks_msec()]
	var members_array := _build_members_array_from_room_state()
	_request_battle_ds_allocation(assignment_id, rs.selected_map_id, rs.selected_mode_id, rs.selected_rule_id, rs.room_kind, members_array)


func _on_assignment_commit_requested(payload: Dictionary) -> void:
	_log("assignment_commit_requested", payload)
	_ensure_services()
	if _room_service == null or _room_service.room_state == null:
		_log("assignment_commit_no_room_state", {})
		return
	var rs := _room_service.room_state
	var assignment_id := String(payload.get("assignment_id", ""))
	if assignment_id.is_empty():
		_log("assignment_commit_missing_assignment_id", payload)
		return
	# Matchmade rooms: DS is allocated by game_service during pairing. The
	# server_host/server_port in the payload already point at the real DS —
	# do NOT call manual-room/create from here (that would double-allocate).
	var server_host := String(payload.get("server_host", ""))
	var server_port := int(payload.get("server_port", 0))
	var battle_id := String(payload.get("battle_id", ""))
	var match_id := String(payload.get("match_id", ""))
	if server_host.is_empty() or server_port <= 0:
		_log("assignment_commit_missing_ds_endpoint", payload)
		_restore_room_after_alloc_failure("BATTLE_DS_NOT_READY")
		return
	freeze_for_battle(assignment_id, battle_id, "allocating_battle")
	rs.current_battle_id = battle_id
	rs.current_match_id = match_id
	rs.current_assignment_id = assignment_id
	# Propagate map/mode/rule from assignment to room state so snapshot carries them
	var assigned_map_id := String(payload.get("map_id", ""))
	var assigned_mode_id := String(payload.get("mode_id", ""))
	var assigned_rule_set_id := String(payload.get("rule_set_id", ""))
	if not assigned_map_id.is_empty():
		rs.selected_map_id = assigned_map_id
	if not assigned_mode_id.is_empty():
		rs.selected_mode_id = assigned_mode_id
	if not assigned_rule_set_id.is_empty():
		rs.selected_rule_id = assigned_rule_set_id
	set_battle_ready(server_host, server_port)
	_log("matchmade_battle_ready_set", {
		"assignment_id": assignment_id,
		"battle_id": battle_id,
		"match_id": match_id,
		"server_host": server_host,
		"server_port": server_port,
	})
	_broadcast_snapshot()


func _request_battle_ds_allocation(
	assignment_id: String,
	map_id: String,
	mode_id: String,
	rule_set_id: String,
	room_kind: String,
	members_array: Array[Dictionary]
) -> void:
	if _room_service == null or _room_service.room_state == null:
		return
	var rs := _room_service.room_state
	freeze_for_battle(assignment_id, "", "allocating_battle")
	_broadcast_snapshot()
	var request := {
		"source_room_id": rs.room_id,
		"source_room_kind": room_kind,
		"mode_id": mode_id,
		"rule_set_id": rule_set_id,
		"map_id": map_id,
		"expected_member_count": members_array.size(),
		"members": members_array,
		"host_hint": "",
	}
	_log("battle_ds_allocation_requested", request)
	if _battle_alloc_client == null:
		_log("battle_ds_alloc_no_client", {})
		_restore_room_after_alloc_failure("BATTLE_ALLOC_CLIENT_MISSING")
		return
	var result := _battle_alloc_client.request_manual_room_battle(request)
	_log("battle_ds_allocation_result", result)
	if not bool(result.get("ok", false)):
		_restore_room_after_alloc_failure(String(result.get("error_code", "ALLOCATION_FAILED")))
		return
	var battle_id := String(result.get("battle_id", ""))
	var match_id := String(result.get("match_id", ""))
	var server_host := String(result.get("server_host", ""))
	var server_port := int(result.get("server_port", 0))
	rs.current_battle_id = battle_id
	rs.current_match_id = match_id
	rs.current_assignment_id = assignment_id
	set_battle_ready(server_host, server_port)
	_log("battle_ready_set", {
		"battle_id": battle_id,
		"match_id": match_id,
		"server_host": server_host,
		"server_port": server_port,
	})
	_broadcast_snapshot()


func _build_members_array_from_room_state() -> Array[Dictionary]:
	var members_array: Array[Dictionary] = []
	if _room_service == null or _room_service.room_state == null:
		return members_array
	var rs := _room_service.room_state
	for binding in rs._get_sorted_member_bindings():
		if binding == null:
			continue
		members_array.append({
			"account_id": String(binding.account_id),
			"profile_id": String(binding.profile_id),
			"assigned_team_id": int(binding.team_id),
		})
	if members_array.is_empty():
		for peer_id in rs.get_sorted_peer_ids():
			var profile: Dictionary = rs.members.get(peer_id, {})
			members_array.append({
				"account_id": String(profile.get("account_id", "")),
				"profile_id": String(profile.get("profile_id", "")),
				"assigned_team_id": int(profile.get("team_id", 1)),
			})
	return members_array


func _restore_room_after_alloc_failure(error_code: String) -> void:
	_log("alloc_failure_restoring_room", {"error_code": error_code})
	if _room_service == null or _room_service.room_state == null:
		return
	var rs := _room_service.room_state
	rs.room_lifecycle_state = "idle"
	rs.current_assignment_id = ""
	rs.current_battle_id = ""
	rs.current_match_id = ""
	rs.battle_allocation_state = ""
	rs.battle_server_host = ""
	rs.battle_server_port = 0
	# 匹配房间：assigned → cancelled，让用户可以重新匹配
	# 自定义房间：room_queue_state 本来是 idle，保持不变
	if rs.room_queue_state == "assigned" or rs.room_queue_state == "queueing":
		rs.room_queue_state = "cancelled"
		rs.room_queue_entry_id = ""
		rs.room_queue_status_text = ""
	rs.room_queue_error_code = error_code
	rs.room_queue_error_message = "Battle allocation failed"
	_broadcast_snapshot()


func _broadcast_snapshot() -> void:
	if _room_service == null or _room_service.room_state == null:
		return
	var snapshot := _room_service.room_state.build_snapshot()
	broadcast_message.emit({
		"message_type": TransportMessageTypesScript.ROOM_SNAPSHOT,
		"snapshot": snapshot.to_dict(),
	})


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
	LogNetScript.debug("[room_authority_runtime] %s %s" % [event_name, JSON.stringify(payload)], "", 0, ROOM_AUTHORITY_LOG_TAG)


func _read_env(env_name: String, fallback: String) -> String:
	var value := OS.get_environment(env_name).strip_edges()
	return value if not value.is_empty() else fallback
