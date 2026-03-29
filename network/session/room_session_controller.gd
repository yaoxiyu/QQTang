extends Node

signal room_snapshot_changed(snapshot: RoomSnapshot)
signal start_match_requested(snapshot: RoomSnapshot)

const DEFAULT_MAP_ID: String = "default_map"
const DEFAULT_RULE_SET_ID: String = "default_rules"

var room_session: RoomSession = RoomSession.new()
var owner_peer_id: int = 0
var member_profiles: Dictionary = {}
var max_players: int = 8


func configure(session: RoomSession) -> void:
	room_session = session if session != null else RoomSession.new()
	owner_peer_id = room_session.peers[0] if not room_session.peers.is_empty() else 0
	_emit_snapshot_changed()


func build_room_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = room_session.room_id
	snapshot.selected_map_id = _resolve_map_id()
	snapshot.rule_set_id = _resolve_rule_set_id()
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
		snapshot.members.append(member)

	return snapshot


func create_room(owner_peer_id: int) -> void:
	room_session = RoomSession.new("room_%d" % owner_peer_id)
	self.owner_peer_id = owner_peer_id
	member_profiles.clear()
	room_session.add_peer(owner_peer_id)
	_emit_snapshot_changed()


func join_room(member_state: RoomMemberState) -> void:
	if member_state == null or not member_state.is_valid_member():
		return
	if room_session.peers.size() >= max_players:
		return

	room_session.add_peer(member_state.peer_id)
	room_session.set_ready(member_state.peer_id, member_state.ready)
	member_profiles[member_state.peer_id] = {
		"player_name": member_state.player_name,
		"character_id": member_state.character_id,
	}
	_emit_snapshot_changed()


func leave_room(peer_id: int) -> void:
	room_session.remove_peer(peer_id)
	member_profiles.erase(peer_id)
	if owner_peer_id == peer_id:
		_reassign_owner()
	_emit_snapshot_changed()


func set_member_ready(peer_id: int, ready: bool) -> void:
	room_session.set_ready(peer_id, ready)
	_emit_snapshot_changed()


func can_start_match() -> bool:
	if room_session.peers.size() < 2:
		return false
	if _resolve_map_id().is_empty():
		return false
	if _resolve_rule_set_id().is_empty():
		return false
	return _are_all_members_ready()


func can_request_start_match(requester_peer_id: int) -> bool:
	if requester_peer_id != owner_peer_id:
		return false
	return can_start_match()


func request_start_match(requester_peer_id: int) -> void:
	if not can_request_start_match(requester_peer_id):
		return
	start_match_requested.emit(build_room_snapshot())


func set_room_selection(map_id: String, rule_set_id: String) -> void:
	room_session.set_selection(
		map_id if not map_id.is_empty() else DEFAULT_MAP_ID,
		rule_set_id if not rule_set_id.is_empty() else DEFAULT_RULE_SET_ID
	)
	_emit_snapshot_changed()


func debug_dump_room() -> Dictionary:
	return build_room_snapshot().to_dict()


func reset_ready_state() -> void:
	for peer_id in room_session.peers:
		room_session.set_ready(peer_id, false)
	_emit_snapshot_changed()


func _emit_snapshot_changed() -> void:
	room_snapshot_changed.emit(build_room_snapshot())


func _resolve_map_id() -> String:
	return room_session.selected_map if not room_session.selected_map.is_empty() else DEFAULT_MAP_ID


func _resolve_rule_set_id() -> String:
	return room_session.selected_mode if not room_session.selected_mode.is_empty() else DEFAULT_RULE_SET_ID


func _are_all_members_ready() -> bool:
	if room_session.peers.size() < 2:
		return false

	for peer_id in room_session.peers:
		if not bool(room_session.ready_state.get(peer_id, false)):
			return false
	return true


func _reassign_owner() -> void:
	owner_peer_id = room_session.peers[0] if not room_session.peers.is_empty() else 0