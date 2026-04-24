extends QQTIntegrationTest

const AuthorityBatchCoalescerScript = preload("res://network/session/runtime/authority_batch_coalescer.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_authority_batch_keeps_one_latest_snapshot_and_preserves_events() -> void:
	var coalescer: RefCounted = AuthorityBatchCoalescerScript.new()
	var batch: Dictionary = coalescer.coalesce_client_authority_batch([
		_snapshot(100, [{"tick": 100, "event_type": SimEvent.EventType.BUBBLE_PLACED, "payload": {"bubble_id": 100}}]),
		_snapshot(105, [{"tick": 105, "event_type": SimEvent.EventType.BUBBLE_EXPLODED, "payload": {"bubble_id": 100}}]),
		_snapshot(106, [{"tick": 106, "event_type": SimEvent.EventType.ITEM_PICKED, "payload": {"item_id": 2}}]),
	], {})
	var runtime := ClientRuntime.new()
	runtime.configure(7)
	runtime.configure_controlled_peer(7)
	runtime.client_session = ClientSession.new()
	runtime.client_session.configure(7, 7)
	runtime._active = true

	runtime.ingest_authority_batch(batch)
	var events := runtime.consume_pending_authoritative_events()

	assert_eq(int(runtime.client_session.latest_snapshot_tick), 106)
	assert_eq(events.size(), 3)
	assert_eq(int(batch["metrics"].get("dropped_intermediate_snapshot_count", 0)), 2)
	runtime.queue_free()


func _snapshot(tick: int, events: Array) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.CHECKPOINT,
		"tick": tick,
		"players": [],
		"bubbles": [],
		"items": [],
		"events": events,
	}
