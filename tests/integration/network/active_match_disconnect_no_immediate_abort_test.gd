extends Node

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")
const ServerRoomRuntimeScript = preload("res://network/session/runtime/server_room_runtime.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ROOM_TICKET_SECRET := "dev_room_ticket_secret"


func _ready() -> void:
	var ok := true
	ok = _test_active_match_disconnect_enters_resume_window() and ok
	ok = _test_resume_accept_uses_new_transport_and_old_control_peer() and ok
	if ok:
		print("active_match_disconnect_no_immediate_abort_test: PASS")


func _test_active_match_disconnect_enters_resume_window() -> bool:
	var fixture := _start_active_match()
	var runtime: ServerRoomRuntime = fixture["runtime"]
	var broadcasts: Array[Dictionary] = fixture["broadcasts"]
	var prefix := "active_match_disconnect_no_immediate_abort_test"
	var ok := true

	ok = TestAssert.is_true(runtime.is_match_active(), "match should be active before disconnect", prefix) and ok
	runtime.handle_peer_disconnected(3)
	ok = TestAssert.is_true(runtime.is_match_active(), "active match disconnect should not immediately abort", prefix) and ok

	var snapshot := _latest_room_snapshot(broadcasts)
	ok = TestAssert.is_true(snapshot != null, "disconnect should broadcast a room snapshot", prefix) and ok
	if snapshot != null:
		var member := _find_member(snapshot, 3)
		ok = TestAssert.is_true(member != null, "disconnected member should remain in snapshot", prefix) and ok
		if member != null:
			ok = TestAssert.is_true(member.connection_state == "disconnected", "member connection_state should be disconnected", prefix) and ok

	runtime.queue_free()
	return ok


func _test_resume_accept_uses_new_transport_and_old_control_peer() -> bool:
	var fixture := _start_active_match()
	var runtime: ServerRoomRuntime = fixture["runtime"]
	var sent: Array[Dictionary] = fixture["sent"]
	var prefix := "active_match_disconnect_no_immediate_abort_test"
	var ok := true

	var member_session := _find_member_session(sent, 3)
	ok = TestAssert.is_true(not member_session.is_empty(), "peer should receive member session", prefix) and ok
	runtime.handle_peer_disconnected(3)
	var resume_ticket := _make_ticket(9, "resume", "phase17_room", String(fixture["match_id"]))
	runtime.handle_room_message({
		"message_type": TransportMessageTypesScript.ROOM_RESUME_REQUEST,
		"sender_peer_id": 9,
		"room_id": "phase17_room",
		"member_id": String(member_session.get("member_id", "")),
		"reconnect_token": String(member_session.get("reconnect_token", "")),
		"match_id": String(fixture["match_id"]),
		"room_ticket": resume_ticket.get("token", ""),
		"room_ticket_id": resume_ticket.get("ticket_id", ""),
		"account_id": resume_ticket.get("account_id", ""),
		"profile_id": resume_ticket.get("profile_id", ""),
		"device_session_id": resume_ticket.get("device_session_id", ""),
	})

	var accepted := _find_message_to_peer(sent, 9, TransportMessageTypesScript.MATCH_RESUME_ACCEPTED)
	ok = TestAssert.is_true(not accepted.is_empty(), "resume request should receive MATCH_RESUME_ACCEPTED", prefix) and ok
	if not accepted.is_empty():
		var start_config: Dictionary = accepted.get("start_config", {})
		var resume_snapshot: Dictionary = accepted.get("resume_snapshot", {})
		ok = TestAssert.is_true(int(start_config.get("local_peer_id", 0)) == 9, "resume config local_peer_id should be new transport peer", prefix) and ok
		ok = TestAssert.is_true(int(start_config.get("controlled_peer_id", 0)) == 3, "resume config controlled_peer_id should stay on original battle peer", prefix) and ok
		ok = TestAssert.is_true(int(resume_snapshot.get("controlled_peer_id", 0)) == 3, "resume snapshot should preserve controlled peer", prefix) and ok
		ok = TestAssert.is_true(not Dictionary(resume_snapshot.get("checkpoint_message", {})).is_empty(), "resume snapshot should include checkpoint payload", prefix) and ok

	runtime.queue_free()
	return ok


func _start_active_match() -> Dictionary:
	var runtime := ServerRoomRuntimeScript.new()
	add_child(runtime)
	runtime.configure("127.0.0.1", 9000)

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
	runtime.handle_room_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 2})
	runtime.handle_room_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 3})
	runtime.handle_room_message({"message_type": TransportMessageTypesScript.ROOM_START_REQUEST, "sender_peer_id": 2})

	var loading_snapshot := _latest_loading_snapshot(broadcasts)
	runtime.handle_loading_message({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
		"sender_peer_id": 2,
		"match_id": String(loading_snapshot.get("match_id", "")),
		"revision": int(loading_snapshot.get("revision", 0)),
	})
	runtime.handle_loading_message({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
		"sender_peer_id": 3,
		"match_id": String(loading_snapshot.get("match_id", "")),
		"revision": int(loading_snapshot.get("revision", 0)),
	})

	return {
		"runtime": runtime,
		"sent": sent,
		"broadcasts": broadcasts,
		"match_id": String(loading_snapshot.get("match_id", "")),
	}


func _create_message(peer_id: int) -> Dictionary:
	var ticket := _make_ticket(peer_id, "create", "phase17_room", "")
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "phase17_room",
		"player_name": "Host",
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"map_id": MapCatalogScript.get_default_map_id(),
		"rule_set_id": RuleSetCatalogScript.get_default_rule_id(),
		"mode_id": ModeCatalogScript.get_default_mode_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _join_message(peer_id: int) -> Dictionary:
	var ticket := _make_ticket(peer_id, "join", "phase17_room", "")
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "phase17_room",
		"player_name": "Client",
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _latest_loading_snapshot(broadcasts: Array[Dictionary]) -> Dictionary:
	for index in range(broadcasts.size() - 1, -1, -1):
		var message := broadcasts[index]
		if String(message.get("message_type", "")) == TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT:
			return Dictionary(message.get("snapshot", {}))
	return {}


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


func _find_member_session(sent: Array[Dictionary], peer_id: int) -> Dictionary:
	return _find_message_to_peer(sent, peer_id, TransportMessageTypesScript.ROOM_MEMBER_SESSION)


func _find_message_to_peer(sent: Array[Dictionary], peer_id: int, message_type: String) -> Dictionary:
	for index in range(sent.size() - 1, -1, -1):
		var entry := sent[index]
		if int(entry.get("peer_id", 0)) != peer_id:
			continue
		var message: Dictionary = entry.get("message", {})
		if String(message.get("message_type", "")) == message_type:
			return message
	return {}


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
