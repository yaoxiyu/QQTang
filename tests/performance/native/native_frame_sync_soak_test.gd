extends QQTUnitTest

const NativeAuthorityBatchBridgeScript = preload("res://gameplay/native_bridge/native_authority_batch_bridge.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_native_frame_sync_soak_reports_batch_metrics() -> void:
	var bridge: RefCounted = NativeAuthorityBatchBridgeScript.new()
	var coalesce_samples: Array[int] = []
	var max_batch_size := 0
	var max_dropped_intermediate := 0
	for sample in range(20):
		var batch_size := 5 + sample
		var batch: Dictionary = bridge.coalesce_client_authority_batch(_messages(batch_size, sample * 100), {})
		var metrics: Dictionary = batch["metrics"]
		coalesce_samples.append(int(metrics.get("coalesce_usec", 0)))
		max_batch_size = max(max_batch_size, int(metrics.get("incoming_batch_size", 0)))
		max_dropped_intermediate = max(max_dropped_intermediate, int(metrics.get("dropped_intermediate_snapshot_count", 0)))
	var report := {
		"authority_batch_size_max": max_batch_size,
		"dropped_intermediate_snapshot_count_max": max_dropped_intermediate,
		"coalesce_usec_avg": _avg(coalesce_samples),
		"coalesce_usec_p95": _p95(coalesce_samples),
	}
	assert_true(int(report.get("authority_batch_size_max", 0)) >= 24)
	assert_true(float(report.get("coalesce_usec_avg", -1.0)) >= 0.0)
	assert_true(float(report.get("coalesce_usec_p95", -1.0)) >= 0.0)


func _messages(count: int, base_tick: int) -> Array:
	var result: Array = []
	for index in range(count):
		result.append({
			"message_type": TransportMessageTypesScript.CHECKPOINT if index % 2 == 0 else TransportMessageTypesScript.STATE_SUMMARY,
			"tick": base_tick + index,
			"players": [],
			"bubbles": [],
			"items": [],
			"events": [],
		})
	return result


func _avg(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0
	for value in values:
		total += value
	return float(total) / float(values.size())


func _p95(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	var index: int = clamp(int(ceil(float(sorted.size()) * 0.95)) - 1, 0, sorted.size() - 1)
	return float(sorted[index])
