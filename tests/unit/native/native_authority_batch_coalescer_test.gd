extends QQTUnitTest

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_native_class_instantiates_and_reports_version() -> void:
	assert_true(ClassDB.can_instantiate("QQTNativeAuthorityBatchCoalescer"))
	var kernel: Object = ClassDB.instantiate("QQTNativeAuthorityBatchCoalescer")
	assert_not_null(kernel)
	assert_eq(String(kernel.call("get_kernel_version")), "phase32_sync_kernel_v1")


func test_native_coalesces_multiple_snapshots_to_latest() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeAuthorityBatchCoalescer")
	var batch: Dictionary = kernel.call("coalesce_client_authority_batch", [
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 100),
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 105),
		_snapshot(TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT, 106),
	], {})

	assert_eq(int(batch["latest_snapshot_message"].get("tick", 0)), 106)
	assert_eq(_packed_to_array(batch["dropped_snapshot_ticks"]), [100, 105])
	assert_eq(int(batch["metrics"].get("raw_checkpoint_count", 0)), 2)


func test_native_drops_stale_snapshot_by_cursor() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeAuthorityBatchCoalescer")
	var batch: Dictionary = kernel.call("coalesce_client_authority_batch", [
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 100),
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 101),
	], {
		"latest_authoritative_tick": 100,
		"latest_snapshot_tick": 99,
	})

	assert_eq(int(batch["latest_snapshot_message"].get("tick", 0)), 101)
	assert_eq(_packed_to_array(batch["dropped_snapshot_ticks"]), [100])
	assert_eq(int(batch["metrics"].get("dropped_stale_snapshot_count", 0)), 1)


func test_native_keeps_max_ack_and_events_order() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeAuthorityBatchCoalescer")
	var batch: Dictionary = kernel.call("coalesce_client_authority_batch", [
		_ack(2, 10),
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 100, [{"tick": 100, "name": "a"}]),
		_ack(2, 12),
		_snapshot(TransportMessageTypesScript.CHECKPOINT, 101, [{"tick": 101, "name": "b"}]),
	], {})

	var acks: Array = batch["input_acks"]
	assert_eq(acks.size(), 1)
	assert_eq(int(acks[0]["ack_tick"]), 12)
	var events_by_tick: Array = batch["authority_events_by_tick"]
	assert_eq(events_by_tick.size(), 2)
	assert_eq(String(events_by_tick[0]["events"][0]["name"]), "a")
	assert_eq(String(events_by_tick[1]["events"][0]["name"]), "b")


func test_native_drops_stale_summary_and_counts_intermediate_summary() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeAuthorityBatchCoalescer")
	var batch: Dictionary = kernel.call("coalesce_client_authority_batch", [
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 100, "value": "stale"},
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 101, "value": "old"},
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 102, "value": "new"},
	], {
		"latest_authoritative_tick": 100,
	})

	var metrics: Dictionary = batch["metrics"]
	assert_eq(int(batch["latest_state_summary"].get("tick", 0)), 102)
	assert_eq(String(batch["latest_state_summary"].get("value", "")), "new")
	assert_eq(int(metrics.get("dropped_stale_summary_count", 0)), 1)
	assert_eq(int(metrics.get("dropped_intermediate_summary_count", 0)), 1)
	assert_eq(int(metrics.get("coalesced_summary_tick", 0)), 102)


func test_native_deduplicates_events_by_event_id() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeAuthorityBatchCoalescer")
	var batch: Dictionary = kernel.call("coalesce_client_authority_batch", [
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


func _packed_to_array(value: Variant) -> Array:
	var result: Array = []
	for item in value:
		result.append(int(item))
	return result
