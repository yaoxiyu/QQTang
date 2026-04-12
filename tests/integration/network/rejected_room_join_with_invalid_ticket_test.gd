extends Node

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const ServerRoomRuntimeScript = preload("res://network/session/runtime/server_room_runtime.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished

const ROOM_TICKET_SECRET := "dev_room_ticket_secret"


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var runtime := ServerRoomRuntimeScript.new()
	add_child(runtime)
	runtime.configure("127.0.0.1", 9000, ROOM_TICKET_SECRET)

	var sent: Array[Dictionary] = []
	runtime.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)

	runtime.create_room_from_request(_build_create_message(2))
	var join_message := _build_join_message(3, "room_2")
	join_message["room_ticket"] = String(join_message.get("room_ticket", "")) + "_bad"
	runtime.handle_room_message(join_message)

	var rejected := _find_message(sent, 3, TransportMessageTypesScript.ROOM_JOIN_REJECTED)
	var ok := TestAssert.is_true(String(rejected.get("error", "")) == "ROOM_TICKET_SIGNATURE_INVALID", "invalid ticket should reject room join", "rejected_room_join_with_invalid_ticket_test")
	runtime.queue_free()
	if ok:
		print("rejected_room_join_with_invalid_ticket_test: PASS")
	test_finished.emit()


func _build_create_message(peer_id: int) -> Dictionary:
	var ticket := _make_ticket(peer_id, "create", "", "private_room")
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "",
		"room_kind": "private_room",
		"player_name": "Host",
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"bubble_style_id": BubbleCatalogScript.get_default_bubble_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _build_join_message(peer_id: int, room_id: String) -> Dictionary:
	var ticket := _make_ticket(peer_id, "join", room_id, "")
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": room_id,
		"player_name": "Guest",
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"bubble_style_id": BubbleCatalogScript.get_default_bubble_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _make_ticket(peer_id: int, purpose: String, room_id: String, room_kind: String) -> Dictionary:
	var payload := {
		"ticket_id": "ticket_%s_%d" % [purpose, peer_id],
		"account_id": "account_%d" % peer_id,
		"profile_id": "profile_%d" % peer_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": purpose,
		"room_id": room_id,
		"room_kind": room_kind,
		"requested_match_id": "",
		"display_name": "Player%d" % peer_id,
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


func _find_message(sent: Array[Dictionary], peer_id: int, message_type: String) -> Dictionary:
	for index in range(sent.size() - 1, -1, -1):
		var entry := sent[index]
		if int(entry.get("peer_id", 0)) != peer_id:
			continue
		var message: Dictionary = entry.get("message", {})
		if String(message.get("message_type", "")) == message_type:
			return message
	return {}


func _to_base64_url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=")
