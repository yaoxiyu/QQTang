extends QQTUnitTest


func test_native_input_buffer_instantiates_and_reports_version() -> void:
	assert_true(ClassDB.can_instantiate("QQTNativeInputBuffer"))
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	assert_not_null(kernel)
	assert_eq(String(kernel.call("get_kernel_version")), "phase32_sync_kernel_v1")


func test_native_input_buffer_merges_duplicate_tick_and_falls_back() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("push_input", _frame(1001, 5, 42, 1, 0, true), -1)
	kernel.call("push_input", _frame(1001, 5, 99, -1, 0, false), -1)

	var exact := _collect_one(kernel, 1001, 5)
	assert_eq(int(exact.get("seq", 0)), 99)
	assert_eq(int(exact.get("move_x", 0)), -1)
	assert_true(bool(exact.get("action_place", false)))

	var fallback := _collect_one(kernel, 1001, 6)
	assert_eq(int(fallback.get("tick_id", 0)), 6)
	assert_eq(int(fallback.get("move_x", 0)), -1)
	assert_false(bool(fallback.get("action_place", true)))


func test_native_input_buffer_late_policy_metrics() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)

	var too_late: Dictionary = kernel.call("push_input", _frame(1001, 1, 1, 1, 0, false), 10)
	var retargeted: Dictionary = kernel.call("push_input", _frame(1001, 10, 2, 1, 0, false), 10)
	var stale: Dictionary = kernel.call("push_input", _frame(1001, 12, 1, 1, 0, false), 10)
	var metrics: Dictionary = kernel.call("get_metrics")

	assert_eq(String(too_late.get("status", "")), "drop_too_late")
	assert_eq(String(retargeted.get("status", "")), "accepted")
	assert_true(bool(retargeted.get("retargeted", false)))
	assert_eq(String(stale.get("status", "")), "drop_stale_seq")
	assert_eq(int(metrics.get("too_late_drop_count", 0)), 1)
	assert_eq(int(metrics.get("late_retarget_count", 0)), 1)
	assert_eq(int(metrics.get("stale_seq_drop_count", 0)), 1)


func test_native_input_buffer_ack_eviction() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("push_input", _frame(1001, 5, 5, 1, 0, false), -1)
	kernel.call("ack_peer", 1001, 5)

	var fallback := _collect_one(kernel, 1001, 5)
	var metrics: Dictionary = kernel.call("get_metrics")
	assert_eq(int(fallback.get("seq", 0)), 5)
	assert_eq(int(metrics.get("ack_evicted_count", 0)), 1)


func _collect_one(kernel: Object, peer_id: int, tick_id: int) -> Dictionary:
	var frames: Array = kernel.call("collect_inputs_for_tick", [peer_id], tick_id)
	assert_eq(frames.size(), 1)
	return frames[0]


func _frame(peer_id: int, tick_id: int, seq: int, move_x: int, move_y: int, action_place: bool) -> Dictionary:
	return {
		"peer_id": peer_id,
		"tick_id": tick_id,
		"seq": seq,
		"move_x": move_x,
		"move_y": move_y,
		"action_place": action_place,
		"action_skill1": false,
		"action_skill2": false,
	}
