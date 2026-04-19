extends "res://tests/gut/base/qqt_unit_test.gd"

const ServerRoomServiceScript = preload("res://network/session/legacy/server_room_service.gd")



func test_main() -> void:
	var service := ServerRoomServiceScript.new()
	add_child(service)
	var sent_messages: Array[Dictionary] = []
	service.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		sent_messages.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)
	service.room_state.ensure_room("ROOM-CONFIG", 1, "casual_match_room", "")
	service.room_state.match_format_id = "2v2"
	service.room_state.required_party_size = 2
	service.room_state.selected_match_mode_ids = ["mode_classic"]
	service.room_state.room_queue_state = "queueing"

	service.handle_message({
		"message_type": "ROOM_UPDATE_MATCH_ROOM_CONFIG",
		"sender_peer_id": 1,
		"match_format_id": "1v1",
		"selected_mode_ids": ["mode_classic"],
	})

	var latest : Dictionary = sent_messages.back().get("message", {}) if not sent_messages.is_empty() else {}
	var prefix := "match_room_config_guard_test"
	var ok := true
	ok = qqt_check(String(service.room_state.match_format_id) == "2v2", "queueing room should keep previous format", prefix) and ok
	ok = qqt_check(service.room_state.selected_match_mode_ids == ["mode_classic"], "queueing room should keep previous mode pool", prefix) and ok
	ok = qqt_check(String(latest.get("message_type", "")) == "ROOM_MATCH_QUEUE_STATUS", "config guard should send queue status", prefix) and ok
	ok = qqt_check(String(latest.get("error_code", "")) == "MATCH_ROOM_CONFIG_FORBIDDEN", "config guard should reject while queueing", prefix) and ok
	service.queue_free()

