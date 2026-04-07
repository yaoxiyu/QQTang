extends Node

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const RoomFlowStateScript = preload("res://network/session/runtime/room_flow_state.gd")
const SessionLifecycleStateScript = preload("res://network/session/runtime/session_lifecycle_state.gd")
const RoomRuntimeContextScript = preload("res://network/session/runtime/room_runtime_context.gd")
signal room_snapshot_changed(snapshot: RoomSnapshot)
signal start_match_requested(snapshot: RoomSnapshot)
signal room_flow_state_changed(previous_state: int, new_state: int, reason: String)
signal session_lifecycle_state_changed(previous_state: int, new_state: int, reason: String)


var room_session: RoomSession = RoomSession.new()
var owner_peer_id: int = 0
var member_profiles: Dictionary = {}
var max_players: int = 8
var room_flow_state: int = RoomFlowStateScript.Value.NONE
var session_lifecycle_state: int = SessionLifecycleStateScript.Value.NONE
var room_runtime_context: RoomRuntimeContext = RoomRuntimeContextScript.new()
var completed_match_count: int = 0
var last_completed_match_id: String = ""


func configure(session: RoomSession) -> void:
	room_session = session if session != null else RoomSession.new()
	owner_peer_id = room_session.peers[0] if not room_session.peers.is_empty() else 0
	set_room_flow_state(RoomFlowStateScript.Value.ENTERING, "configure")
	if room_session.peers.is_empty():
		set_room_flow_state(RoomFlowStateScript.Value.IDLE, "configure_without_members")
		set_session_lifecycle_state(SessionLifecycleStateScript.Value.NONE, "configure_without_members")
	else:
		set_room_flow_state(RoomFlowStateScript.Value.IN_ROOM, "configure_with_existing_room")
		set_session_lifecycle_state(SessionLifecycleStateScript.Value.ROOM_ACTIVE, "configure_with_existing_room")
	_sync_runtime_context()
	_emit_snapshot_changed()


func build_room_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = room_session.room_id
	snapshot.room_kind = room_session.room_kind
	snapshot.topology = room_session.topology
	snapshot.selected_map_id = _resolve_map_id()
	snapshot.rule_set_id = _resolve_rule_set_id()
	snapshot.mode_id = _resolve_mode_id()
	snapshot.min_start_players = room_session.min_start_players
	snapshot.max_players = max_players
	snapshot.owner_peer_id = owner_peer_id
	snapshot.all_ready = _are_all_members_ready()

	var slot_map := room_session.build_peer_slots()
	for peer_id in room_session.peers:
		var member := RoomMemberState.new()
		var profile: Dictionary = member_profiles.get(peer_id, {})
		member.peer_id = peer_id
		member.player_name = String(profile.get("player_name", "Player%d" % peer_id))
		member.ready = bool(room_session.ready_state.get(peer_id, false))
		member.slot_index = int(slot_map.get(peer_id, -1))
		member.character_id = String(profile.get("character_id", ""))
		member.character_skin_id = String(profile.get("character_skin_id", ""))
		member.bubble_style_id = String(profile.get("bubble_style_id", ""))
		member.bubble_skin_id = String(profile.get("bubble_skin_id", ""))
		member.is_owner = peer_id == owner_peer_id
		member.is_local_player = peer_id == room_runtime_context.local_player_id
		member.connection_state = "local" if member.is_local_player and room_session.topology == "local" else "connected"
		snapshot.members.append(member)

	return snapshot



func create_room(owner_peer_id: int) -> void:
	set_room_flow_state(RoomFlowStateScript.Value.ENTERING, "create_room_requested")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.CREATING_ROOM, "create_room_requested")
	room_session = RoomSession.new("room_%d" % owner_peer_id)
	room_session.room_kind = "private_room"
	room_session.topology = "dedicated_server"
	room_session.min_start_players = 2
	self.owner_peer_id = owner_peer_id
	member_profiles.clear()
	room_session.add_peer(owner_peer_id)
	set_room_flow_state(RoomFlowStateScript.Value.HOSTING, "room_created")
	set_room_flow_state(RoomFlowStateScript.Value.IN_ROOM, "host_room_ready")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.ROOM_ACTIVE, "room_created")
	_sync_runtime_context()
	_emit_snapshot_changed()


func join_room(member_state: RoomMemberState) -> void:
	if member_state == null or not member_state.is_valid_member():
		return
	if room_session.peers.size() >= max_players:
		return

	set_room_flow_state(RoomFlowStateScript.Value.JOINING, "join_room_requested")
	room_session.add_peer(member_state.peer_id)
	room_session.set_ready(member_state.peer_id, member_state.ready)
	member_profiles[member_state.peer_id] = {
		"player_name": member_state.player_name,
		"character_id": member_state.character_id,
		"character_skin_id": member_state.character_skin_id,
		"bubble_style_id": member_state.bubble_style_id,
		"bubble_skin_id": member_state.bubble_skin_id,
	}
	set_room_flow_state(RoomFlowStateScript.Value.IN_ROOM, "join_room_completed")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.ROOM_ACTIVE, "join_room_completed")
	_sync_runtime_context()
	_emit_snapshot_changed()


func leave_room(peer_id: int) -> void:
	room_session.remove_peer(peer_id)
	member_profiles.erase(peer_id)
	if owner_peer_id == peer_id:
		_reassign_owner()
	_sync_runtime_context()
	_emit_snapshot_changed()


func reset_room_state() -> void:
	var preserved_local_player_id := room_runtime_context.local_player_id
	room_session = RoomSession.new()
	owner_peer_id = 0
	member_profiles.clear()
	max_players = 8
	completed_match_count = 0
	last_completed_match_id = ""
	room_runtime_context = RoomRuntimeContextScript.new()
	room_runtime_context.local_player_id = preserved_local_player_id
	set_room_flow_state(RoomFlowStateScript.Value.NONE, "reset_room_state")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.NONE, "reset_room_state")
	_sync_runtime_context()
	_emit_snapshot_changed()


func set_member_ready(peer_id: int, ready: bool) -> void:
	room_session.set_ready(peer_id, ready)
	_sync_runtime_context()
	_emit_snapshot_changed()


func can_start_match() -> bool:
	if room_session.peers.size() < room_session.min_start_players:
		return false
	if not MapCatalogScript.has_map(_resolve_map_id()):
		return false
	if not RuleSetCatalogScript.has_rule(_resolve_rule_set_id()):
		return false
	if not ModeCatalogScript.has_mode(_resolve_mode_id()):
		return false
	return _are_all_members_ready()


func can_request_start_match(requester_peer_id: int) -> bool:
	if requester_peer_id != owner_peer_id:
		return false
	return can_start_match()


func get_start_match_blocker(requester_peer_id: int) -> Dictionary:
	if not _can_interact_in_room():
		return {
			"error_code": "ROOM_START_FORBIDDEN",
			"user_message": "Room is not ready for this action",
		}
	if requester_peer_id != owner_peer_id:
		return {
			"error_code": "ROOM_START_FORBIDDEN",
			"user_message": "Only the host can start the match",
		}
	if room_session.peers.size() < room_session.min_start_players:
		return {
			"error_code": "ROOM_MEMBER_NOT_READY",
			"user_message": "At least %d player(s) are required to start" % room_session.min_start_players,
		}
	if not MapCatalogScript.has_map(_resolve_map_id()) or not RuleSetCatalogScript.has_rule(_resolve_rule_set_id()):
		return {
			"error_code": "ROOM_SELECTION_INVALID",
			"user_message": "Map or rule selection is invalid",
		}
	if not ModeCatalogScript.has_mode(_resolve_mode_id()):
		return {
			"error_code": "ROOM_SELECTION_INVALID",
			"user_message": "Mode selection is invalid",
		}
	if not _are_all_members_ready():
		return {
			"error_code": "ROOM_MEMBER_NOT_READY",
			"user_message": "All players must be ready before starting",
		}
	return {}


func request_toggle_ready(peer_id: int) -> Dictionary:
	if not _can_interact_in_room() or not room_session.peers.has(peer_id):
		return {
			"ok": false,
			"error_code": "ROOM_START_FORBIDDEN",
			"user_message": "Room is not ready for ready toggle",
		}
	var local_ready := bool(room_session.ready_state.get(peer_id, false))
	set_member_ready(peer_id, not local_ready)
	return {"ok": true}


func request_update_selection(requester_peer_id: int, map_id: String, rule_set_id: String, mode_id: String) -> Dictionary:
	if not _can_interact_in_room() or requester_peer_id == 0:
		return {
			"ok": false,
			"error_code": "ROOM_SELECTION_INVALID",
			"user_message": "Room is not ready for selection update",
		}
	if requester_peer_id != owner_peer_id:
		return {
			"ok": false,
			"error_code": "ROOM_START_FORBIDDEN",
			"user_message": "Only the host can change room selection",
		}
	if not MapCatalogScript.has_map(map_id) or not RuleSetCatalogScript.has_rule(rule_set_id) or not ModeCatalogScript.has_mode(mode_id):
		return {
			"ok": false,
			"error_code": "ROOM_SELECTION_INVALID",
			"user_message": "Map, rule, or mode selection is invalid",
		}
	var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
	var mode_rule_set_id := String(mode_metadata.get("rule_set_id", ""))
	if not mode_rule_set_id.is_empty() and mode_rule_set_id != rule_set_id:
		return {
			"ok": false,
			"error_code": "ROOM_SELECTION_INVALID",
			"user_message": "Mode does not match the selected rule set",
		}
	set_room_selection(map_id, rule_set_id, mode_id)
	return {"ok": true}


func request_update_member_profile(
	peer_id: int,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = ""
) -> Dictionary:
	if not _can_interact_in_room() or peer_id == 0 or not room_session.peers.has(peer_id):
		return {
			"ok": false,
			"error_code": "ROOM_MEMBER_PROFILE_INVALID",
			"user_message": "Room is not ready for profile update",
		}
	var trimmed_character_id := character_id.strip_edges()
	if trimmed_character_id.is_empty() or not CharacterCatalogScript.has_character(trimmed_character_id):
		return {
			"ok": false,
			"error_code": "ROOM_MEMBER_PROFILE_INVALID",
			"user_message": "Character selection is invalid",
		}
	var profile: Dictionary = member_profiles.get(peer_id, {})
	profile["player_name"] = player_name if not player_name.strip_edges().is_empty() else "Player%d" % peer_id
	profile["character_id"] = trimmed_character_id
	profile["character_skin_id"] = character_skin_id.strip_edges()
	profile["bubble_style_id"] = bubble_style_id
	profile["bubble_skin_id"] = bubble_skin_id.strip_edges()
	member_profiles[peer_id] = profile
	_emit_snapshot_changed()
	return {"ok": true}


func apply_authoritative_snapshot(snapshot: RoomSnapshot) -> void:
	if snapshot == null:
		return
	room_session = RoomSession.new(snapshot.room_id)
	room_session.room_kind = snapshot.room_kind
	room_session.topology = snapshot.topology
	room_session.min_start_players = snapshot.min_start_players
	owner_peer_id = snapshot.owner_peer_id
	max_players = snapshot.max_players
	member_profiles.clear()
	for member in snapshot.sorted_members():
		room_session.add_peer(member.peer_id)
		room_session.set_ready(member.peer_id, member.ready)
		member_profiles[member.peer_id] = {
			"player_name": member.player_name,
			"character_id": member.character_id,
			"character_skin_id": member.character_skin_id,
			"bubble_style_id": member.bubble_style_id,
			"bubble_skin_id": member.bubble_skin_id,
		}
	room_session.set_selection(snapshot.selected_map_id, snapshot.rule_set_id, snapshot.mode_id)
	set_room_flow_state(RoomFlowStateScript.Value.IN_ROOM, "authoritative_snapshot")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.ROOM_ACTIVE, "authoritative_snapshot")
	_sync_runtime_context()
	_emit_snapshot_changed()


func request_begin_match(requester_peer_id: int) -> Dictionary:
	var blocker := get_start_match_blocker(requester_peer_id)
	if not blocker.is_empty():
		blocker["ok"] = false
		return blocker
	request_start_match(requester_peer_id)
	return {"ok": true, "snapshot": build_room_snapshot().to_dict()}


func request_start_match(requester_peer_id: int) -> void:
	if not can_request_start_match(requester_peer_id):
		return
	set_room_flow_state(RoomFlowStateScript.Value.PREPARING_MATCH, "start_match_requested")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.MATCH_NEGOTIATING, "start_match_requested")
	set_room_flow_state(RoomFlowStateScript.Value.STARTING_MATCH, "start_match_emitted")
	room_runtime_context.pending_match_id = "%s_pending" % room_session.room_id if not room_session.room_id.is_empty() else "pending_match"
	_sync_runtime_context()
	start_match_requested.emit(build_room_snapshot())


func set_room_selection(map_id: String, rule_set_id: String, mode_id: String) -> void:
	room_session.set_selection(
		map_id if not map_id.is_empty() else MapCatalogScript.get_default_map_id(),
		rule_set_id if not rule_set_id.is_empty() else RuleSetCatalogScript.get_default_rule_id(),
		mode_id if not mode_id.is_empty() else ModeCatalogScript.get_default_mode_id()
	)
	_sync_runtime_context()
	_emit_snapshot_changed()


func configure_practice_room(
	local_profile_state,
	map_id: String,
	rule_id: String,
	mode_id: String,
	local_peer_id: int
) -> void:
	set_room_flow_state(RoomFlowStateScript.Value.ENTERING, "configure_practice_room_requested")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.CREATING_ROOM, "configure_practice_room_requested")
	room_session = RoomSession.new("practice")
	room_session.room_kind = "practice"
	room_session.topology = "local"
	room_session.min_start_players = 1
	max_players = 1
	owner_peer_id = local_peer_id
	member_profiles.clear()
	room_session.add_peer(local_peer_id)
	room_session.set_ready(local_peer_id, true)
	member_profiles[local_peer_id] = {
		"player_name": String(local_profile_state.nickname if local_profile_state != null else "Player%d" % local_peer_id),
		"character_id": String(local_profile_state.default_character_id if local_profile_state != null else ""),
		"character_skin_id": String(local_profile_state.default_character_skin_id if local_profile_state != null else ""),
		"bubble_style_id": String(local_profile_state.default_bubble_style_id if local_profile_state != null else ""),
		"bubble_skin_id": String(local_profile_state.default_bubble_skin_id if local_profile_state != null else ""),
	}
	set_room_selection(map_id, rule_id, mode_id)
	set_room_flow_state(RoomFlowStateScript.Value.IN_ROOM, "practice_room_configured")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.ROOM_ACTIVE, "practice_room_configured")
	_sync_runtime_context()
	_emit_snapshot_changed()


func debug_dump_room() -> Dictionary:
	return {
		"snapshot": build_room_snapshot().to_dict(),
		"runtime_context": room_runtime_context.to_dict(),
		"completed_match_count": completed_match_count,
		"last_completed_match_id": last_completed_match_id,
	}


func reset_ready_state() -> void:
	for peer_id in room_session.peers:
		room_session.set_ready(peer_id, false)
	room_runtime_context.pending_match_id = ""
	_sync_runtime_context()
	_emit_snapshot_changed()


func set_room_flow_state(new_state: int, reason: String = "") -> void:
	if room_flow_state == new_state:
		return
	var previous_state := room_flow_state
	room_flow_state = new_state
	room_runtime_context.room_flow_state = new_state
	print(
		"[RoomFlowState] %s -> %s (%s)" % [
			RoomFlowStateScript.state_to_string(previous_state),
			RoomFlowStateScript.state_to_string(new_state),
			reason
		]
	)
	room_flow_state_changed.emit(previous_state, new_state, reason)


func set_session_lifecycle_state(new_state: int, reason: String = "") -> void:
	if session_lifecycle_state == new_state:
		return
	var previous_state := session_lifecycle_state
	session_lifecycle_state = new_state
	room_runtime_context.session_lifecycle_state = new_state
	print(
		"[SessionLifecycleState] %s -> %s (%s)" % [
			SessionLifecycleStateScript.state_to_string(previous_state),
			SessionLifecycleStateScript.state_to_string(new_state),
			reason
		]
	)
	session_lifecycle_state_changed.emit(previous_state, new_state, reason)


func get_room_flow_state_name() -> String:
	return RoomFlowStateScript.state_to_string(room_flow_state)


func get_session_lifecycle_state_name() -> String:
	return SessionLifecycleStateScript.state_to_string(session_lifecycle_state)


func set_local_player_id(peer_id: int) -> void:
	room_runtime_context.local_player_id = peer_id
	_sync_runtime_context()


func set_pending_match_id(match_id: String) -> void:
	room_runtime_context.pending_match_id = match_id


func mark_match_started(match_id: String = "") -> void:
	if not match_id.is_empty():
		room_runtime_context.pending_match_id = match_id
	set_room_flow_state(RoomFlowStateScript.Value.IN_BATTLE, "match_started")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.MATCH_ACTIVE, "match_started")
	_sync_runtime_context()


func mark_match_finished(match_id: String = "") -> void:
	completed_match_count += 1
	last_completed_match_id = match_id
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.MATCH_ENDING, "match_finished")
	_sync_runtime_context()


func begin_return_to_room() -> void:
	set_room_flow_state(RoomFlowStateScript.Value.RETURNING_FROM_BATTLE, "return_to_room_requested")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.RECOVERING_ROOM, "return_to_room_requested")
	_sync_runtime_context()


func complete_return_to_room() -> void:
	room_runtime_context.pending_match_id = ""
	clear_last_error()
	set_room_flow_state(RoomFlowStateScript.Value.IN_ROOM, "return_to_room_completed")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.ROOM_ACTIVE, "return_to_room_completed")
	_sync_runtime_context()


func set_last_error(error_code: String, error_message: String, details: Dictionary = {}) -> void:
	room_runtime_context.last_error = {
		"error_code": error_code,
		"error_message": error_message,
		"details": details.duplicate(true),
	}
	_emit_snapshot_changed()


func clear_last_error() -> void:
	room_runtime_context.last_error = {}
	_emit_snapshot_changed()


func _emit_snapshot_changed() -> void:
	_sync_runtime_context()
	room_snapshot_changed.emit(build_room_snapshot())


func _sync_runtime_context() -> void:
	if room_runtime_context == null:
		room_runtime_context = RoomRuntimeContextScript.new()
	room_runtime_context.room_id = room_session.room_id
	room_runtime_context.room_flow_state = room_flow_state
	room_runtime_context.session_lifecycle_state = session_lifecycle_state
	room_runtime_context.members = room_session.peers.duplicate()
	room_runtime_context.ready_map = room_session.ready_state.duplicate(true)
	room_runtime_context.room_kind = room_session.room_kind
	room_runtime_context.topology = room_session.topology
	room_runtime_context.selected_map_id = _resolve_map_id()
	room_runtime_context.selected_rule_set_id = _resolve_rule_set_id()
	room_runtime_context.mode_id = _resolve_mode_id()
	room_runtime_context.min_start_players = room_session.min_start_players
	room_runtime_context.host_player_id = owner_peer_id
	room_runtime_context.is_host = room_runtime_context.local_player_id != 0 and room_runtime_context.local_player_id == owner_peer_id


func _resolve_map_id() -> String:
	return room_session.selected_map_id if not room_session.selected_map_id.is_empty() else MapCatalogScript.get_default_map_id()


func _resolve_rule_set_id() -> String:
	return room_session.selected_rule_set_id if not room_session.selected_rule_set_id.is_empty() else RuleSetCatalogScript.get_default_rule_id()


func _resolve_mode_id() -> String:
	return room_session.selected_mode_id if not room_session.selected_mode_id.is_empty() else ModeCatalogScript.get_default_mode_id()


func _are_all_members_ready() -> bool:
	if room_session.peers.size() < room_session.min_start_players:
		return false

	for peer_id in room_session.peers:
		if not bool(room_session.ready_state.get(peer_id, false)):
			return false
	return true


func _can_interact_in_room() -> bool:
	return room_flow_state == RoomFlowStateScript.Value.IN_ROOM and session_lifecycle_state == SessionLifecycleStateScript.Value.ROOM_ACTIVE


func _reassign_owner() -> void:
	owner_peer_id = room_session.peers[0] if not room_session.peers.is_empty() else 0
