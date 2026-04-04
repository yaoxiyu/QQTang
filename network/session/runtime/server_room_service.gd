class_name ServerRoomService
extends Node

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")

signal room_snapshot_updated(snapshot: RoomSnapshot)
signal start_match_requested(snapshot: RoomSnapshot)
signal send_to_peer(peer_id: int, message: Dictionary)
signal broadcast_message(message: Dictionary)

var room_state: RoomServerState = RoomServerStateScript.new()


func handle_peer_disconnected(peer_id: int) -> void:
	if room_state == null or not room_state.members.has(peer_id):
		return
	room_state.remove_member(peer_id)
	_broadcast_snapshot()


func handle_match_finished() -> void:
	if room_state == null:
		return
	room_state.reset_ready_state()
	_broadcast_snapshot()


func handle_message(message: Dictionary) -> void:
	var message_type := String(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.ROOM_JOIN_REQUEST:
			_handle_join_request(message)
		TransportMessageTypesScript.ROOM_UPDATE_PROFILE:
			_handle_update_profile(message)
		TransportMessageTypesScript.ROOM_UPDATE_SELECTION:
			_handle_update_selection(message)
		TransportMessageTypesScript.ROOM_TOGGLE_READY:
			_handle_toggle_ready(message)
		TransportMessageTypesScript.ROOM_START_REQUEST:
			_handle_start_request(message)
		TransportMessageTypesScript.ROOM_LEAVE:
			handle_peer_disconnected(int(message.get("sender_peer_id", 0)))
		_:
			pass


func _handle_join_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id <= 0:
		return
	var requested_character_id := String(message.get("character_id", "")).strip_edges()
	if requested_character_id.is_empty() or not CharacterCatalogScript.has_character(requested_character_id):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.ROOM_JOIN_REJECTED,
			"error": "ROOM_MEMBER_PROFILE_INVALID",
			"user_message": "Character selection is invalid",
		})
		return
	var requested_room_id := String(message.get("room_id_hint", "")).strip_edges()
	room_state.ensure_room(requested_room_id, peer_id)
	room_state.upsert_member(
		peer_id,
		String(message.get("player_name", "Player%d" % peer_id)),
		requested_character_id,
		_resolve_character_skin_id(String(message.get("character_skin_id", ""))),
		_resolve_bubble_style_id(String(message.get("bubble_style_id", ""))),
		_resolve_bubble_skin_id(String(message.get("bubble_skin_id", "")))
	)
	room_state.set_ready(peer_id, false)
	send_to_peer.emit(peer_id, {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_ACCEPTED,
		"room_id": room_state.room_id,
		"owner_peer_id": room_state.owner_peer_id,
	})
	_broadcast_snapshot()


func _handle_update_profile(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	var character_id := String(message.get("character_id", "")).strip_edges()
	if character_id.is_empty() or not CharacterCatalogScript.has_character(character_id):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_MEMBER_PROFILE_INVALID",
			"user_message": "Character selection is invalid",
		})
		return
	room_state.update_profile(
		peer_id,
		String(message.get("player_name", "Player%d" % peer_id)),
		character_id,
		_resolve_character_skin_id(String(message.get("character_skin_id", ""))),
		_resolve_bubble_style_id(String(message.get("bubble_style_id", ""))),
		_resolve_bubble_skin_id(String(message.get("bubble_skin_id", "")))
	)
	_broadcast_snapshot()


func _handle_update_selection(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id != room_state.owner_peer_id:
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_START_FORBIDDEN",
			"user_message": "Only the host can change map or rule selection",
		})
		return
	if not MapCatalogScript.has_map(String(message.get("map_id", ""))) or not RuleSetCatalogScript.has_rule(String(message.get("rule_set_id", ""))):
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_SELECTION_INVALID",
			"user_message": "Map or rule selection is invalid",
		})
		return
	room_state.set_selection(
		String(message.get("map_id", "")),
		String(message.get("rule_set_id", ""))
	)
	_broadcast_snapshot()


func _handle_toggle_ready(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	room_state.toggle_ready(peer_id)
	_broadcast_snapshot()


func _handle_start_request(message: Dictionary) -> void:
	var peer_id := int(message.get("sender_peer_id", 0))
	if peer_id != room_state.owner_peer_id or not room_state.can_start():
		send_to_peer.emit(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_REJECTED,
			"error": "ROOM_START_FORBIDDEN",
			"user_message": "Room is not ready to start",
		})
		return
	start_match_requested.emit(room_state.build_snapshot())


func _broadcast_snapshot() -> void:
	var snapshot := room_state.build_snapshot()
	room_snapshot_updated.emit(snapshot)
	broadcast_message.emit({
		"message_type": TransportMessageTypesScript.ROOM_SNAPSHOT,
		"snapshot": snapshot.to_dict(),
	})


func _resolve_character_skin_id(character_skin_id: String) -> String:
	var trimmed := character_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if CharacterSkinCatalogScript.has_id(trimmed):
		return trimmed
	return ""


func _resolve_bubble_style_id(bubble_style_id: String) -> String:
	var trimmed := bubble_style_id.strip_edges()
	if BubbleCatalogScript.has_bubble(trimmed):
		return trimmed
	return BubbleCatalogScript.get_default_bubble_id()


func _resolve_bubble_skin_id(bubble_skin_id: String) -> String:
	var trimmed := bubble_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if BubbleSkinCatalogScript.has_id(trimmed):
		return trimmed
	return ""
