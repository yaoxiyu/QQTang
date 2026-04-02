class_name RoomServerState
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")

var room_id: String = ""
var owner_peer_id: int = 0
var max_players: int = 8
var selected_map_id: String = MapCatalogScript.get_default_map_id()
var selected_rule_id: String = RuleCatalogScript.get_default_rule_id()
var members: Dictionary = {}
var ready_map: Dictionary = {}


func ensure_room(next_room_id: String, peer_id: int) -> void:
	if room_id.is_empty():
		room_id = next_room_id if not next_room_id.is_empty() else "room_%d" % peer_id
	if owner_peer_id <= 0:
		owner_peer_id = peer_id


func upsert_member(peer_id: int, player_name: String, character_id: String) -> void:
	var profile : Dictionary = members.get(peer_id, {})
	profile["peer_id"] = peer_id
	profile["player_name"] = player_name if not player_name.strip_edges().is_empty() else "Player%d" % peer_id
	profile["character_id"] = _resolve_character_id(character_id)
	members[peer_id] = profile
	if not ready_map.has(peer_id):
		ready_map[peer_id] = false
	if owner_peer_id <= 0:
		owner_peer_id = peer_id


func remove_member(peer_id: int) -> void:
	members.erase(peer_id)
	ready_map.erase(peer_id)
	if owner_peer_id == peer_id:
		var peer_ids := get_sorted_peer_ids()
		owner_peer_id = peer_ids[0] if not peer_ids.is_empty() else 0


func update_profile(peer_id: int, player_name: String, character_id: String) -> void:
	if not members.has(peer_id):
		return
	upsert_member(peer_id, player_name, character_id)


func set_ready(peer_id: int, ready: bool) -> void:
	if not members.has(peer_id):
		return
	ready_map[peer_id] = ready


func toggle_ready(peer_id: int) -> bool:
	var next_ready := not bool(ready_map.get(peer_id, false))
	set_ready(peer_id, next_ready)
	return next_ready


func set_selection(map_id: String, rule_id: String) -> void:
	selected_map_id = map_id if not map_id.is_empty() else MapCatalogScript.get_default_map_id()
	selected_rule_id = rule_id if not rule_id.is_empty() else RuleCatalogScript.get_default_rule_id()


func can_start() -> bool:
	if members.size() < 2:
		return false
	if selected_map_id.is_empty() or selected_rule_id.is_empty():
		return false
	for peer_id in members.keys():
		if not bool(ready_map.get(peer_id, false)):
			return false
	return true


func reset_ready_state() -> void:
	for peer_id in members.keys():
		ready_map[peer_id] = false


func build_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = room_id
	snapshot.owner_peer_id = owner_peer_id
	snapshot.max_players = max_players
	snapshot.selected_map_id = selected_map_id
	snapshot.rule_set_id = selected_rule_id
	snapshot.all_ready = can_start()

	var slot_index := 0
	for peer_id in get_sorted_peer_ids():
		var member := RoomMemberState.new()
		var profile: Dictionary = members.get(peer_id, {})
		member.peer_id = peer_id
		member.player_name = String(profile.get("player_name", "Player%d" % peer_id))
		member.character_id = String(profile.get("character_id", ""))
		member.ready = bool(ready_map.get(peer_id, false))
		member.slot_index = slot_index
		snapshot.members.append(member)
		slot_index += 1
	return snapshot


func get_sorted_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for peer_id in members.keys():
		peer_ids.append(int(peer_id))
	peer_ids.sort()
	return peer_ids


func _resolve_character_id(character_id: String) -> String:
	var trimmed := character_id.strip_edges()
	if CharacterCatalogScript.has_character(trimmed):
		return trimmed
	return CharacterCatalogScript.get_default_character_id()
