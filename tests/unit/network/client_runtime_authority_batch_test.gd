extends "res://tests/gut/base/qqt_unit_test.gd"

const ClientRuntimeScript = preload("res://network/session/runtime/client_runtime.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_ingest_authority_batch_applies_max_ack_once() -> void:
	var runtime := _runtime_with_session(7)
	runtime.ingest_authority_batch({
		"input_acks": [
			{"message_type": TransportMessageTypesScript.INPUT_ACK, "peer_id": 7, "ack_tick": 12},
		],
		"metrics": {},
	})

	assert_eq(runtime.client_session.last_confirmed_tick, 12)
	runtime.queue_free()


func test_ingest_state_summary_applies_merged_ack_by_peer() -> void:
	var runtime := _runtime_with_session(7)
	runtime.ingest_network_message({
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 12,
		"ack_by_peer": {7: 12},
		"player_summary": {},
		"events": [],
	})

	assert_eq(runtime.client_session.last_confirmed_tick, 12)
	runtime.queue_free()


func test_ingest_state_summary_applies_ack_by_peer_fallback_when_ids_are_transport_scoped() -> void:
	var runtime := _runtime_with_session(243214422)
	runtime.configure_controlled_peer(9)
	runtime.ingest_network_message({
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 15,
		"ack_by_peer": {1: 15, 2: 14},
		"player_summary": {},
		"events": [],
	})

	assert_eq(runtime.client_session.last_confirmed_tick, 15)
	runtime.queue_free()


func test_ingest_input_ack_batch_applies_ack_by_peer() -> void:
	var runtime := _runtime_with_session(7)
	runtime.ingest_network_message({
		"message_type": TransportMessageTypesScript.INPUT_ACK_BATCH,
		"ack_by_peer": {7: 16},
	})

	assert_eq(runtime.client_session.last_confirmed_tick, 16)
	runtime.queue_free()


func test_ingest_authority_batch_runs_one_rollback_for_latest_snapshot() -> void:
	var runtime := _runtime_with_session(7)
	runtime.ingest_authority_batch({
		"latest_snapshot_message": _snapshot(42),
		"metrics": {"coalesced_snapshot_tick": 42},
	})

	assert_eq(runtime.client_session.latest_snapshot_tick, 42)
	assert_eq(int(runtime.get_last_authority_batch_metrics().get("coalesced_snapshot_tick", 0)), 42)
	runtime.queue_free()


func test_ingest_authority_batch_preserves_events_by_tick() -> void:
	var runtime := _runtime_with_session(7)
	runtime.ingest_authority_batch({
		"authority_events_by_tick": [
			{"tick": 3, "events": [{"tick": 3, "event_type": SimEvent.EventType.BUBBLE_PLACED, "payload": {"bubble_id": 1}}]},
			{"tick": 5, "events": [{"tick": 5, "event_type": SimEvent.EventType.BUBBLE_EXPLODED, "payload": {"bubble_id": 1}}]},
		],
		"metrics": {},
	})

	var events := runtime.consume_pending_authoritative_events()
	assert_eq(events.size(), 2)
	assert_eq(int(events[0].event_type), SimEvent.EventType.BUBBLE_PLACED)
	assert_eq(int(events[1].event_type), SimEvent.EventType.BUBBLE_EXPLODED)
	assert_eq(runtime.consume_pending_authoritative_events().size(), 0)
	runtime.queue_free()


func test_ingest_authority_batch_applies_terminal_after_snapshot() -> void:
	var runtime := _runtime_with_session(7)
	runtime.ingest_authority_batch({
		"latest_snapshot_message": _snapshot(9),
		"terminal_messages": [
			{
				"message_type": TransportMessageTypesScript.MATCH_FINISHED,
				"tick": 10,
				"result": {"finish_reason": "force_end", "finish_tick": 10},
			},
		],
		"metrics": {},
	})

	assert_eq(runtime.client_session.latest_snapshot_tick, 9)
	assert_false(runtime.is_active())
	runtime.queue_free()


func test_ingest_ignores_authority_world_updates_after_match_finished() -> void:
	var runtime := _runtime_with_session(7)
	runtime.ingest_network_message({
		"message_type": TransportMessageTypesScript.MATCH_FINISHED,
		"tick": 10,
		"result": {"finish_reason": "force_end", "finish_tick": 10},
	})
	runtime.ingest_network_message(_snapshot(11))

	assert_eq(runtime.client_session.latest_snapshot_tick, 0)
	assert_false(runtime.is_active())
	runtime.queue_free()


func _runtime_with_session(peer_id: int) -> ClientRuntime:
	var runtime: ClientRuntime = ClientRuntimeScript.new()
	runtime.configure(peer_id)
	runtime.configure_controlled_peer(peer_id)
	runtime.client_session = ClientSession.new()
	runtime.client_session.configure(peer_id, peer_id)
	runtime._active = true
	return runtime


func _snapshot(tick: int) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.CHECKPOINT,
		"tick": tick,
		"players": [],
		"bubbles": [],
		"items": [],
		"walls": [],
		"events": [],
	}
