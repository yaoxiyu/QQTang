class_name RoomSession
extends RefCounted

var room_id: String = ""
var peers: Array[int] = []
var ready_state: Dictionary = {}
var selected_map: String = ""
var selected_mode: String = ""
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


func set_selection(map_id: String, mode_id: String) -> void:
	if locked:
		return

	selected_map = map_id
	selected_mode = mode_id


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
