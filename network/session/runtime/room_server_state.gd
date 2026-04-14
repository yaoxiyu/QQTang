class_name RoomServerState
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const RoomSelectionPolicyScript = preload("res://network/session/runtime/room_selection_policy.gd")
const RoomMemberBindingStateScript = preload("res://network/session/runtime/room_member_binding_state.gd")
const ResumeTokenUtilsScript = preload("res://network/session/runtime/resume_token_utils.gd")

var room_id: String = ""
var room_kind: String = "private_room"
var topology: String = "dedicated_server"
var owner_peer_id: int = 0
var max_players: int = 8
var room_display_name: String = ""
var is_public_room: bool = false
var assignment_id: String = ""
var season_id: String = ""
var expected_member_count: int = 0
var is_matchmade_room: bool = false
var locked_map_id: String = ""
var locked_rule_set_id: String = ""
var locked_mode_id: String = ""
var assignment_revision: int = 0
var selected_map_id: String = MapCatalogScript.get_default_map_id()
var selected_rule_id: String = RuleSetCatalogScript.get_default_rule_id()
var selected_mode_id: String = ModeCatalogScript.get_default_mode_id()
var min_start_players: int = 2
var members: Dictionary = {}
var ready_map: Dictionary = {}
var match_active: bool = false

# Phase17: Stable member identity model
var member_bindings_by_member_id: Dictionary = {}
var member_id_by_transport_peer_id: Dictionary = {}
var next_member_sequence: int = 1


func reset() -> void:
	room_id = ""
	room_kind = "private_room"
	topology = "dedicated_server"
	owner_peer_id = 0
	max_players = 8
	room_display_name = ""
	is_public_room = false
	assignment_id = ""
	season_id = ""
	expected_member_count = 0
	is_matchmade_room = false
	locked_map_id = ""
	locked_rule_set_id = ""
	locked_mode_id = ""
	assignment_revision = 0
	selected_map_id = MapCatalogScript.get_default_map_id()
	selected_rule_id = RuleSetCatalogScript.get_default_rule_id()
	selected_mode_id = ModeCatalogScript.get_default_mode_id()
	min_start_players = 2
	match_active = false
	members.clear()
	ready_map.clear()
	member_bindings_by_member_id.clear()
	member_id_by_transport_peer_id.clear()
	next_member_sequence = 1


func ensure_room(next_room_id: String, peer_id: int, next_room_kind: String = "private_room", next_room_display_name: String = "") -> void:
	if room_id.is_empty():
		room_id = next_room_id if not next_room_id.is_empty() else "room_%d" % peer_id
	if owner_peer_id <= 0:
		owner_peer_id = peer_id
	var resolved_room_kind := String(next_room_kind).strip_edges().to_lower()
	if resolved_room_kind != "public_room" and resolved_room_kind != "private_room" and resolved_room_kind != "matchmade_room":
		resolved_room_kind = "private_room"
	room_kind = resolved_room_kind
	is_matchmade_room = room_kind == "matchmade_room"
	is_public_room = room_kind == "public_room"
	var normalized_display_name := next_room_display_name.strip_edges()
	if is_matchmade_room:
		room_display_name = "Matchmade Room"
	elif is_public_room:
		room_display_name = normalized_display_name if not normalized_display_name.is_empty() else room_id
	else:
		room_display_name = normalized_display_name
	topology = "dedicated_server"
	match_active = false
	set_selection("", "", "")


func upsert_member(
	peer_id: int,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = "",
	team_id: int = 0,
	account_id: String = "",
	profile_id: String = "",
	device_session_id: String = "",
	ticket_id: String = "",
	display_name_source: String = ""
) -> void:
	var profile : Dictionary = members.get(peer_id, {})
	var resolved_team_id := _resolve_team_id(peer_id, team_id)
	var resolved_loadout: Dictionary = RoomSelectionPolicyScript.normalize_member_loadout(character_id, character_skin_id, bubble_style_id, bubble_skin_id)
	profile["peer_id"] = peer_id
	profile["player_name"] = player_name if not player_name.strip_edges().is_empty() else "Player%d" % peer_id
	profile["character_id"] = String(resolved_loadout.get("character_id", ""))
	profile["character_skin_id"] = String(resolved_loadout.get("character_skin_id", ""))
	profile["bubble_style_id"] = String(resolved_loadout.get("bubble_style_id", ""))
	profile["bubble_skin_id"] = String(resolved_loadout.get("bubble_skin_id", ""))
	profile["team_id"] = resolved_team_id
	members[peer_id] = profile
	if not ready_map.has(peer_id):
		ready_map[peer_id] = false
	profile["ready"] = bool(ready_map.get(peer_id, false))
	members[peer_id] = profile
	if owner_peer_id <= 0:
		owner_peer_id = peer_id
	
	# Phase17: Also create/update member binding
	var binding := get_member_binding_by_transport_peer(peer_id)
	if binding == null:
		create_member_binding(
			peer_id,
			String(profile["player_name"]),
			String(profile["character_id"]),
			String(profile["character_skin_id"]),
			String(profile["bubble_style_id"]),
			String(profile["bubble_skin_id"]),
			resolved_team_id,
			account_id,
			profile_id,
			device_session_id,
			ticket_id,
			display_name_source
		)
	else:
		binding.player_name = String(profile["player_name"])
		binding.character_id = String(profile["character_id"])
		binding.character_skin_id = String(profile["character_skin_id"])
		binding.bubble_style_id = String(profile["bubble_style_id"])
		binding.bubble_skin_id = String(profile["bubble_skin_id"])
		binding.team_id = resolved_team_id
		if not account_id.is_empty():
			binding.account_id = account_id
		if not profile_id.is_empty():
			binding.profile_id = profile_id
		if not device_session_id.is_empty():
			binding.device_session_id = device_session_id
		if not ticket_id.is_empty():
			binding.ticket_id = ticket_id
		if not display_name_source.is_empty():
			binding.display_name_source = display_name_source
		if binding.auth_claim_version <= 0 and not binding.account_id.is_empty():
			binding.auth_claim_version = 1


func remove_member(peer_id: int) -> void:
	members.erase(peer_id)
	ready_map.erase(peer_id)
	
	# Phase17: Also remove member binding
	var binding := get_member_binding_by_transport_peer(peer_id)
	if binding == null:
		binding = get_member_binding_by_match_peer(peer_id)
	if binding != null:
		remove_member_binding(binding.member_id)
	
	if owner_peer_id == peer_id:
		var peer_ids := get_sorted_peer_ids()
		owner_peer_id = peer_ids[0] if not peer_ids.is_empty() else 0


func update_profile(
	peer_id: int,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = "",
	team_id: int = 1
) -> void:
	if not members.has(peer_id):
		return
	if is_matchmade_room:
		var profile_for_team: Dictionary = members.get(peer_id, {})
		team_id = int(profile_for_team.get("team_id", _resolve_team_id(peer_id, team_id)))
	if bool(ready_map.get(peer_id, false)):
		var profile: Dictionary = members.get(peer_id, {})
		var current_team_id := int(profile.get("team_id", _resolve_team_id(peer_id, 0)))
		if team_id != current_team_id:
			return
	upsert_member(peer_id, player_name, character_id, character_skin_id, bubble_style_id, bubble_skin_id, team_id)


func set_ready(peer_id: int, ready: bool) -> void:
	if not members.has(peer_id):
		return
	ready_map[peer_id] = ready
	var profile: Dictionary = members.get(peer_id, {})
	profile["ready"] = ready
	members[peer_id] = profile
	var binding := get_member_binding_by_transport_peer(peer_id)
	if binding != null:
		binding.ready = ready


func toggle_ready(peer_id: int) -> bool:
	var next_ready := not bool(ready_map.get(peer_id, false))
	set_ready(peer_id, next_ready)
	return next_ready


func set_selection(map_id: String, rule_id: String, mode_id: String) -> void:
	var resolved_map_id := map_id
	if is_matchmade_room:
		resolved_map_id = locked_map_id if not locked_map_id.is_empty() else resolved_map_id
	elif resolved_map_id.is_empty():
		resolved_map_id = MapSelectionCatalogScript.get_default_custom_room_map_id()
	if resolved_map_id.is_empty():
		resolved_map_id = MapCatalogScript.get_default_map_id()
	var binding := _resolve_map_binding(resolved_map_id)
	selected_map_id = resolved_map_id
	if not binding.is_empty():
		selected_rule_id = String(binding.get("bound_rule_set_id", ""))
		selected_mode_id = String(binding.get("bound_mode_id", ""))
		min_start_players = int(binding.get("required_team_count", 2))
		max_players = int(binding.get("max_player_count", max_players))
		return
	selected_rule_id = locked_rule_set_id if is_matchmade_room and not locked_rule_set_id.is_empty() else (rule_id if not rule_id.is_empty() else RuleSetCatalogScript.get_default_rule_id())
	selected_mode_id = locked_mode_id if is_matchmade_room and not locked_mode_id.is_empty() else (mode_id if not mode_id.is_empty() else ModeCatalogScript.get_default_mode_id())
	min_start_players = 2


func can_start() -> bool:
	var binding := _resolve_map_binding(selected_map_id)
	if binding.is_empty():
		return false
	var required_team_count := int(binding.get("required_team_count", min_start_players))
	var max_player_count := int(binding.get("max_player_count", max_players))
	if is_matchmade_room and expected_member_count > 0 and members.size() != expected_member_count:
		return false
	if members.size() < min_start_players:
		return false
	if max_player_count > 0 and members.size() > max_player_count:
		return false
	if get_distinct_team_ids().size() < required_team_count:
		return false
	if selected_map_id.is_empty() or selected_rule_id.is_empty() or selected_mode_id.is_empty():
		return false
	if not MapCatalogScript.has_map(selected_map_id):
		return false
	if not RuleSetCatalogScript.has_rule(selected_rule_id):
		return false
	if not ModeCatalogScript.has_mode(selected_mode_id):
		return false
	for peer_id in members.keys():
		if not bool(ready_map.get(peer_id, false)):
			return false
	return true


func get_distinct_team_ids() -> Array[int]:
	var team_ids: Array[int] = []
	if not member_bindings_by_member_id.is_empty():
		for binding in _get_sorted_member_bindings():
			if binding == null or binding.team_id < 1:
				continue
			if not team_ids.has(binding.team_id):
				team_ids.append(binding.team_id)
		team_ids.sort()
		return team_ids

	for peer_id in members.keys():
		var profile: Dictionary = members.get(peer_id, {})
		var team_id := int(profile.get("team_id", 0))
		if team_id < 1:
			continue
		if not team_ids.has(team_id):
			team_ids.append(team_id)
	team_ids.sort()
	return team_ids


func reset_ready_state() -> void:
	for peer_id in members.keys():
		ready_map[peer_id] = false
	for member_id in member_bindings_by_member_id.keys():
		var binding: RoomMemberBindingState = member_bindings_by_member_id[member_id]
		binding.ready = false


func build_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = room_id
	snapshot.room_kind = room_kind
	snapshot.topology = topology
	snapshot.owner_peer_id = owner_peer_id
	snapshot.max_players = max_players
	snapshot.room_display_name = room_display_name
	snapshot.selected_map_id = selected_map_id
	snapshot.rule_set_id = selected_rule_id
	snapshot.mode_id = selected_mode_id
	snapshot.min_start_players = min_start_players
	snapshot.all_ready = can_start()
	snapshot.match_active = match_active

	if not member_bindings_by_member_id.is_empty():
		for binding in _get_sorted_member_bindings():
			var member := RoomMemberState.new()
			var display_peer_id := binding.match_peer_id if binding.match_peer_id > 0 else binding.transport_peer_id
			member.peer_id = display_peer_id
			member.player_name = binding.player_name
			member.character_id = binding.character_id
			member.character_skin_id = binding.character_skin_id
			member.bubble_style_id = binding.bubble_style_id
			member.bubble_skin_id = binding.bubble_skin_id
			member.team_id = binding.team_id
			member.ready = binding.ready
			member.slot_index = binding.slot_index
			member.is_owner = binding.is_owner or display_peer_id == owner_peer_id
			member.is_local_player = false
			member.connection_state = binding.connection_state
			snapshot.members.append(member)
		return snapshot

	var slot_index := 0
	for peer_id in get_sorted_peer_ids():
		var member := RoomMemberState.new()
		var profile: Dictionary = members.get(peer_id, {})
		member.peer_id = peer_id
		member.player_name = String(profile.get("player_name", "Player%d" % peer_id))
		member.character_id = String(profile.get("character_id", ""))
		member.character_skin_id = String(profile.get("character_skin_id", ""))
		member.bubble_style_id = String(profile.get("bubble_style_id", ""))
		member.bubble_skin_id = String(profile.get("bubble_skin_id", ""))
		member.team_id = int(profile.get("team_id", slot_index + 1))
		member.ready = bool(ready_map.get(peer_id, false))
		member.slot_index = slot_index
		member.is_owner = peer_id == owner_peer_id
		member.is_local_player = false
		
		# Phase17: Get connection_state from member binding
		var binding := get_member_binding_by_transport_peer(peer_id)
		if binding != null:
			member.connection_state = binding.connection_state
		else:
			member.connection_state = "connected"
		
		snapshot.members.append(member)
		slot_index += 1
	return snapshot


func get_sorted_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for peer_id in members.keys():
		peer_ids.append(int(peer_id))
	peer_ids.sort()
	return peer_ids


func _resolve_team_id(peer_id: int, team_id: int) -> int:
	if is_matchmade_room and team_id > 0:
		return team_id
	if team_id > 0:
		return team_id
	var profile: Dictionary = members.get(peer_id, {})
	var profile_team_id := int(profile.get("team_id", 0))
	if profile_team_id > 0:
		return profile_team_id
	var binding := get_member_binding_by_transport_peer(peer_id)
	if binding != null and binding.team_id > 0:
		return binding.team_id
	return member_bindings_by_member_id.size() + 1


func _get_sorted_member_bindings() -> Array[RoomMemberBindingState]:
	var bindings: Array[RoomMemberBindingState] = []
	for member_id in member_bindings_by_member_id.keys():
		var binding: RoomMemberBindingState = member_bindings_by_member_id[member_id]
		if binding != null:
			bindings.append(binding)
	bindings.sort_custom(func(a: RoomMemberBindingState, b: RoomMemberBindingState) -> bool:
		if a.slot_index == b.slot_index:
			return a.match_peer_id < b.match_peer_id
		return a.slot_index < b.slot_index
	)
	return bindings


# Phase17: Stable member identity methods

func allocate_member_id() -> String:
	var member_id := "member_%d" % next_member_sequence
	next_member_sequence += 1
	return member_id


func allocate_reconnect_token() -> String:
	return ResumeTokenUtilsScript.generate_resume_token()


func create_member_binding(
	transport_peer_id: int,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = "",
	team_id: int = 0,
	account_id: String = "",
	profile_id: String = "",
	device_session_id: String = "",
	ticket_id: String = "",
	display_name_source: String = ""
) -> RoomMemberBindingState:
	var binding := RoomMemberBindingStateScript.new()
	var slot_index := member_bindings_by_member_id.size()
	binding.member_id = allocate_member_id()
	binding.set_reconnect_token_plaintext(allocate_reconnect_token())
	binding.transport_peer_id = transport_peer_id
	binding.match_peer_id = transport_peer_id
	binding.player_name = player_name if not player_name.strip_edges().is_empty() else "Player%d" % transport_peer_id
	binding.character_id = character_id
	binding.character_skin_id = character_skin_id
	binding.bubble_style_id = bubble_style_id
	binding.bubble_skin_id = bubble_skin_id
	binding.team_id = team_id if team_id > 0 else slot_index + 1
	binding.ready = false
	binding.slot_index = slot_index
	binding.is_owner = owner_peer_id <= 0 or owner_peer_id == transport_peer_id
	binding.connection_state = "connected"
	binding.last_room_id = room_id
	binding.account_id = account_id
	binding.profile_id = profile_id
	binding.device_session_id = device_session_id
	binding.ticket_id = ticket_id
	binding.auth_claim_version = 1 if not account_id.is_empty() else 0
	binding.display_name_source = display_name_source
	
	member_bindings_by_member_id[binding.member_id] = binding
	member_id_by_transport_peer_id[transport_peer_id] = binding.member_id
	
	if owner_peer_id <= 0:
		owner_peer_id = transport_peer_id
	
	return binding


func get_member_binding_by_transport_peer(peer_id: int) -> RoomMemberBindingState:
	var member_id: String = member_id_by_transport_peer_id.get(peer_id, "")
	if member_id.is_empty():
		return null
	return member_bindings_by_member_id.get(member_id)


func get_member_binding_by_member_id(member_id: String) -> RoomMemberBindingState:
	return member_bindings_by_member_id.get(member_id)


func get_member_binding_by_match_peer(peer_id: int) -> RoomMemberBindingState:
	for member_id in member_bindings_by_member_id.keys():
		var binding: RoomMemberBindingState = member_bindings_by_member_id[member_id]
		if binding != null and binding.match_peer_id == peer_id:
			return binding
	return null


func bind_transport_to_member(member_id: String, peer_id: int) -> void:
	var binding := get_member_binding_by_member_id(member_id)
	if binding == null:
		return
	# Remove old transport mapping if exists
	if binding.transport_peer_id > 0:
		member_id_by_transport_peer_id.erase(binding.transport_peer_id)
	binding.transport_peer_id = peer_id
	binding.connection_state = "connected"
	member_id_by_transport_peer_id[peer_id] = member_id


func mark_member_disconnected_by_transport_peer(peer_id: int, deadline_msec: int, current_match_id: String) -> RoomMemberBindingState:
	var binding := get_member_binding_by_transport_peer(peer_id)
	if binding == null:
		return null
	binding.connection_state = "disconnected"
	binding.disconnect_deadline_msec = deadline_msec
	binding.last_match_id = current_match_id
	# Keep match_peer_id intact for resume
	member_id_by_transport_peer_id.erase(peer_id)
	binding.transport_peer_id = 0
	return binding


func remove_member_binding(member_id: String) -> void:
	var binding := get_member_binding_by_member_id(member_id)
	if binding == null:
		return
	if binding.transport_peer_id > 0:
		member_id_by_transport_peer_id.erase(binding.transport_peer_id)
	member_bindings_by_member_id.erase(member_id)
	# Update owner if needed
	if binding.is_owner:
		var remaining_ids := member_bindings_by_member_id.keys()
		if not remaining_ids.is_empty():
			var new_owner_binding: RoomMemberBindingState = member_bindings_by_member_id[remaining_ids[0]]
			new_owner_binding.is_owner = true
			owner_peer_id = new_owner_binding.transport_peer_id
		else:
			owner_peer_id = 0


func clear_resume_state() -> void:
	for member_id in member_bindings_by_member_id.keys():
		var binding: RoomMemberBindingState = member_bindings_by_member_id[member_id]
		binding.disconnect_deadline_msec = 0
		binding.last_match_id = ""
		if binding.connection_state == "disconnected":
			binding.connection_state = "connected"


func freeze_match_peer_bindings(match_id: String) -> void:
	for member_id in member_bindings_by_member_id.keys():
		var binding: RoomMemberBindingState = member_bindings_by_member_id[member_id]
		if binding.connection_state == "connected" and binding.transport_peer_id > 0:
			binding.match_peer_id = binding.transport_peer_id
			binding.last_match_id = match_id


func _resolve_map_binding(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	if binding.is_empty() or not bool(binding.get("valid", false)):
		return {}
	return binding
