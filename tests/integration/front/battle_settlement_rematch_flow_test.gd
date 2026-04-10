extends Node

const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func _ready() -> void:
	var ok := true
	ok = _test_rematch_request_from_non_owner_rejected() and ok
	ok = _test_rematch_request_from_owner_succeeds() and ok
	ok = _test_rematch_rejected_when_match_active() and ok
	if ok:
		print("battle_settlement_rematch_flow_test: PASS")


func _test_rematch_request_from_non_owner_rejected() -> bool:
	var service := ServerRoomServiceScript.new()
	var sent_messages := []

	service.send_to_peer.connect(func(peer_id, msg): sent_messages.append({"peer_id": peer_id, "msg": msg}))
	service.broadcast_message.connect(func(_msg): pass)

	service.room_state.ensure_room("test_room", 1, "private_room", "Test Room")
	service.room_state.upsert_member(1, "Host", "char_001", "", "bubble_001", "")
	service.room_state.upsert_member(2, "Player2", "char_002", "", "bubble_002", "")

	service.handle_message({
		"message_type": TransportMessageTypesScript.ROOM_REMATCH_REQUEST,
		"sender_peer_id": 2,
	})

	if sent_messages.size() != 1:
		print("FAIL: non-owner rematch should send 1 rejection message")
		return false
	if sent_messages[0]["msg"]["message_type"] != TransportMessageTypesScript.ROOM_REMATCH_REJECTED:
		print("FAIL: non-owner rematch should be rejected")
		return false
	if sent_messages[0]["msg"]["error"] != "REMATCH_FORBIDDEN":
		print("FAIL: non-owner rematch error should be REMATCH_FORBIDDEN")
		service.free()
		return false
	service.free()
	return true


func _test_rematch_request_from_owner_succeeds() -> bool:
	var service := ServerRoomServiceScript.new()
	var sent_messages := []
	var broadcasted := []
	var start_match_called := [false]

	service.send_to_peer.connect(func(peer_id, msg): sent_messages.append({"peer_id": peer_id, "msg": msg}))
	service.broadcast_message.connect(func(msg): broadcasted.append(msg))
	service.start_match_requested.connect(func(_snapshot): start_match_called[0] = true)

	service.room_state.ensure_room("test_room", 1, "private_room", "Test Room")
	service.room_state.upsert_member(1, "Host", "char_001", "", "bubble_001", "")
	service.room_state.upsert_member(2, "Player2", "char_002", "", "bubble_002", "")
	service.room_state.match_active = false

	service.handle_message({
		"message_type": TransportMessageTypesScript.ROOM_REMATCH_REQUEST,
		"sender_peer_id": 1,
	})

	if sent_messages.size() != 0:
		print("FAIL: owner rematch should not send rejection, got ", sent_messages.size())
		return false
	if broadcasted.size() != 1:
		print("FAIL: owner rematch should broadcast 1 snapshot")
		return false
	if broadcasted[0]["message_type"] != TransportMessageTypesScript.ROOM_SNAPSHOT:
		print("FAIL: owner rematch broadcast should be ROOM_SNAPSHOT")
		return false
	if not start_match_called[0]:
		print("FAIL: owner rematch should emit start_match_requested")
		return false
	if not service.room_state.match_active:
		print("FAIL: owner rematch should set match_active to true")
		return false
	if not service.room_state.members[1].ready:
		print("FAIL: owner rematch should set member 1 ready to true")
		return false
	if not service.room_state.members[2].ready:
		print("FAIL: owner rematch should set member 2 ready to true")
		service.free()
		return false
	service.free()
	return true


func _test_rematch_rejected_when_match_active() -> bool:
	var service := ServerRoomServiceScript.new()
	var sent_messages := []

	service.send_to_peer.connect(func(peer_id, msg): sent_messages.append({"peer_id": peer_id, "msg": msg}))
	service.broadcast_message.connect(func(_msg): pass)

	service.room_state.ensure_room("test_room", 1, "private_room", "Test Room")
	service.room_state.upsert_member(1, "Host", "char_001", "", "bubble_001", "")
	service.room_state.upsert_member(2, "Player2", "char_002", "", "bubble_002", "")
	service.room_state.match_active = true

	service.handle_message({
		"message_type": TransportMessageTypesScript.ROOM_REMATCH_REQUEST,
		"sender_peer_id": 1,
	})

	if sent_messages.size() != 1:
		print("FAIL: rematch during active match should send 1 rejection")
		return false
	if sent_messages[0]["msg"]["message_type"] != TransportMessageTypesScript.ROOM_REMATCH_REJECTED:
		print("FAIL: rematch during active match should be rejected")
		return false
	if sent_messages[0]["msg"]["error"] != "MATCH_ALREADY_ACTIVE":
		print("FAIL: rematch during active match error should be MATCH_ALREADY_ACTIVE")
		service.free()
		return false
	service.free()
	return true
