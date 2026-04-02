class_name RuntimeDebugTools
extends Node

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const DEFAULT_REMOTE_NAME: String = "RemoteFox"
const DEFAULT_REMOTE_CHARACTER_ID: String = "hero_runner"


func bootstrap_local_loop_room_if_enabled(room_controller: Node, runtime_config: RefCounted, local_peer_id: int, remote_peer_id: int) -> void:
	if runtime_config == null or room_controller == null:
		return
	if not runtime_config.enable_local_loop_debug_room:
		return

	if runtime_config.auto_create_room_on_enter and room_controller.room_session.peers.is_empty():
		room_controller.create_room(local_peer_id)

	if runtime_config.auto_add_remote_debug_member and room_controller.room_session.peers.size() == 1 and room_controller.room_session.peers.has(local_peer_id) and not room_controller.room_session.peers.has(remote_peer_id):
		var remote_member := RoomMemberState.new()
		remote_member.peer_id = remote_peer_id
		remote_member.player_name = DEFAULT_REMOTE_NAME
		remote_member.ready = true
		remote_member.slot_index = 1
		remote_member.character_id = _resolve_debug_character_id(DEFAULT_REMOTE_CHARACTER_ID)
		room_controller.join_room(remote_member)

	if room_controller.room_session.peers.size() == 2 and room_controller.room_session.peers.has(local_peer_id) and room_controller.room_session.peers.has(remote_peer_id):
		room_controller.set_member_ready(local_peer_id, false)
		room_controller.set_member_ready(remote_peer_id, true)
		if room_controller.room_session.selected_map.is_empty() or room_controller.room_session.selected_mode.is_empty():
			room_controller.set_room_selection(
				MapCatalogScript.get_default_map_id(),
				RuleCatalogScript.get_default_rule_id()
			)


func ensure_manual_local_loop_room(room_controller: Node, local_peer_id: int, remote_peer_id: int, selected_map_id: String = "", selected_rule_set_id: String = "") -> void:
	if room_controller == null:
		return

	if room_controller.room_session == null or not room_controller.room_session.peers.has(local_peer_id):
		room_controller.create_room(local_peer_id)

	if not room_controller.room_session.peers.has(remote_peer_id):
		var remote_member := RoomMemberState.new()
		remote_member.peer_id = remote_peer_id
		remote_member.player_name = DEFAULT_REMOTE_NAME
		remote_member.ready = true
		remote_member.slot_index = 1
		remote_member.character_id = _resolve_debug_character_id(DEFAULT_REMOTE_CHARACTER_ID)
		room_controller.join_room(remote_member)
	else:
		room_controller.set_member_ready(remote_peer_id, true)

	if room_controller.room_session.selected_map.is_empty() or room_controller.room_session.selected_mode.is_empty():
		room_controller.set_room_selection(
			selected_map_id if not selected_map_id.is_empty() else MapCatalogScript.get_default_map_id(),
			selected_rule_set_id if not selected_rule_set_id.is_empty() else RuleCatalogScript.get_default_rule_id()
		)


func reset_local_loop_room_ready(room_controller: Node, runtime_config: RefCounted, local_peer_id: int, remote_peer_id: int) -> void:
	if room_controller == null:
		return
	if room_controller.room_session.peers.size() == 2 and room_controller.room_session.peers.has(local_peer_id) and room_controller.room_session.peers.has(remote_peer_id):
		room_controller.set_member_ready(local_peer_id, false)
		room_controller.set_member_ready(remote_peer_id, true)


func debug_dump(runtime_config: RefCounted = null) -> Dictionary:
	return {
		"local_loop_enabled": runtime_config.enable_local_loop_debug_room if runtime_config != null else false,
		"auto_create_room_on_enter": runtime_config.auto_create_room_on_enter if runtime_config != null else false,
		"auto_add_remote_debug_member": runtime_config.auto_add_remote_debug_member if runtime_config != null else false,
	}


func _resolve_debug_character_id(character_id: String) -> String:
	if CharacterCatalogScript.has_character(character_id):
		return character_id
	return CharacterCatalogScript.get_default_character_id()
