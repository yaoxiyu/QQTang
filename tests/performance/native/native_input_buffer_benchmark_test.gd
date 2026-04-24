extends QQTUnitTest


func test_native_input_buffer_benchmark_reports_metrics() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	assert_not_null(kernel)
	kernel.call("configure", 8, 128, 2)
	for tick in range(1, 65):
		for peer_id in [1001, 1002, 1003, 1004]:
			kernel.call("push_input", _frame(peer_id, tick, tick, 1, 0), -1)
		kernel.call("collect_inputs_for_tick", [1001, 1002, 1003, 1004], tick)
	var metrics: Dictionary = kernel.call("get_metrics")
	assert_eq(int(metrics.get("accepted_count", 0)), 256)
	assert_true(metrics.has("fallback_idle_count"))


func _frame(peer_id: int, tick_id: int, seq: int, move_x: int, move_y: int) -> Dictionary:
	return {
		"peer_id": peer_id,
		"tick_id": tick_id,
		"seq": seq,
		"move_x": move_x,
		"move_y": move_y,
		"action_place": false,
		"action_skill1": false,
		"action_skill2": false,
	}
