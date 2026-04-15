extends Node

const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


class FakePartyQueueClient:
	extends RefCounted
	var enter_count := 0
	var cancel_count := 0

	func enter_party_queue(_request: Dictionary) -> Dictionary:
		enter_count += 1
		return {
			"ok": true,
			"queue_entry_id": "party_queue_alpha",
			"queue_status_text": "Queueing",
		}

	func cancel_party_queue(_party_room_id: String, _queue_entry_id: String) -> Dictionary:
		cancel_count += 1
		return {"ok": true}


func _ready() -> void:
	var service := ServerRoomServiceScript.new()
	add_child(service)
	var client := FakePartyQueueClient.new()
	service.configure_party_queue_client(client)
	service.room_state.ensure_room("ROOM-QUEUE", 1, "ranked_match_room", "")
	service.room_state.match_format_id = "2v2"
	service.room_state.required_party_size = 2
	service.room_state.selected_match_mode_ids = ["mode_classic"]
	service.room_state.upsert_member(1, "Host", "character_default", "", "bubble_style_default", "", 1, "account_1", "profile_1", "dsess_1")

	var prefix := "match_room_queue_guard_test"
	var ok := true
	ok = TestAssert.is_true(not service.room_state.can_enter_match_queue(1), "2v2 room with one member cannot queue", prefix) and ok

	service.room_state.upsert_member(2, "Guest", "character_default", "", "bubble_style_default", "", 1, "account_2", "profile_2", "dsess_2")
	service.room_state.set_ready(1, true)
	ok = TestAssert.is_true(not service.room_state.can_enter_match_queue(1), "not-ready guest should block queue", prefix) and ok
	service.room_state.set_ready(2, true)
	ok = TestAssert.is_true(service.room_state.can_enter_match_queue(1), "full ready party should allow queue", prefix) and ok

	service.handle_message({
		"message_type": "ROOM_ENTER_MATCH_QUEUE",
		"sender_peer_id": 1,
	})
	ok = TestAssert.is_true(String(service.room_state.room_queue_state) == "queueing", "enter queue should set queueing state", prefix) and ok
	ok = TestAssert.is_true(String(service.room_state.room_queue_entry_id) == "party_queue_alpha", "enter queue should store queue entry id", prefix) and ok

	service.handle_message({
		"message_type": "ROOM_LEAVE",
		"sender_peer_id": 2,
	})
	ok = TestAssert.is_true(client.cancel_count == 1, "leaving while queueing should cancel backend party queue", prefix) and ok
	ok = TestAssert.is_true(String(service.room_state.room_queue_state) == "cancelled", "leaving while queueing should mark local queue cancelled", prefix) and ok
	service.queue_free()
	if ok:
		print("match_room_queue_guard_test: PASS")
	test_finished.emit()
