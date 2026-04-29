extends "res://tests/gut/base/qqt_unit_test.gd"

const AuthorityBatchCoalescerScript = preload("res://network/session/runtime/authority_batch_coalescer.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_coalesces_multiple_snapshots_to_latest_useful_snapshot() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var batch := coalescer.coalesce_client_authority_batch([
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 100),
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 105),
		_snapshot(TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT, 106),
	], {})

	assert_eq(int(batch["latest_snapshot_message"].get("tick", 0)), 106)
	assert_eq(batch["dropped_snapshot_ticks"], PackedInt32Array([100, 105]))
	assert_eq(int(batch["metrics"].get("raw_checkpoint_count", 0)), 2)
	assert_eq(int(batch["metrics"].get("raw_auth_snapshot_count", 0)), 1)
	assert_eq(int(batch["metrics"].get("dropped_intermediate_snapshot_count", 0)), 2)


func test_drops_stale_snapshots_by_cursor() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var batch := coalescer.coalesce_client_authority_batch([
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 100),
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 101),
	], {
		"latest_authoritative_tick": 100,
		"latest_snapshot_tick": 99,
	})

	assert_eq(int(batch["latest_snapshot_message"].get("tick", 0)), 101)
	assert_eq(batch["dropped_snapshot_ticks"], PackedInt32Array([100]))
	assert_eq(int(batch["metrics"].get("dropped_stale_snapshot_count", 0)), 1)


func test_preserves_events_from_intermediate_snapshots() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var batch := coalescer.coalesce_client_authority_batch([
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 100, [{"tick": 100, "name": "a"}]),
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 105, [{"tick": 105, "name": "b"}]),
		{
			"message_type": TransportMessageTypesScript.STATE_SUMMARY,
			"tick": 103,
			"events": [{"tick": 103, "name": "summary"}],
		},
		_snapshot(TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT, 106, [{"tick": 106, "name": "c"}]),
	], {})

	var events_by_tick: Array = batch["authority_events_by_tick"]
	assert_eq(events_by_tick.size(), 4)
	assert_eq(int(events_by_tick[0]["tick"]), 100)
	assert_eq(String(events_by_tick[1]["events"][0]["name"]), "summary")
	assert_eq(String(events_by_tick[2]["events"][0]["name"]), "b")
	assert_eq(String(events_by_tick[3]["events"][0]["name"]), "c")


func test_keeps_max_ack_per_peer() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var batch := coalescer.coalesce_client_authority_batch([
		_ack(2, 10),
		_ack(2, 12),
		_ack(3, 7),
		_ack(2, 11),
	], {})

	var acks: Array = batch["input_acks"]
	assert_eq(acks.size(), 2)
	assert_eq(int(acks[0]["peer_id"]), 2)
	assert_eq(int(acks[0]["ack_tick"]), 12)
	assert_eq(int(acks[1]["peer_id"]), 3)
	assert_eq(int(acks[1]["ack_tick"]), 7)
	assert_eq(int(batch["metrics"].get("raw_ack_count", 0)), 4)
	assert_eq(int(batch["metrics"].get("coalesced_ack_count", 0)), 2)


func test_keeps_latest_state_summary() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var batch := coalescer.coalesce_client_authority_batch([
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 8, "value": "old"},
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 9, "value": "new"},
	], {})

	assert_eq(int(batch["latest_state_summary"].get("tick", 0)), 9)
	assert_eq(String(batch["latest_state_summary"].get("value", "")), "new")
	assert_eq(int(batch["metrics"].get("raw_summary_count", 0)), 2)
	assert_eq(int(batch["metrics"].get("dropped_intermediate_summary_count", 0)), 1)
	assert_eq(int(batch["metrics"].get("coalesced_summary_tick", 0)), 9)


func test_drops_stale_state_summaries_by_cursor() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var batch := coalescer.coalesce_client_authority_batch([
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 100, "value": "stale"},
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 101, "value": "latest"},
	], {
		"latest_authoritative_tick": 100,
	})

	assert_eq(int(batch["latest_state_summary"].get("tick", 0)), 101)
	assert_eq(String(batch["latest_state_summary"].get("value", "")), "latest")
	assert_eq(int(batch["metrics"].get("dropped_stale_summary_count", 0)), 1)


func test_deduplicates_events_by_event_id() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var batch := coalescer.coalesce_client_authority_batch([
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 10, "events": [
			{"tick": 10, "event_id": "same", "name": "first"},
		]},
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 11, "events": [
			{"tick": 11, "event_id": "same", "name": "duplicate"},
			{"tick": 11, "event_id": "other", "name": "second"},
		]},
	], {})

	var events_by_tick: Array = batch["authority_events_by_tick"]
	assert_eq(events_by_tick.size(), 2)
	assert_eq(String(events_by_tick[0]["events"][0]["name"]), "first")
	assert_eq(String(events_by_tick[1]["events"][0]["name"]), "second")
	assert_eq(int(batch["metrics"].get("preserved_event_count", 0)), 2)


func test_preserves_event_details_and_deduplicates_against_short_summary_event() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var short_event := {
		"tick": 14,
		"event_type": 3,
		"payload": {"bubble_id": 2, "cell_x": 6, "cell_y": 7},
	}
	var full_event := {
		"tick": 14,
		"event_type": 3,
		"payload": {
			"bubble_id": 2,
			"cell_x": 6,
			"cell_y": 7,
			"covered_cells": [Vector2i(6, 7), Vector2i(7, 7)],
		},
	}
	var batch := coalescer.coalesce_client_authority_batch([
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 14, "events": [short_event]},
		{"message_type": TransportMessageTypesScript.STATE_DELTA, "tick": 14, "event_details": [full_event]},
	], {})

	var events_by_tick: Array = batch["authority_events_by_tick"]
	assert_eq(events_by_tick.size(), 1)
	var payload: Dictionary = (events_by_tick[0]["events"][0] as Dictionary).get("payload", {})
	assert_eq((payload.get("covered_cells", []) as Array).size(), 2)


func test_preserves_match_finished_as_terminal_message() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var batch := coalescer.coalesce_client_authority_batch([
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 9),
		{"message_type": TransportMessageTypesScript.MATCH_FINISHED, "tick": 10, "result": {"finish_reason": "force_end"}},
	], {})

	assert_eq(batch["terminal_messages"].size(), 1)
	assert_eq(String(batch["terminal_messages"][0].get("message_type", "")), TransportMessageTypesScript.MATCH_FINISHED)
	assert_eq(int(batch["metrics"].get("terminal_message_count", 0)), 1)


func test_routes_non_authority_messages_as_passthrough() -> void:
	var coalescer := AuthorityBatchCoalescerScript.new()
	var batch := coalescer.coalesce_client_authority_batch([
		{"message_type": TransportMessageTypesScript.MATCH_START, "tick": 1},
		{"message_type": TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED, "tick": 1},
	], {})

	assert_eq(batch["passthrough_messages"].size(), 2)
	assert_eq(String(batch["passthrough_messages"][0].get("message_type", "")), TransportMessageTypesScript.MATCH_START)
	assert_eq(int(batch["metrics"].get("passthrough_message_count", 0)), 2)


func _snapshot(message_type: String, tick: int, events: Array = []) -> Dictionary:
	return {
		"message_type": message_type,
		"tick": tick,
		"players": [],
		"bubbles": [],
		"items": [],
		"events": events,
	}


func _ack(peer_id: int, ack_tick: int) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.INPUT_ACK,
		"peer_id": peer_id,
		"ack_tick": ack_tick,
	}
