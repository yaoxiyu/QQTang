extends Node

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const RoomFlowStateScript = preload("res://network/session/runtime/room_flow_state.gd")
const SessionLifecycleStateScript = preload("res://network/session/runtime/session_lifecycle_state.gd")
const RoomRuntimeContextScript = preload("res://network/session/runtime/room_runtime_context.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const ROOM_SESSION_LOG_PREFIX := "[QQT_ROOM_SESSION]"
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
	snapshot.queue_type = room_session.queue_type
	snapshot.match_format_id = room_session.match_format_id
	snapshot.selected_match_mode_ids = room_session.selected_match_mode_ids.duplicate()
	snapshot.required_party_size = room_session.required_party_size
	snapshot.room_queue_state = room_session.room_queue_state
	snapshot.room_queue_entry_id = room_session.room_queue_entry_id
	snapshot.room_queue_status_text = room_session.room_queue_status_text
	snapshot.room_queue_error_code = room_session.room_queue_error_code
	snapshot.room_queue_error_message = room_session.room_queue_error_message
	snapshot.min_start_players = room_session.min_start_players
	snapshot.max_players = max_players
	snapshot.owner_peer_id = owner_peer_id
	snapshot.all_ready = _are_all_members_ready()
	snapshot.match_active = room_session.match_active
	# LegacyMigration: Battle handoff fields
	snapshot.room_lifecycle_state = room_session.room_lifecycle_state
	snapshot.room_phase = room_session.room_phase
	snapshot.room_phase_reason = room_session.room_phase_reason
	snapshot.current_assignment_id = room_session.current_assignment_id
	snapshot.current_battle_id = room_session.current_battle_id
	snapshot.current_match_id = room_session.current_match_id
	snapshot.queue_phase = room_session.queue_phase
	snapshot.queue_terminal_reason = room_session.queue_terminal_reason
	snapshot.queue_status_text = room_session.room_queue_status_text
	snapshot.queue_error_code = room_session.room_queue_error_code
	snapshot.queue_user_message = room_session.room_queue_error_message
	snapshot.queue_entry_id = room_session.room_queue_entry_id
	snapshot.battle_allocation_state = room_session.battle_allocation_state
	snapshot.battle_phase = room_session.battle_phase
	snapshot.battle_terminal_reason = room_session.battle_terminal_reason
	snapshot.battle_status_text = room_session.battle_status_text
	snapshot.battle_server_host = room_session.battle_server_host
	snapshot.battle_server_port = room_session.battle_server_port
	snapshot.room_return_policy = room_session.room_return_policy
	snapshot.battle_entry_ready = room_session.battle_allocation_state == "battle_ready"
	snapshot.can_toggle_ready = room_session.can_toggle_ready
	snapshot.can_start_manual_battle = room_session.can_start_manual_battle
	snapshot.can_update_selection = room_session.can_update_selection
	snapshot.can_update_match_room_config = room_session.can_update_match_room_config
	snapshot.can_enter_queue = room_session.can_enter_queue
	snapshot.can_cancel_queue = room_session.can_cancel_queue
	snapshot.can_leave_room = room_session.can_leave_room

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
		member.team_id = int(profile.get("team_id", member.slot_index + 1))
		member.member_phase = String(profile.get("member_phase", "ready" if member.ready else "idle"))
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
	self.owner_peer_id = owner_peer_id
	member_profiles.clear()
	room_session.add_peer(owner_peer_id)
	set_room_selection("", "", "")
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
		"team_id": member_state.team_id,
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
	var binding := _resolve_map_binding(_resolve_map_id())
	if binding.is_empty():
		return false
	var required_team_count := int(binding.get("required_team_count", room_session.min_start_players))
	var max_player_count := int(binding.get("max_player_count", max_players))
	if room_session.peers.size() < room_session.min_start_players:
		return false
	if max_player_count > 0 and room_session.peers.size() > max_player_count:
		return false
	if _collect_distinct_team_ids().size() < required_team_count:
		return false
	if not MapCatalogScript.has_map(_resolve_map_id()):
		return false
	if not RuleSetCatalogScript.has_rule(_resolve_rule_set_id()):
		return false
	if not ModeCatalogScript.has_mode(_resolve_mode_id()):
		return false
	return _are_all_members_ready()


func can_request_start_match(requester_peer_id: int) -> bool:
	var effective_peer_id := _resolve_effective_requester_peer_id(requester_peer_id)
	if effective_peer_id != owner_peer_id:
		return false
	return can_start_match()


func get_start_match_blocker(requester_peer_id: int) -> Dictionary:
	var effective_peer_id := _resolve_effective_requester_peer_id(requester_peer_id)
	if not _can_interact_in_room():
		return {
			"error_code": "ROOM_START_FORBIDDEN",
			"user_message": "Room is not ready for this action",
		}
	if effective_peer_id != owner_peer_id:
		return {
			"error_code": "ROOM_START_FORBIDDEN",
			"user_message": "Only the host can start the match",
		}
	var binding := _resolve_map_binding(_resolve_map_id())
	if binding.is_empty():
		return {
			"error_code": "ROOM_SELECTION_INVALID",
			"user_message": "Selection is incomplete",
		}
	var required_team_count := int(binding.get("required_team_count", room_session.min_start_players))
	var max_player_count := int(binding.get("max_player_count", max_players))
	if room_session.peers.size() < room_session.min_start_players:
		return {
			"error_code": "ROOM_MEMBER_NOT_READY",
			"user_message": "At least %d player(s) are required to start" % room_session.min_start_players,
		}
	if max_player_count > 0 and room_session.peers.size() > max_player_count:
		return {
			"error_code": "ROOM_CAPACITY_EXCEEDED",
			"user_message": "Room is over capacity",
		}
	if _collect_distinct_team_ids().size() < required_team_count:
		return {
			"error_code": "ROOM_TEAM_INVALID",
			"user_message": "Need at least %d teams" % required_team_count,
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
	var effective_peer_id := _resolve_effective_requester_peer_id(peer_id)
	if not _can_interact_in_room() or not room_session.peers.has(effective_peer_id):
		return {
			"ok": false,
			"error_code": "ROOM_START_FORBIDDEN",
			"user_message": "Room is not ready for ready toggle",
		}
	var local_ready := bool(room_session.ready_state.get(effective_peer_id, false))
	set_member_ready(effective_peer_id, not local_ready)
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
	var binding := _resolve_map_binding(map_id)
	if binding.is_empty():
		_log_room_session("selection_update_rejected_invalid_binding", {
			"requester_peer_id": requester_peer_id,
			"requested_map_id": map_id,
			"requested_rule_set_id": rule_set_id,
			"requested_mode_id": mode_id,
		})
		return {
			"ok": false,
			"error_code": "ROOM_SELECTION_INVALID",
			"user_message": "Map selection is invalid",
		}
	set_room_selection(
		String(binding.get("map_id", map_id)),
		String(binding.get("bound_rule_set_id", rule_set_id)),
		String(binding.get("bound_mode_id", mode_id))
	)
	return {"ok": true}


func request_update_member_profile(
	peer_id: int,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = "",
	team_id: int = 1
) -> Dictionary:
	var effective_peer_id := _resolve_effective_requester_peer_id(peer_id)
	if not _can_interact_in_room() or effective_peer_id == 0 or not room_session.peers.has(effective_peer_id):
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
	var current_profile: Dictionary = member_profiles.get(effective_peer_id, {})
	var current_team_id := int(current_profile.get("team_id", _resolve_member_slot_index(effective_peer_id) + 1))
	if bool(room_session.ready_state.get(effective_peer_id, false)) and team_id != current_team_id:
		return {
			"ok": false,
			"error_code": "ROOM_MEMBER_PROFILE_FORBIDDEN",
			"user_message": "Team cannot be changed after ready",
		}
	var profile: Dictionary = member_profiles.get(effective_peer_id, {})
	profile["player_name"] = player_name if not player_name.strip_edges().is_empty() else "Player%d" % effective_peer_id
	profile["character_id"] = trimmed_character_id
	profile["character_skin_id"] = character_skin_id.strip_edges()
	profile["bubble_style_id"] = bubble_style_id
	profile["bubble_skin_id"] = bubble_skin_id.strip_edges()
	profile["team_id"] = team_id
	member_profiles[effective_peer_id] = profile
	_emit_snapshot_changed()
	return {"ok": true}


func _resolve_effective_requester_peer_id(requested_peer_id: int) -> int:
	if requested_peer_id > 0 and room_session != null and room_session.peers.has(requested_peer_id):
		return requested_peer_id
	var local_peer_id := int(room_runtime_context.local_player_id) if room_runtime_context != null else 0
	if local_peer_id > 0 and room_session != null and room_session.peers.has(local_peer_id):
		return local_peer_id
	if room_session != null and room_session.peers.size() == 1:
		return int(room_session.peers[0])
	return requested_peer_id


func apply_authoritative_snapshot(snapshot: RoomSnapshot) -> void:
	if snapshot == null:
		return
	var previous_room_flow_state := room_flow_state
	var previous_session_lifecycle_state := session_lifecycle_state
	room_session = RoomSession.new(snapshot.room_id)
	room_session.room_kind = snapshot.room_kind
	room_session.topology = snapshot.topology
	room_session.min_start_players = snapshot.min_start_players
	room_session.queue_type = snapshot.queue_type
	room_session.match_format_id = snapshot.match_format_id
	room_session.selected_match_mode_ids = snapshot.selected_match_mode_ids.duplicate()
	room_session.required_party_size = snapshot.required_party_size
	room_session.room_queue_state = snapshot.room_queue_state
	room_session.room_queue_entry_id = snapshot.room_queue_entry_id
	room_session.room_queue_status_text = snapshot.room_queue_status_text
	room_session.room_queue_error_code = snapshot.room_queue_error_code
	room_session.room_queue_error_message = snapshot.room_queue_error_message
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
			"team_id": member.team_id,
			"member_phase": member.member_phase,
		}
	room_session.set_selection(snapshot.selected_map_id, snapshot.rule_set_id, snapshot.mode_id)
	# LegacyMigration: For matchmade rooms with an assignment, the server overrides
	# map/mode/rule via the assignment payload. set_selection blanks them for
	# match rooms, so re-apply the snapshot values when an assignment exists.
	if not snapshot.current_assignment_id.is_empty():
		if not snapshot.selected_map_id.is_empty():
			room_session.selected_map_id = snapshot.selected_map_id
		if not snapshot.mode_id.is_empty():
			room_session.selected_mode_id = snapshot.mode_id
		if not snapshot.rule_set_id.is_empty():
			room_session.selected_rule_set_id = snapshot.rule_set_id
	# LegacyMigration: Battle handoff fields
	room_session.room_lifecycle_state = snapshot.room_lifecycle_state
	room_session.room_phase = snapshot.room_phase
	room_session.room_phase_reason = snapshot.room_phase_reason
	room_session.current_assignment_id = snapshot.current_assignment_id
	room_session.current_battle_id = snapshot.current_battle_id
	room_session.current_match_id = snapshot.current_match_id
	room_session.queue_phase = snapshot.queue_phase
	room_session.queue_terminal_reason = snapshot.queue_terminal_reason
	room_session.battle_allocation_state = snapshot.battle_allocation_state
	room_session.battle_phase = snapshot.battle_phase
	room_session.battle_terminal_reason = snapshot.battle_terminal_reason
	room_session.battle_status_text = snapshot.battle_status_text
	if room_session.battle_allocation_state.strip_edges().is_empty() and snapshot.battle_entry_ready:
		room_session.battle_allocation_state = "battle_ready"
	room_session.battle_server_host = snapshot.battle_server_host
	room_session.battle_server_port = snapshot.battle_server_port
	room_session.room_return_policy = snapshot.room_return_policy
	room_session.match_active = snapshot.match_active
	room_session.can_toggle_ready = snapshot.can_toggle_ready
	room_session.can_start_manual_battle = snapshot.can_start_manual_battle
	room_session.can_update_selection = snapshot.can_update_selection
	room_session.can_update_match_room_config = snapshot.can_update_match_room_config
	room_session.can_enter_queue = snapshot.can_enter_queue
	room_session.can_cancel_queue = snapshot.can_cancel_queue
	room_session.can_leave_room = snapshot.can_leave_room
	var mapped_room_flow_state := _map_room_phase_to_room_flow_state(snapshot.room_phase)
	var mapped_session_lifecycle_state := _map_room_phase_to_session_lifecycle_state(snapshot.room_phase)
	if _should_preserve_active_battle_for_snapshot(
		snapshot,
		previous_room_flow_state,
		previous_session_lifecycle_state,
		mapped_room_flow_state,
		mapped_session_lifecycle_state
	):
		room_session.match_active = true
		if room_session.room_phase.strip_edges().is_empty() or room_session.room_phase == "idle":
			room_session.room_phase = "in_battle"
		if room_session.battle_phase.strip_edges().is_empty():
			room_session.battle_phase = "active"
		set_room_flow_state(previous_room_flow_state, "authoritative_snapshot_preserve_active_battle")
		set_session_lifecycle_state(previous_session_lifecycle_state, "authoritative_snapshot_preserve_active_battle")
		_log_room_session("ignored_stale_battle_idle_snapshot", {
			"room_id": String(snapshot.room_id),
			"room_phase": String(snapshot.room_phase),
			"battle_phase": String(snapshot.battle_phase),
			"match_active": bool(snapshot.match_active),
			"previous_room_flow_state": RoomFlowStateScript.state_to_string(previous_room_flow_state),
			"previous_session_lifecycle_state": SessionLifecycleStateScript.state_to_string(previous_session_lifecycle_state),
		})
	else:
		set_room_flow_state(mapped_room_flow_state, "authoritative_snapshot")
		set_session_lifecycle_state(mapped_session_lifecycle_state, "authoritative_snapshot")
	room_runtime_context.last_error = {}
	_sync_runtime_context()
	_emit_snapshot_changed()


func request_begin_match(requester_peer_id: int) -> Dictionary:
	var blocker := get_start_match_blocker(requester_peer_id)
	if not blocker.is_empty():
		blocker["ok"] = false
		_log_room_session("start_match_blocked", {
			"requester_peer_id": requester_peer_id,
			"error_code": String(blocker.get("error_code", "")),
			"user_message": String(blocker.get("user_message", "")),
			"map_id": _resolve_map_id(),
			"rule_set_id": _resolve_rule_set_id(),
			"mode_id": _resolve_mode_id(),
			"member_count": room_session.peers.size() if room_session != null else 0,
			"team_count": _collect_distinct_team_ids().size(),
			"min_start_players": room_session.min_start_players if room_session != null else 0,
			"max_players": max_players,
		})
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
	var old_map_id := _resolve_map_id()
	var resolved_map_id := _resolve_custom_room_map_id(map_id)
	var binding := _resolve_map_binding(resolved_map_id)
	var resolved_rule_set_id := String(binding.get("bound_rule_set_id", rule_set_id if not rule_set_id.is_empty() else RuleSetCatalogScript.get_default_rule_id()))
	var resolved_mode_id := String(binding.get("bound_mode_id", mode_id if not mode_id.is_empty() else ModeCatalogScript.get_default_mode_id()))
	room_session.set_selection(resolved_map_id, resolved_rule_set_id, resolved_mode_id)
	if not binding.is_empty():
		room_session.min_start_players = int(binding.get("required_team_count", room_session.min_start_players))
		max_players = int(binding.get("max_player_count", max_players))
	_log_room_session("room_selection_resolved", {
		"old_map_id": old_map_id,
		"new_map_id": resolved_map_id,
		"derived_rule_set_id": resolved_rule_set_id,
		"derived_mode_id": resolved_mode_id,
		"required_team_count": room_session.min_start_players,
		"max_player_count": max_players,
		"binding_valid": not binding.is_empty(),
		"room_kind": String(room_session.room_kind) if room_session != null else "",
	})
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
		"team_id": 1,
	}
	set_room_selection(map_id, rule_id, mode_id)
	room_session.min_start_players = 1
	max_players = 1
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


const LogSessionScript = preload("res://app/logging/log_session.gd")

func set_room_flow_state(new_state: int, reason: String = "") -> void:
	if room_flow_state == new_state:
		return
	var previous_state := room_flow_state
	room_flow_state = new_state
	room_runtime_context.room_flow_state = new_state
	LogSessionScript.info(
		"%s -> %s (%s)" % [
			RoomFlowStateScript.state_to_string(previous_state),
			RoomFlowStateScript.state_to_string(new_state),
			reason
		],
		"",
		0,
		"session.room_flow_state"
	)
	room_flow_state_changed.emit(previous_state, new_state, reason)


func set_session_lifecycle_state(new_state: int, reason: String = "") -> void:
	if session_lifecycle_state == new_state:
		return
	var previous_state := session_lifecycle_state
	session_lifecycle_state = new_state
	room_runtime_context.session_lifecycle_state = new_state
	LogSessionScript.info(
		"%s -> %s (%s)" % [
			SessionLifecycleStateScript.state_to_string(previous_state),
			SessionLifecycleStateScript.state_to_string(new_state),
			reason
		],
		"",
		0,
		"session.lifecycle_state"
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
	room_runtime_context.loading_phase = "committed"
	room_runtime_context.loading_ready_peers = room_session.peers.duplicate()
	room_runtime_context.loading_expected_peers = room_session.peers.duplicate()
	set_room_flow_state(RoomFlowStateScript.Value.IN_BATTLE, "match_started")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.MATCH_ACTIVE, "match_started")
	_sync_runtime_context()


func mark_match_finished(match_id: String = "") -> void:
	completed_match_count += 1
	last_completed_match_id = match_id
	room_runtime_context.loading_phase = ""
	room_runtime_context.loading_ready_peers = []
	room_runtime_context.loading_expected_peers = []
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.MATCH_ENDING, "match_finished")
	_sync_runtime_context()


func begin_return_to_room() -> void:
	set_room_flow_state(RoomFlowStateScript.Value.RETURNING_FROM_BATTLE, "return_to_room_requested")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.RECOVERING_ROOM, "return_to_room_requested")
	_sync_runtime_context()


func complete_return_to_room() -> void:
	room_runtime_context.pending_match_id = ""
	clear_last_error()
	room_runtime_context.loading_phase = ""
	room_runtime_context.loading_ready_peers = []
	room_runtime_context.loading_expected_peers = []
	set_room_flow_state(RoomFlowStateScript.Value.IN_ROOM, "return_to_room_completed")
	set_session_lifecycle_state(SessionLifecycleStateScript.Value.ROOM_ACTIVE, "return_to_room_completed")
	_sync_runtime_context()


func set_loading_state(phase: String, ready_peer_ids: Array[int], expected_peer_ids: Array[int], reason: String = "") -> void:
	room_runtime_context.loading_phase = phase
	room_runtime_context.loading_ready_peers = ready_peer_ids.duplicate()
	room_runtime_context.loading_expected_peers = expected_peer_ids.duplicate()
	if phase == "waiting":
		set_room_flow_state(RoomFlowStateScript.Value.MATCH_LOADING, reason if not reason.is_empty() else "loading_waiting")
		set_session_lifecycle_state(SessionLifecycleStateScript.Value.MATCH_LOADING, reason if not reason.is_empty() else "loading_waiting")
	elif phase == "aborted":
		set_room_flow_state(RoomFlowStateScript.Value.IN_ROOM, reason if not reason.is_empty() else "loading_aborted")
		set_session_lifecycle_state(SessionLifecycleStateScript.Value.ROOM_ACTIVE, reason if not reason.is_empty() else "loading_aborted")
	_sync_runtime_context()


func clear_loading_state() -> void:
	room_runtime_context.loading_phase = ""
	room_runtime_context.loading_ready_peers = []
	room_runtime_context.loading_expected_peers = []
	_sync_runtime_context()


func set_pending_room_action(action: String) -> void:
	room_runtime_context.pending_room_action = action
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
	room_runtime_context.queue_type = room_session.queue_type
	room_runtime_context.match_format_id = room_session.match_format_id
	room_runtime_context.selected_match_mode_ids = room_session.selected_match_mode_ids.duplicate()
	room_runtime_context.required_party_size = room_session.required_party_size
	room_runtime_context.room_queue_state = room_session.room_queue_state
	room_runtime_context.room_queue_entry_id = room_session.room_queue_entry_id
	room_runtime_context.room_queue_status_text = room_session.room_queue_status_text
	room_runtime_context.room_queue_error_code = room_session.room_queue_error_code
	room_runtime_context.room_queue_error_message = room_session.room_queue_error_message
	room_runtime_context.min_start_players = room_session.min_start_players
	room_runtime_context.host_player_id = owner_peer_id
	room_runtime_context.is_host = room_runtime_context.local_player_id != 0 and room_runtime_context.local_player_id == owner_peer_id


func _resolve_map_id() -> String:
	if room_session != null and (room_session.room_kind == "casual_match_room" or room_session.room_kind == "ranked_match_room"):
		# Match rooms with an assignment have a server-assigned map
		if not room_session.current_assignment_id.is_empty() and not room_session.selected_map_id.is_empty():
			return room_session.selected_map_id
		return ""
	return room_session.selected_map_id if not room_session.selected_map_id.is_empty() else MapCatalogScript.get_default_map_id()


func _resolve_rule_set_id() -> String:
	if room_session != null and (room_session.room_kind == "casual_match_room" or room_session.room_kind == "ranked_match_room"):
		if not room_session.current_assignment_id.is_empty() and not room_session.selected_rule_set_id.is_empty():
			return room_session.selected_rule_set_id
		return ""
	return room_session.selected_rule_set_id if not room_session.selected_rule_set_id.is_empty() else RuleSetCatalogScript.get_default_rule_id()


func _resolve_mode_id() -> String:
	if room_session != null and (room_session.room_kind == "casual_match_room" or room_session.room_kind == "ranked_match_room"):
		if not room_session.current_assignment_id.is_empty() and not room_session.selected_mode_id.is_empty():
			return room_session.selected_mode_id
		return ""
	return room_session.selected_mode_id if not room_session.selected_mode_id.is_empty() else ModeCatalogScript.get_default_mode_id()


func _are_all_members_ready() -> bool:
	if room_session.peers.is_empty():
		return false

	for peer_id in room_session.peers:
		if not bool(room_session.ready_state.get(peer_id, false)):
			return false
	return true


func _collect_distinct_team_ids() -> Array[int]:
	var team_ids: Array[int] = []
	var slot_map := room_session.build_peer_slots()
	for peer_id in room_session.peers:
		var profile: Dictionary = member_profiles.get(peer_id, {})
		var team_id := int(profile.get("team_id", int(slot_map.get(peer_id, 0)) + 1))
		if team_id < 1:
			continue
		if not team_ids.has(team_id):
			team_ids.append(team_id)
	team_ids.sort()
	return team_ids


func _resolve_member_slot_index(peer_id: int) -> int:
	var slot_map := room_session.build_peer_slots()
	return int(slot_map.get(peer_id, 0))


func _can_interact_in_room() -> bool:
	return room_flow_state == RoomFlowStateScript.Value.IN_ROOM and session_lifecycle_state == SessionLifecycleStateScript.Value.ROOM_ACTIVE


func _reassign_owner() -> void:
	owner_peer_id = room_session.peers[0] if not room_session.peers.is_empty() else 0


func _resolve_custom_room_map_id(preferred_map_id: String) -> String:
	if room_session != null and room_session.room_kind == "matchmade_room":
		return preferred_map_id if not preferred_map_id.is_empty() else MapCatalogScript.get_default_map_id()
	var resolved_map_id := MapSelectionCatalogScript.get_default_custom_room_map_id(preferred_map_id)
	if not resolved_map_id.is_empty():
		return resolved_map_id
	return preferred_map_id if not preferred_map_id.is_empty() else MapCatalogScript.get_default_map_id()


func _resolve_map_binding(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	if binding.is_empty() or not bool(binding.get("valid", false)):
		return {}
	return binding


func _log_room_session(event_name: String, payload: Dictionary) -> void:
	LogNetScript.debug("%s[room_session_controller] %s %s" % [ROOM_SESSION_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "net.room_session.controller")


func _map_room_phase_to_room_flow_state(room_phase: String) -> int:
	match room_phase.strip_edges():
		"idle", "":
			return RoomFlowStateScript.Value.IN_ROOM
		"battle_entry_ready", "battle_entering":
			return RoomFlowStateScript.Value.MATCH_LOADING
		"in_battle":
			return RoomFlowStateScript.Value.IN_BATTLE
		"returning_to_room":
			return RoomFlowStateScript.Value.RETURNING_FROM_BATTLE
		_:
			return RoomFlowStateScript.Value.IN_ROOM


func _map_room_phase_to_session_lifecycle_state(room_phase: String) -> int:
	match room_phase.strip_edges():
		"idle", "":
			return SessionLifecycleStateScript.Value.ROOM_ACTIVE
		"battle_entry_ready", "battle_entering":
			return SessionLifecycleStateScript.Value.MATCH_LOADING
		"in_battle":
			return SessionLifecycleStateScript.Value.MATCH_ACTIVE
		"returning_to_room":
			return SessionLifecycleStateScript.Value.RECOVERING_ROOM
		_:
			return SessionLifecycleStateScript.Value.ROOM_ACTIVE


func _should_preserve_active_battle_for_snapshot(
	snapshot: RoomSnapshot,
	previous_room_flow_state: int,
	previous_session_lifecycle_state: int,
	mapped_room_flow_state: int,
	mapped_session_lifecycle_state: int
) -> bool:
	if snapshot == null:
		return false
	if previous_room_flow_state != RoomFlowStateScript.Value.IN_BATTLE:
		return false
	if previous_session_lifecycle_state != SessionLifecycleStateScript.Value.MATCH_ACTIVE:
		return false
	if mapped_room_flow_state != RoomFlowStateScript.Value.IN_ROOM:
		return false
	if mapped_session_lifecycle_state != SessionLifecycleStateScript.Value.ROOM_ACTIVE:
		return false
	var room_phase := String(snapshot.room_phase).strip_edges()
	if not (room_phase.is_empty() or room_phase == "idle"):
		return false
	var battle_phase := String(snapshot.battle_phase).strip_edges()
	if battle_phase == "completed" or battle_phase == "settled" or battle_phase == "returning":
		return false
	return true
