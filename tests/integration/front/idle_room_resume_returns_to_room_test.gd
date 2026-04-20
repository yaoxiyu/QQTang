extends "res://tests/gut/base/qqt_integration_test.gd"

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const SERVER_ROOM_RUNTIME_PATH := "res://network/session/runtime/server_room_runtime.gd"
const ROOM_TICKET_SECRET := "dev_room_ticket_secret"


func test_main() -> void:
	var ok := true
	ok = _test_idle_room_resume_returns_to_room_snapshot() and ok
	ok = _test_manual_leave_invalidates_room_member_session() and ok
	ok = _test_idle_room_resume_window_expiry_removes_member_session() and ok


func _test_idle_room_resume_returns_to_room_snapshot() -> bool:
	var runtime := _new_server_room_runtime()
	if runtime == null:
		return qqt_check(true, "skip: ServerRoomRuntime removed after phase26", "idle_room_resume_returns_to_room_test")
	add_child(runtime)
	runtime.configure("127.0.0.1", 9100)

	var sent: Array[Dictionary] = []
	var broadcasts: Array[Dictionary] = []
	runtime.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)
	runtime.broadcast_message.connect(func(message: Dictionary) -> void:
		broadcasts.append(message.duplicate(true))
	)

	runtime.create_room_from_request(_create_message(2))
	runtime.handle_room_message(_join_message(3))
	var member_session := _find_message_to_peer(sent, 3, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	runtime.handle_peer_disconnected(3)
	runtime.handle_room_message({
		"message_type": TransportMessageTypesScript.ROOM_RESUME_REQUEST,
		"sender_peer_id": 9,
		"room_id": "LegacyMigration_idle_room",
		"member_id": String(member_session.get("member_id", "")),
		"reconnect_token": String(member_session.get("reconnect_token", "")),
		"match_id": "",
		"room_ticket": _make_resume_ticket(9, String(member_session.get("room_id", "LegacyMigration_idle_room")), "").get("token", ""),
		"room_ticket_id": _make_resume_ticket(9, String(member_session.get("room_id", "LegacyMigration_idle_room")), "").get("ticket_id", ""),
		"account_id": "account_3",
		"profile_id": "profile_3",
		"device_session_id": "dsess_9",
	})

	var prefix := "idle_room_resume_returns_to_room_test"
	var ok := true
	var accepted := _find_message_to_peer(sent, 9, TransportMessageTypesScript.ROOM_JOIN_ACCEPTED)
	var resume_rejected := _find_message_to_peer(sent, 9, TransportMessageTypesScript.ROOM_RESUME_REJECTED)
	var match_resume := _find_message_to_peer(sent, 9, TransportMessageTypesScript.MATCH_RESUME_ACCEPTED)
	ok = qqt_check(not accepted.is_empty(), "idle resume should receive ROOM_JOIN_ACCEPTED", prefix) and ok
	ok = qqt_check(resume_rejected.is_empty(), "idle resume should not be rejected", prefix) and ok
	ok = qqt_check(match_resume.is_empty(), "idle resume should not enter active match resume", prefix) and ok

	var snapshot := _latest_room_snapshot(broadcasts)
	ok = qqt_check(snapshot != null, "idle resume should broadcast room snapshot", prefix) and ok
	if snapshot != null:
		var resumed_member := _find_member(snapshot, 9)
		ok = qqt_check(resumed_member != null, "room snapshot should show resumed transport peer", prefix) and ok
		if resumed_member != null:
			ok = qqt_check(resumed_member.connection_state == "connected", "resumed member should be connected", prefix) and ok
		ok = qqt_check(not snapshot.match_active, "idle resume should stay in room state", prefix) and ok

	runtime.free()
	return ok


func _test_idle_room_resume_window_expiry_removes_member_session() -> bool:
	var runtime := _new_server_room_runtime()
	if runtime == null:
		return qqt_check(true, "skip: ServerRoomRuntime removed after phase26", "idle_room_resume_returns_to_room_test")
	add_child(runtime)
	runtime.configure("127.0.0.1", 9100)

	var sent: Array[Dictionary] = []
	runtime.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)

	runtime.create_room_from_request(_create_message(2))
	runtime.handle_room_message(_join_message(3))
	var member_session := _find_message_to_peer(sent, 3, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	runtime.handle_peer_disconnected(3)
	var binding = runtime._room_service.room_state.get_member_binding_by_member_id(String(member_session.get("member_id", "")))
	if binding != null:
		binding.disconnect_deadline_msec = 1
	runtime._room_service.poll_idle_resume_expired()
	runtime.handle_room_message({
		"message_type": TransportMessageTypesScript.ROOM_RESUME_REQUEST,
		"sender_peer_id": 9,
		"room_id": "LegacyMigration_idle_room",
		"member_id": String(member_session.get("member_id", "")),
		"reconnect_token": String(member_session.get("reconnect_token", "")),
		"match_id": "",
		"room_ticket": _make_resume_ticket(9, String(member_session.get("room_id", "LegacyMigration_idle_room")), "").get("token", ""),
		"room_ticket_id": _make_resume_ticket(9, String(member_session.get("room_id", "LegacyMigration_idle_room")), "").get("ticket_id", ""),
		"account_id": "account_3",
		"profile_id": "profile_3",
		"device_session_id": "dsess_9",
	})

	var rejected := _find_message_to_peer(sent, 9, TransportMessageTypesScript.ROOM_RESUME_REJECTED)
	var prefix := "idle_room_resume_returns_to_room_test"
	var ok := true
	ok = qqt_check(not rejected.is_empty(), "expired idle resume session should be rejected", prefix) and ok
	if not rejected.is_empty():
		ok = qqt_check(String(rejected.get("error", "")) == "MEMBER_NOT_FOUND", "expired idle session should be removed", prefix) and ok

	runtime.free()
	return ok


func _test_manual_leave_invalidates_room_member_session() -> bool:
	var runtime := _new_server_room_runtime()
	if runtime == null:
		return qqt_check(true, "skip: ServerRoomRuntime removed after phase26", "idle_room_resume_returns_to_room_test")
	add_child(runtime)
	runtime.configure("127.0.0.1", 9100)

	var sent: Array[Dictionary] = []
	runtime.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)

	runtime.create_room_from_request(_create_message(2))
	runtime.handle_room_message(_join_message(3))
	var member_session := _find_message_to_peer(sent, 3, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	runtime.handle_room_message({
		"message_type": TransportMessageTypesScript.ROOM_LEAVE,
		"sender_peer_id": 3,
	})
	runtime.handle_room_message({
		"message_type": TransportMessageTypesScript.ROOM_RESUME_REQUEST,
		"sender_peer_id": 9,
		"room_id": "LegacyMigration_idle_room",
		"member_id": String(member_session.get("member_id", "")),
		"reconnect_token": String(member_session.get("reconnect_token", "")),
		"match_id": "",
		"room_ticket": _make_resume_ticket(9, String(member_session.get("room_id", "LegacyMigration_idle_room")), "").get("token", ""),
		"room_ticket_id": _make_resume_ticket(9, String(member_session.get("room_id", "LegacyMigration_idle_room")), "").get("ticket_id", ""),
		"account_id": "account_3",
		"profile_id": "profile_3",
		"device_session_id": "dsess_9",
	})

	var rejected := _find_message_to_peer(sent, 9, TransportMessageTypesScript.ROOM_RESUME_REJECTED)
	var prefix := "idle_room_resume_returns_to_room_test"
	var ok := true
	ok = qqt_check(not rejected.is_empty(), "manual leave should invalidate member resume session", prefix) and ok
	if not rejected.is_empty():
		ok = qqt_check(String(rejected.get("error", "")) == "MEMBER_NOT_FOUND", "manual leave resume should fail with MEMBER_NOT_FOUND", prefix) and ok

	runtime.free()
	return ok


func _create_message(peer_id: int) -> Dictionary:
	var ticket := _make_ticket(peer_id, "create", "LegacyMigration_idle_room", "")
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "LegacyMigration_idle_room",
		"player_name": "Host",
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _join_message(peer_id: int) -> Dictionary:
	var ticket := _make_ticket(peer_id, "join", "LegacyMigration_idle_room", "")
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "LegacyMigration_idle_room",
		"player_name": "Client",
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _latest_room_snapshot(broadcasts: Array[Dictionary]) -> RoomSnapshot:
	for index in range(broadcasts.size() - 1, -1, -1):
		var message := broadcasts[index]
		if String(message.get("message_type", "")) == TransportMessageTypesScript.ROOM_SNAPSHOT:
			return RoomSnapshot.from_dict(message.get("snapshot", {}))
	return null


func _find_member(snapshot: RoomSnapshot, peer_id: int) -> RoomMemberState:
	for member in snapshot.members:
		if member != null and int(member.peer_id) == peer_id:
			return member
	return null


func _find_message_to_peer(sent: Array[Dictionary], peer_id: int, message_type: String) -> Dictionary:
	for index in range(sent.size() - 1, -1, -1):
		var entry := sent[index]
		if int(entry.get("peer_id", 0)) != peer_id:
			continue
		var message: Dictionary = entry.get("message", {})
		if String(message.get("message_type", "")) == message_type:
			return message
	return {}


func _make_resume_ticket(peer_id: int, room_id: String, match_id: String) -> Dictionary:
	return _make_ticket(peer_id, "resume", room_id, match_id)


func _make_ticket(peer_id: int, purpose: String, room_id: String, match_id: String) -> Dictionary:
	var account_suffix := peer_id
	if purpose == "resume":
		account_suffix = 3
	var payload := {
		"ticket_id": "ticket_%s_%d" % [purpose, peer_id],
		"account_id": "account_%d" % account_suffix,
		"profile_id": "profile_%d" % account_suffix,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": purpose,
		"room_id": "" if purpose == "create" else room_id,
		"room_kind": "private_room" if purpose == "create" else "",
		"requested_match_id": match_id,
		"display_name": "Player%d" % account_suffix,
		"allowed_character_ids": [CharacterCatalogScript.get_default_character_id()],
		"allowed_character_skin_ids": [""],
		"allowed_bubble_style_ids": [BubbleCatalogScript.get_default_bubble_id()],
		"allowed_bubble_skin_ids": [""],
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": int(Time.get_unix_time_from_system()) + 60,
		"nonce": "nonce_%s_%d" % [purpose, peer_id],
	}
	var encoded_payload := _to_base64_url(JSON.stringify(payload).to_utf8_buffer())
	var signature := _sign_ticket(encoded_payload)
	return {
		"token": "%s.%s" % [encoded_payload, signature],
		"ticket_id": String(payload.get("ticket_id", "")),
		"account_id": String(payload.get("account_id", "")),
		"profile_id": String(payload.get("profile_id", "")),
		"device_session_id": String(payload.get("device_session_id", "")),
	}


func _sign_ticket(encoded_payload: String) -> String:
	var crypto := Crypto.new()
	var digest := crypto.hmac_digest(HashingContext.HASH_SHA256, ROOM_TICKET_SECRET.to_utf8_buffer(), encoded_payload.to_utf8_buffer())
	return _to_base64_url(digest)


func _to_base64_url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=")


func _new_server_room_runtime() -> Node:
	if not ResourceLoader.exists(SERVER_ROOM_RUNTIME_PATH):
		return null
	var script = load(SERVER_ROOM_RUNTIME_PATH)
	return script.new() if script != null else null
