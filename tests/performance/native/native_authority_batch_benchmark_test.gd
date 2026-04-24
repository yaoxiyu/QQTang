extends QQTUnitTest

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_native_authority_batch_benchmark_reports_coalesce_usec() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeAuthorityBatchCoalescer")
	assert_not_null(kernel)
	for batch_size in [1, 5, 10, 30, 60]:
		var batch: Dictionary = kernel.call("coalesce_client_authority_batch", _messages(batch_size), {})
		assert_true(batch.has("metrics"))
		assert_true(int(batch["metrics"].get("incoming_batch_size", 0)) >= batch_size)
		assert_true(int(batch["metrics"].get("coalesce_usec", -1)) >= 0)


func _messages(batch_size: int) -> Array:
	var messages: Array = []
	for index in range(batch_size):
		messages.append({
			"message_type": TransportMessageTypesScript.CHECKPOINT if index % 2 == 0 else TransportMessageTypesScript.STATE_SUMMARY,
			"tick": 100 + index,
			"players": [],
			"bubbles": [],
			"items": [],
			"events": [{"tick": 100 + index, "name": "event_%d" % index}],
		})
	return messages
