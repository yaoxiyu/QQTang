extends Node

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const ServerRoomRuntimeScript = preload("res://network/session/runtime/server_room_runtime.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func _ready() -> void:
	var ok := true
	ok = _test_idle_room_resume_returns_to_room_snapshot() and ok
	ok = _test_manual_leave_invalidates_room_member_session() and ok
	ok = _test_idle_room_resume_window_expiry_removes_member_session() and ok
	if ok:
		print("idle_room_resume_returns_to_room_test: PASS")


func _test_idle_room_resume_returns_to_room_snapshot() -> bool:
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
	var member_session := _find_message_to_peer(sent, 3, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	runtime.handle_peer_disconnected(3)
	runtime.handle_room_message({
		"message_type": TransportMessageTypesScript.ROOM_RESUME_REQUEST,
		"sender_peer_id": 9,
		"room_id": "phase17_idle_room",
		"member_id": String(member_session.get("member_id", "")),
		"reconnect_token": String(member_session.get("reconnect_token", "")),
		"match_id": "",
	})

	var prefix := "idle_room_resume_returns_to_room_test"
	var ok := true
	var accepted := _find_message_to_peer(sent, 9, TransportMessageTypesScript.ROOM_JOIN_ACCEPTED)
	var resume_rejected := _find_message_to_peer(sent, 9, TransportMessageTypesScript.ROOM_RESUME_REJECTED)
	var match_resume := _find_message_to_peer(sent, 9, TransportMessageTypesScript.MATCH_RESUME_ACCEPTED)
	ok = TestAssert.is_true(not accepted.is_empty(), "idle resume should receive ROOM_JOIN_ACCEPTED", prefix) and ok
	ok = TestAssert.is_true(resume_rejected.is_empty(), "idle resume should not be rejected", prefix) and ok
	ok = TestAssert.is_true(match_resume.is_empty(), "idle resume should not enter active match resume", prefix) and ok

	var snapshot := _latest_room_snapshot(broadcasts)
	ok = TestAssert.is_true(snapshot != null, "idle resume should broadcast room snapshot", prefix) and ok
	if snapshot != null:
		var resumed_member := _find_member(snapshot, 9)
		ok = TestAssert.is_true(resumed_member != null, "room snapshot should show resumed transport peer", prefix) and ok
		if resumed_member != null:
			ok = TestAssert.is_true(resumed_member.connection_state == "connected", "resumed member should be connected", prefix) and ok
		ok = TestAssert.is_true(not snapshot.match_active, "idle resume should stay in room state", prefix) and ok

	runtime.free()
	return ok


func _test_idle_room_resume_window_expiry_removes_member_session() -> bool:
	var runtime := ServerRoomRuntimeScript.new()
	add_child(runtime)
	runtime.configure("127.0.0.1", 9000)

	var sent: Array[Dictionary] = []
	runtime.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)

	runtime.create_room_from_request(_create_message(2))
	runtime.handle_room_message(_join_message(3))
	var member_session := _find_message_to_peer(sent, 3, TransportMessageTypesScript.ROOM_MEMBER_SESSION)
	runtime.handle_peer_disconnected(3)
	var binding := runtime._room_service.room_state.get_member_binding_by_member_id(String(member_session.get("member_id", "")))
	if binding != null:
		binding.disconnect_deadline_msec = 1
	runtime._room_service.poll_idle_resume_expired()
	runtime.handle_room_message({
		"message_type": TransportMessageTypesScript.ROOM_RESUME_REQUEST,
		"sender_peer_id": 9,
		"room_id": "phase17_idle_room",
		"member_id": String(member_session.get("member_id", "")),
		"reconnect_token": String(member_session.get("reconnect_token", "")),
		"match_id": "",
	})

	var rejected := _find_message_to_peer(sent, 9, TransportMessageTypesScript.ROOM_RESUME_REJECTED)
	var prefix := "idle_room_resume_returns_to_room_test"
	var ok := true
	ok = TestAssert.is_true(not rejected.is_empty(), "expired idle resume session should be rejected", prefix) and ok
	if not rejected.is_empty():
		ok = TestAssert.is_true(String(rejected.get("error", "")) == "MEMBER_NOT_FOUND", "expired idle session should be removed", prefix) and ok

	runtime.free()
	return ok


func _test_manual_leave_invalidates_room_member_session() -> bool:
	var runtime := ServerRoomRuntimeScript.new()
	add_child(runtime)
	runtime.configure("127.0.0.1", 9000)

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
		"room_id": "phase17_idle_room",
		"member_id": String(member_session.get("member_id", "")),
		"reconnect_token": String(member_session.get("reconnect_token", "")),
		"match_id": "",
	})

	var rejected := _find_message_to_peer(sent, 9, TransportMessageTypesScript.ROOM_RESUME_REJECTED)
	var prefix := "idle_room_resume_returns_to_room_test"
	var ok := true
	ok = TestAssert.is_true(not rejected.is_empty(), "manual leave should invalidate member resume session", prefix) and ok
	if not rejected.is_empty():
		ok = TestAssert.is_true(String(rejected.get("error", "")) == "MEMBER_NOT_FOUND", "manual leave resume should fail with MEMBER_NOT_FOUND", prefix) and ok

	runtime.free()
	return ok


func _create_message(peer_id: int) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "phase17_idle_room",
		"player_name": "Host",
		"character_id": CharacterCatalogScript.get_default_character_id(),
	}


func _join_message(peer_id: int) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "phase17_idle_room",
		"player_name": "Client",
		"character_id": CharacterCatalogScript.get_default_character_id(),
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
