class_name RoomSession
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")

var room_id: String = ""
var room_kind: String = ""
var topology: String = ""
var peers: Array[int] = []
var ready_state: Dictionary = {}
var selected_map_id: String = ""
var selected_rule_set_id: String = ""
var selected_mode_id: String = ""
var min_start_players: int = 2
var locked: bool = false


func _init(p_room_id: String = "") -> void:
	room_id = p_room_id


func add_peer(peer_id: int) -> void:
	if peer_id in peers:
		return

	peers.append(peer_id)
	ready_state[peer_id] = false


func remove_peer(peer_id: int) -> void:
	if not (peer_id in peers):
		return

	peers.remove_at(peers.find(peer_id))
	ready_state.erase(peer_id)


func set_ready(peer_id: int, ready: bool) -> void:
	if locked or not (peer_id in peers):
		return

	ready_state[peer_id] = ready


func set_selection(map_id: String, rule_set_id: String, mode_id: String) -> void:
	if locked:
		return
	var resolved_map_id := map_id
	if resolved_map_id.is_empty() and room_kind != "matchmade_room":
		resolved_map_id = MapSelectionCatalogScript.get_default_custom_room_map_id()
	if resolved_map_id.is_empty():
		resolved_map_id = MapCatalogScript.get_default_map_id()
	var binding := MapSelectionCatalogScript.get_map_binding(resolved_map_id)
	selected_map_id = resolved_map_id
	if not binding.is_empty() and bool(binding.get("valid", false)):
		selected_rule_set_id = String(binding.get("bound_rule_set_id", rule_set_id))
		selected_mode_id = String(binding.get("bound_mode_id", mode_id))
		return
	selected_rule_set_id = rule_set_id
	selected_mode_id = mode_id


func can_start() -> bool:
	if peers.is_empty():
		return false

	for peer_id in peers:
		if not ready_state.get(peer_id, false):
			return false

	return true


func lock_config() -> void:
	locked = true


func build_peer_slots() -> Dictionary:
	var slots: Dictionary = {}
	for index in range(peers.size()):
		slots[peers[index]] = index
	return slots
