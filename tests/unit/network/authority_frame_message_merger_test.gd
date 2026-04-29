extends "res://tests/gut/base/qqt_unit_test.gd"

const AuthorityFrameMessageMergerScript = preload("res://network/session/runtime/authority_frame_message_merger.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_keeps_latest_state_summary() -> void:
	var merger := AuthorityFrameMessageMergerScript.new()
	var result := merger.merge_server_frame([
		_state_summary(1),
		_state_summary(2),
		_state_summary(3),
	])

	assert_eq(result.size(), 1)
	assert_eq(int(result[0].get("tick", 0)), 3)


func test_merges_ack_by_peer_into_latest_summary() -> void:
	var merger := AuthorityFrameMessageMergerScript.new()
	var result := merger.merge_server_frame([
		_ack(2, 10),
		_ack(2, 12),
		_ack(3, 7),
		_state_summary(20),
	])

	var acks: Dictionary = result[0].get("ack_by_peer", {})
	assert_eq(int(acks.get(2, 0)), 12)
	assert_eq(int(acks.get(3, 0)), 7)


func test_keeps_latest_checkpoint() -> void:
	var merger := AuthorityFrameMessageMergerScript.new()
	var result := merger.merge_server_frame([
		_checkpoint(5),
		_checkpoint(10),
		_checkpoint(15),
	])

	assert_eq(result.size(), 1)
	assert_eq(int(result[0].get("tick", 0)), 15)


func test_preserves_events_when_summary_is_coalesced() -> void:
	var merger := AuthorityFrameMessageMergerScript.new()
	var result := merger.merge_server_frame([
		_state_summary(10, [{"tick": 10, "event_id": "a", "name": "placed"}]),
		_state_summary(11, [{"tick": 11, "event_id": "b", "name": "exploded"}]),
		_state_summary(12),
	])

	var events: Array = result[0].get("events", [])
	assert_eq(int(result[0].get("tick", 0)), 12)
	assert_eq(events.size(), 2)
	assert_eq(String(events[0].get("name", "")), "placed")
	assert_eq(String(events[1].get("name", "")), "exploded")


func test_preserves_latest_delta_and_prefers_full_delta_event_payload() -> void:
	var merger := AuthorityFrameMessageMergerScript.new()
	var short_event := {
		"tick": 20,
		"event_type": 3,
		"payload": {"bubble_id": 7, "cell_x": 4, "cell_y": 5},
	}
	var full_event := {
		"tick": 20,
		"event_type": 3,
		"payload": {
			"bubble_id": 7,
			"cell_x": 4,
			"cell_y": 5,
			"covered_cells": [Vector2i(4, 5), Vector2i(5, 5)],
		},
	}
	var result := merger.merge_server_frame([
		_state_summary(20, [short_event]),
		{
			"message_type": TransportMessageTypesScript.STATE_DELTA,
			"tick": 20,
			"event_details": [full_event],
			"removed_bubble_ids": [7],
		},
	])

	assert_eq(result.size(), 2)
	assert_eq(String(result[1].get("message_type", "")), TransportMessageTypesScript.STATE_DELTA)
	var events: Array = result[0].get("events", [])
	assert_eq(events.size(), 1)
	var payload: Dictionary = (events[0] as Dictionary).get("payload", {})
	assert_eq((payload.get("covered_cells", []) as Array).size(), 2)


func test_preserves_terminal_messages_at_end() -> void:
	var merger := AuthorityFrameMessageMergerScript.new()
	var result := merger.merge_server_frame([
		_state_summary(100),
		{"message_type": TransportMessageTypesScript.MATCH_FINISHED, "tick": 100},
	])

	assert_eq(result.size(), 2)
	assert_eq(String(result[1].get("message_type", "")), TransportMessageTypesScript.MATCH_FINISHED)


func _state_summary(tick: int, events: Array = []) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": tick,
		"events": events,
	}


func _checkpoint(tick: int) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.CHECKPOINT,
		"tick": tick,
	}


func _ack(peer_id: int, ack_tick: int) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.INPUT_ACK,
		"peer_id": peer_id,
		"ack_tick": ack_tick,
	}
