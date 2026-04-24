extends QQTIntegrationTest

const NativeAuthorityBatchBridgeScript = preload("res://gameplay/native_bridge/native_authority_batch_bridge.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_client_authority_burst_coalesces_to_one_snapshot_and_preserves_events() -> void:
	var bridge: RefCounted = NativeAuthorityBatchBridgeScript.new()
	var messages := _burst_messages(30)
	var batch: Dictionary = bridge.coalesce_client_authority_batch(messages, {
		"latest_authoritative_tick": 99,
		"latest_snapshot_tick": 99,
		"controlled_peer_id": 2,
		"local_peer_id": 2,
	})
	var runtime := ClientRuntime.new()
	runtime.configure(2)
	runtime.configure_controlled_peer(2)
	runtime.client_session = ClientSession.new()
	runtime.client_session.configure(2, 2)
	runtime._active = true

	runtime.ingest_authority_batch(batch)
	var events := runtime.consume_pending_authoritative_events()
	var metrics: Dictionary = batch["metrics"]

	assert_eq(int(runtime.client_session.latest_snapshot_tick), 129)
	assert_eq(int(runtime.client_session.last_confirmed_tick), 127)
	assert_eq(int(metrics.get("raw_checkpoint_count", 0)), 10)
	assert_eq(int(metrics.get("raw_summary_count", 0)), 10)
	assert_eq(int(metrics.get("raw_ack_count", 0)), 10)
	assert_eq(int(metrics.get("coalesced_snapshot_tick", 0)), 129)
	assert_eq(int(metrics.get("dropped_intermediate_snapshot_count", 0)), 9)
	assert_eq(events.size(), 20)
	assert_true(bool(metrics.get("native_shadow_equal", false)))
	runtime.queue_free()


func _burst_messages(count: int) -> Array:
	var messages: Array = []
	for index in range(count):
		var tick := 100 + index
		match index % 3:
			0:
				messages.append({
					"message_type": TransportMessageTypesScript.INPUT_ACK,
					"peer_id": 2,
					"ack_tick": tick,
				})
			1:
				messages.append({
					"message_type": TransportMessageTypesScript.STATE_SUMMARY,
					"tick": tick,
					"player_summary": [],
					"bubbles": [],
					"items": [],
					"events": [_event(tick, SimEvent.EventType.BUBBLE_PLACED)],
				})
			_:
				messages.append({
					"message_type": TransportMessageTypesScript.CHECKPOINT,
					"tick": tick,
					"players": [],
					"bubbles": [],
					"items": [],
					"events": [_event(tick, SimEvent.EventType.BUBBLE_EXPLODED)],
				})
	return messages


func _event(tick: int, event_type: int) -> Dictionary:
	return {
		"tick": tick,
		"event_type": event_type,
		"payload": {"id": tick},
	}
