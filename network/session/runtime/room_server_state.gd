class_name RoomServerState
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const RoomMemberBindingStateScript = preload("res://network/session/runtime/room_member_binding_state.gd")

var room_id: String = ""
var room_kind: String = "private_room"
var topology: String = "dedicated_server"
var owner_peer_id: int = 0
var max_players: int = 8
var room_display_name: String = ""
var is_public_room: bool = false
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
	if resolved_room_kind != "public_room" and resolved_room_kind != "private_room":
		resolved_room_kind = "private_room"
	room_kind = resolved_room_kind
	is_public_room = room_kind == "public_room"
	var normalized_display_name := next_room_display_name.strip_edges()
	if is_public_room:
		room_display_name = normalized_display_name if not normalized_display_name.is_empty() else room_id
	else:
		room_display_name = normalized_display_name
	topology = "dedicated_server"
	min_start_players = 2
	match_active = false


func upsert_member(
	peer_id: int,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = ""
) -> void:
	var profile : Dictionary = members.get(peer_id, {})
	profile["peer_id"] = peer_id
	profile["player_name"] = player_name if not player_name.strip_edges().is_empty() else "Player%d" % peer_id
	profile["character_id"] = _resolve_character_id(character_id)
	profile["character_skin_id"] = _resolve_character_skin_id(character_skin_id)
	profile["bubble_style_id"] = _resolve_bubble_style_id(bubble_style_id, String(profile["character_id"]))
	profile["bubble_skin_id"] = _resolve_bubble_skin_id(bubble_skin_id)
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
			String(profile["bubble_skin_id"])
		)
	else:
		binding.player_name = String(profile["player_name"])
		binding.character_id = String(profile["character_id"])
		binding.character_skin_id = String(profile["character_skin_id"])
		binding.bubble_style_id = String(profile["bubble_style_id"])
		binding.bubble_skin_id = String(profile["bubble_skin_id"])


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
	bubble_skin_id: String = ""
) -> void:
	if not members.has(peer_id):
		return
	upsert_member(peer_id, player_name, character_id, character_skin_id, bubble_style_id, bubble_skin_id)


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
	selected_map_id = map_id if not map_id.is_empty() else MapCatalogScript.get_default_map_id()
	selected_rule_id = rule_id if not rule_id.is_empty() else RuleSetCatalogScript.get_default_rule_id()
	selected_mode_id = mode_id if not mode_id.is_empty() else ModeCatalogScript.get_default_mode_id()


func can_start() -> bool:
	if members.size() < min_start_players:
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


func _resolve_character_id(character_id: String) -> String:
	var trimmed := character_id.strip_edges()
	if CharacterCatalogScript.has_character(trimmed):
		return trimmed
	return CharacterCatalogScript.get_default_character_id()


func _resolve_character_skin_id(character_skin_id: String) -> String:
	var trimmed := character_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if CharacterSkinCatalogScript.has_id(trimmed):
		return trimmed
	return ""


func _resolve_bubble_style_id(bubble_style_id: String, character_id: String) -> String:
	var trimmed := bubble_style_id.strip_edges()
	if BubbleCatalogScript.has_bubble(trimmed):
		return trimmed
	var metadata := CharacterLoaderScript.build_character_metadata(character_id)
	var default_bubble_style_id := String(metadata.get("default_bubble_style_id", ""))
	if BubbleCatalogScript.has_bubble(default_bubble_style_id):
		return default_bubble_style_id
	return BubbleCatalogScript.get_default_bubble_id()


func _resolve_bubble_skin_id(bubble_skin_id: String) -> String:
	var trimmed := bubble_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if BubbleSkinCatalogScript.has_id(trimmed):
		return trimmed
	return ""


# Phase17: Stable member identity methods

func allocate_member_id() -> String:
	var member_id := "member_%d" % next_member_sequence
	next_member_sequence += 1
	return member_id


func allocate_reconnect_token() -> String:
	var timestamp := Time.get_ticks_msec()
	var random_part := randi() % 100000
	return "token_%d_%d" % [timestamp, random_part]


func create_member_binding(
	transport_peer_id: int,
	player_name: String,
	character_id: String,
	character_skin_id: String = "",
	bubble_style_id: String = "",
	bubble_skin_id: String = ""
) -> RoomMemberBindingState:
	var binding := RoomMemberBindingStateScript.new()
	binding.member_id = allocate_member_id()
	binding.reconnect_token = allocate_reconnect_token()
	binding.transport_peer_id = transport_peer_id
	binding.match_peer_id = transport_peer_id
	binding.player_name = player_name if not player_name.strip_edges().is_empty() else "Player%d" % transport_peer_id
	binding.character_id = character_id
	binding.character_skin_id = character_skin_id
	binding.bubble_style_id = bubble_style_id
	binding.bubble_skin_id = bubble_skin_id
	binding.ready = false
	binding.slot_index = member_bindings_by_member_id.size()
	binding.is_owner = owner_peer_id <= 0 or owner_peer_id == transport_peer_id
	binding.connection_state = "connected"
	binding.last_room_id = room_id
	
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
