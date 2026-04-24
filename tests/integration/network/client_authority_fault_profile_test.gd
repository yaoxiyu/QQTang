extends QQTIntegrationTest

const NativeAuthorityBatchBridgeScript = preload("res://gameplay/native_bridge/native_authority_batch_bridge.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_authority_batch_fault_profile_drops_stale_and_preserves_reordered_events() -> void:
	var bridge: RefCounted = NativeAuthorityBatchBridgeScript.new()
	var batch: Dictionary = bridge.coalesce_client_authority_batch([
		_snapshot(104, "newer"),
		_state_summary(103, "summary"),
		_snapshot(101, "stale_a"),
		_snapshot(104, "duplicate_newer"),
		_snapshot(100, "stale_b"),
	], {
		"latest_authoritative_tick": 101,
		"latest_snapshot_tick": 101,
	})
	var events_by_tick: Array = batch["authority_events_by_tick"]
	var metrics: Dictionary = batch["metrics"]

	assert_eq(int(batch["latest_snapshot_message"].get("tick", 0)), 104)
	assert_eq(int(metrics.get("dropped_stale_snapshot_count", 0)), 2)
	assert_eq(int(metrics.get("dropped_intermediate_snapshot_count", 0)), 1)
	assert_eq(events_by_tick.size(), 4)
	assert_eq(String(events_by_tick[0]["events"][0]["name"]), "stale_b")
	assert_eq(String(events_by_tick[1]["events"][0]["name"]), "stale_a")
	assert_eq(String(events_by_tick[2]["events"][0]["name"]), "summary")
	assert_eq(String(events_by_tick[3]["events"][0]["name"]), "newer")
	assert_eq(String(events_by_tick[3]["events"][1]["name"]), "duplicate_newer")


func _snapshot(tick: int, event_name: String) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.CHECKPOINT,
		"tick": tick,
		"players": [],
		"bubbles": [],
		"items": [],
		"events": [{"tick": tick, "event_type": SimEvent.EventType.BUBBLE_PLACED, "payload": {}, "name": event_name}],
	}


func _state_summary(tick: int, event_name: String) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": tick,
		"events": [{"tick": tick, "event_type": SimEvent.EventType.BUBBLE_EXPLODED, "payload": {}, "name": event_name}],
	}
