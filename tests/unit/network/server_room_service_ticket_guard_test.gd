extends Node

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

const ROOM_TICKET_SECRET := "dev_room_ticket_secret"


func _ready() -> void:
	var ok := true
	ok = _test_create_rejects_missing_ticket() and ok
	ok = _test_create_accepts_valid_ticket_and_writes_binding() and ok
	ok = _test_resume_rejects_account_mismatch() and ok
	if ok:
		print("server_room_service_ticket_guard_test: PASS")


func _test_create_rejects_missing_ticket() -> bool:
	var service = _create_service()
	var sent: Array[Dictionary] = []
	service.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)
	service.handle_message({
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": 2,
		"room_id_hint": "room_guard",
		"room_kind": "private_room",
		"player_name": "Player2",
		"character_id": CharacterCatalogScript.get_default_character_id(),
	})
	var rejected := _find_message(sent, 2, TransportMessageTypesScript.ROOM_CREATE_REJECTED)
	service.queue_free()
	return TestAssert.is_true(String(rejected.get("error", "")) == "ROOM_TICKET_MISSING", "missing ticket should reject create", "server_room_service_ticket_guard_test")


func _test_create_accepts_valid_ticket_and_writes_binding() -> bool:
	var service = _create_service()
	var sent: Array[Dictionary] = []
	service.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)
	service.handle_message(_create_message(2, "create", "", "private_room", "", "account_2", "profile_2"))
	var accepted := _find_message(sent, 2, TransportMessageTypesScript.ROOM_CREATE_ACCEPTED)
	var binding = service.room_state.get_member_binding_by_transport_peer(2)
	var prefix := "server_room_service_ticket_guard_test"
	var ok := true
	ok = TestAssert.is_true(not accepted.is_empty(), "valid create ticket should be accepted", prefix) and ok
	ok = TestAssert.is_true(binding != null, "accepted create should allocate member binding", prefix) and ok
	if binding != null:
		ok = TestAssert.is_true(String(binding.account_id) == "account_2", "binding should record account id", prefix) and ok
		ok = TestAssert.is_true(String(binding.profile_id) == "profile_2", "binding should record profile id", prefix) and ok
		ok = TestAssert.is_true(String(binding.device_session_id) == "dsess_2", "binding should record device session id", prefix) and ok
		ok = TestAssert.is_true(String(binding.reconnect_token).is_empty(), "binding should not retain plaintext reconnect token after session send", prefix) and ok
		ok = TestAssert.is_true(not String(binding.reconnect_token_hash).is_empty(), "binding should retain reconnect token hash", prefix) and ok
	service.queue_free()
	return ok


func _test_resume_rejects_account_mismatch() -> bool:
	var service = _create_service()
	var sent: Array[Dictionary] = []
	service.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)
	service.handle_message(_create_message(2, "create", "", "private_room", "", "account_2", "profile_2"))
	var member_session := _find_message(sent, 2, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	service.handle_peer_disconnected(2)
	service.handle_message(_resume_message(9, String(member_session.get("member_id", "")), String(member_session.get("reconnect_token", "")), "room_2", "", "account_9", "profile_2"))
	var rejected := _find_message(sent, 9, TransportMessageTypesScript.ROOM_RESUME_REJECTED)
	service.queue_free()
	return TestAssert.is_true(String(rejected.get("error", "")) == "ROOM_TICKET_ACCOUNT_MISMATCH", "resume should reject mismatched account id", "server_room_service_ticket_guard_test")


func _create_service():
	var service = ServerRoomServiceScript.new()
	add_child(service)
	service.configure_room_ticket_verifier(ROOM_TICKET_SECRET)
	return service


func _create_message(peer_id: int, purpose: String, room_id: String, room_kind: String, match_id: String, account_id: String, profile_id: String) -> Dictionary:
	var ticket := _make_ticket(peer_id, purpose, room_id, room_kind, match_id, account_id, profile_id)
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": room_id,
		"room_kind": room_kind,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"bubble_style_id": BubbleCatalogScript.get_default_bubble_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _resume_message(peer_id: int, member_id: String, reconnect_token: String, room_id: String, match_id: String, account_id: String, profile_id: String) -> Dictionary:
	var ticket := _make_ticket(peer_id, "resume", room_id, "", match_id, account_id, profile_id)
	return {
		"message_type": TransportMessageTypesScript.ROOM_RESUME_REQUEST,
		"sender_peer_id": peer_id,
		"room_id": room_id,
		"member_id": member_id,
		"reconnect_token": reconnect_token,
		"match_id": match_id,
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _make_ticket(peer_id: int, purpose: String, room_id: String, room_kind: String, match_id: String, account_id: String, profile_id: String) -> Dictionary:
	var payload := {
		"ticket_id": "ticket_%s_%d" % [purpose, peer_id],
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": purpose,
		"room_id": room_id,
		"room_kind": room_kind,
		"requested_match_id": match_id,
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
