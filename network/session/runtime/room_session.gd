class_name RoomSession
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")

var room_id: String = ""
var room_kind: String = ""
var topology: String = ""
var peers: Array[int] = []
var peer_slots: Dictionary = {}
var ready_state: Dictionary = {}
var open_slot_indices: Array[int] = []
var selected_map_id: String = ""
var selected_rule_set_id: String = ""
var selected_mode_id: String = ""
var queue_type: String = ""
var match_format_id: String = "1v1"
var selected_match_mode_ids: Array[String] = []
var required_party_size: int = 1
var room_queue_state: String = "idle"
var room_queue_entry_id: String = ""
var room_queue_status_text: String = ""
var room_queue_error_code: String = ""
var room_queue_error_message: String = ""
var min_start_players: int = 2
var locked: bool = false

# LegacyMigration: Battle handoff state (populated from authoritative server snapshot)
var room_lifecycle_state: String = "idle"
var room_phase: String = "idle"
var room_phase_reason: String = "none"
var current_assignment_id: String = ""
var current_battle_id: String = ""
var current_match_id: String = ""
var queue_phase: String = "idle"
var queue_terminal_reason: String = "none"
var battle_allocation_state: String = ""
var battle_phase: String = "idle"
var battle_terminal_reason: String = "none"
var battle_status_text: String = ""
var battle_server_host: String = ""
var battle_server_port: int = 0
var room_return_policy: String = "return_to_source_room"
var match_active: bool = false
var can_toggle_ready: bool = false
var can_start_manual_battle: bool = false
var can_update_selection: bool = false
var can_update_match_room_config: bool = false
var can_enter_queue: bool = false
var can_cancel_queue: bool = false
var can_leave_room: bool = true


func _init(p_room_id: String = "") -> void:
	room_id = p_room_id


func add_peer(peer_id: int, slot_index: int = -1) -> void:
	if peer_id in peers:
		if slot_index >= 0:
			peer_slots[peer_id] = slot_index
		return

	peers.append(peer_id)
	ready_state[peer_id] = false
	peer_slots[peer_id] = slot_index if slot_index >= 0 else _first_available_slot()


func remove_peer(peer_id: int) -> void:
	if not (peer_id in peers):
		return

	peers.remove_at(peers.find(peer_id))
	ready_state.erase(peer_id)
	peer_slots.erase(peer_id)


func set_ready(peer_id: int, ready: bool) -> void:
	if locked or not (peer_id in peers):
		return

	ready_state[peer_id] = ready


func set_selection(map_id: String, rule_set_id: String, mode_id: String) -> void:
	if locked:
		return
	if room_kind == "casual_match_room" or room_kind == "ranked_match_room":
		selected_map_id = ""
		selected_rule_set_id = ""
		selected_mode_id = ""
		return
	var resolved_map_id := map_id
	if resolved_map_id.is_empty() and not FrontRoomKindScript.is_match_room(room_kind):
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
		var peer_id: int = peers[index]
		slots[peer_id] = int(peer_slots.get(peer_id, index))
	return slots


func _first_available_slot() -> int:
	var occupied: Dictionary = {}
	for value in peer_slots.values():
		occupied[int(value)] = true
	for slot_index in range(max(peers.size() + 1, 8)):
		if not occupied.has(slot_index):
			return slot_index
	return peers.size()
