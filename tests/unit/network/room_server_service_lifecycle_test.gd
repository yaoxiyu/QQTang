extends "res://tests/gut/base/qqt_unit_test.gd"

const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const ROOM_TICKET_SECRET := "dev_room_ticket_secret"


func test_main() -> void:
	var service := ServerRoomServiceScript.new()
	add_child(service)
	service.configure_room_ticket_verifier(ROOM_TICKET_SECRET)
	var sent_messages: Array[Dictionary] = []
	service.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent_messages.append({
			"peer_id": peer_id,
			"message": message.duplicate(true),
		})
	)

	var character_id := CharacterCatalogScript.get_default_character_id()
	var bubble_id := BubbleCatalogScript.get_default_bubble_id()
	var create_ticket := _make_ticket(101, "create", "", "private_room", "")

	service.handle_message({
		"message_type": "ROOM_CREATE_REQUEST",
		"sender_peer_id": 101,
		"room_id_hint": "ROOM-LIFECYCLE",
		"player_name": "Host",
		"character_id": character_id,
		"bubble_style_id": bubble_id,
		"room_kind": "private_room",
		"room_ticket": create_ticket.get("token", ""),
		"room_ticket_id": create_ticket.get("ticket_id", ""),
		"account_id": create_ticket.get("account_id", ""),
		"profile_id": create_ticket.get("profile_id", ""),
		"device_session_id": create_ticket.get("device_session_id", ""),
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



func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)


func _make_ticket(peer_id: int, purpose: String, room_id: String, room_kind: String, match_id: String) -> Dictionary:
	var payload := {
		"ticket_id": "ticket_%s_%d" % [purpose, peer_id],
		"account_id": "account_%d" % peer_id,
		"profile_id": "profile_%d" % peer_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": purpose,
		"room_id": room_id,
		"room_kind": room_kind,
		"requested_match_id": match_id,
		"display_name": "Host",
		"allowed_character_ids": [CharacterCatalogScript.get_default_character_id()],
		"allowed_character_skin_ids": [""],
		"allowed_bubble_style_ids": [BubbleCatalogScript.get_default_bubble_id()],
		"allowed_bubble_skin_ids": [""],
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": int(Time.get_unix_time_from_system()) + 60,
		"nonce": "nonce_%s_%d" % [purpose, peer_id],
	}
	var encoded_payload := _to_base64_url(JSON.stringify(payload).to_utf8_buffer())
	var crypto := Crypto.new()
	var digest := crypto.hmac_digest(HashingContext.HASH_SHA256, ROOM_TICKET_SECRET.to_utf8_buffer(), encoded_payload.to_utf8_buffer())
	return {
		"token": "%s.%s" % [encoded_payload, _to_base64_url(digest)],
		"ticket_id": String(payload.get("ticket_id", "")),
		"account_id": String(payload.get("account_id", "")),
		"profile_id": String(payload.get("profile_id", "")),
		"device_session_id": String(payload.get("device_session_id", "")),
	}


func _to_base64_url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=")

