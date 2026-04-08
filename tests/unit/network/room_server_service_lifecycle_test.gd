extends Node

const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")


func _ready() -> void:
	var service := ServerRoomServiceScript.new()
	add_child(service)
	var sent_messages: Array[Dictionary] = []
	service.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent_messages.append({
			"peer_id": peer_id,
			"message": message.duplicate(true),
		})
	)

	var character_id := CharacterCatalogScript.get_default_character_id()
	var bubble_id := BubbleCatalogScript.get_default_bubble_id()

	service.handle_message({
		"message_type": "ROOM_CREATE_REQUEST",
		"sender_peer_id": 101,
		"room_id_hint": "ROOM-LIFECYCLE",
		"player_name": "Host",
		"character_id": character_id,
		"bubble_style_id": bubble_id,
	})

	_assert(not service.room_state.room_id.is_empty(), "create request assigns room id")
	_assert(service.room_state.members.size() == 1, "create request registers host member")

	service.handle_message({
		"message_type": "ROOM_LEAVE",
		"sender_peer_id": 101,
	})

	_assert(service.room_state.room_id.is_empty(), "empty room resets room id")
	_assert(service.room_state.owner_peer_id == 0, "empty room clears owner")
	_assert(service.room_state.members.is_empty(), "empty room clears members")
	_assert(service.room_state.ready_map.is_empty(), "empty room clears ready state")
	_assert(sent_messages.size() >= 2, "leave request emits room create and leave responses")
	var leave_ack: Dictionary = sent_messages[sent_messages.size() - 1]
	_assert(int(leave_ack.get("peer_id", 0)) == 101, "leave ack targets leaving peer")
	_assert(String(leave_ack.get("message", {}).get("message_type", "")) == "ROOM_LEAVE_ACCEPTED", "leave request returns leave ack")

	print("room_server_service_lifecycle_test: PASS")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("room_server_service_lifecycle_test: FAIL - %s" % message)
