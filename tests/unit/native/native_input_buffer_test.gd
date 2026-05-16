extends QQTUnitTest


func test_native_input_buffer_instantiates_and_reports_version() -> void:
	assert_true(ClassDB.can_instantiate("QQTNativeInputBuffer"))
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	assert_not_null(kernel)
	assert_eq(String(kernel.call("get_kernel_version")), "sync_kernel_v1")


func test_same_identity_duplicate_ignored() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("register_peer", 1, 0)

	var r1: Dictionary = kernel.call("push_input", _frame(1, 10, 100, 1, 0, 1), -1)
	var r2: Dictionary = kernel.call("push_input", _frame(1, 10, 100, 1, 0, 1), -1)

	assert_eq(String(r1.get("status", "")), "accepted")
	assert_eq(String(r2.get("status", "")), "duplicate_ignored")

	var metrics: Dictionary = kernel.call("get_metrics")
	assert_eq(int(metrics.get("duplicate_ignored_count", 0)), 1)

	var collected := _collect_one(kernel, 1, 10)
	assert_eq(int(collected.get("action_bits", 0)), 1)
	assert_eq(int(collected.get("move_x", 0)), 1)


func test_same_identity_duplicate_conflict() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("register_peer", 1, 0)

	kernel.call("push_input", _frame(1, 10, 100, 1, 0, 1), -1)
	var r2: Dictionary = kernel.call("push_input", _frame(1, 10, 100, -1, 0, 1), -1)

	assert_eq(String(r2.get("status", "")), "duplicate_conflict")

	var metrics: Dictionary = kernel.call("get_metrics")
	assert_eq(int(metrics.get("duplicate_conflict_count", 0)), 1)

	var collected := _collect_one(kernel, 1, 10)
	assert_eq(int(collected.get("move_x", 0)), 1)


func test_higher_seq_replacement() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("register_peer", 1, 0)

	kernel.call("push_input", _frame(1, 10, 100, 1, 0, 1), -1)
	var r2: Dictionary = kernel.call("push_input", _frame(1, 10, 101, 0, 0, 0), -1)

	assert_eq(String(r2.get("status", "")), "replaced_by_higher_seq")

	var metrics: Dictionary = kernel.call("get_metrics")
	assert_eq(int(metrics.get("replaced_by_higher_seq_count", 0)), 1)

	var collected := _collect_one(kernel, 1, 10)
	assert_eq(int(collected.get("move_x", 0)), 0)
	assert_eq(int(collected.get("action_bits", 0)), 0)


func test_lower_seq_drop() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("register_peer", 1, 0)

	kernel.call("push_input", _frame(1, 10, 101, 1, 0, 1), -1)
	var r2: Dictionary = kernel.call("push_input", _frame(1, 10, 100, -1, 0, 1), -1)

	assert_eq(String(r2.get("status", "")), "drop_stale_seq")

	var metrics: Dictionary = kernel.call("get_metrics")
	assert_eq(int(metrics.get("stale_seq_drop_count", 0)), 1)


func test_too_late_no_retarget() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("register_peer", 1, 0)

	var r: Dictionary = kernel.call("push_input", _frame(1, 20, 20, 1, 0, 1), 20)

	assert_eq(String(r.get("status", "")), "drop_too_late")
	assert_false(bool(r.get("retargeted", true)))

	var metrics: Dictionary = kernel.call("get_metrics")
	assert_eq(int(metrics.get("too_late_drop_count", 0)), 1)
	assert_eq(int(metrics.get("late_retarget_count", 0)), 0)

	var fallback := _collect_one(kernel, 1, 21)
	assert_eq(int(fallback.get("action_bits", 0)), 0)


func test_ack_monotonic() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("register_peer", 1, 0)

	kernel.call("push_input", _frame(1, 10, 10, 1, 0, 1), -1)
	kernel.call("push_input", _frame(1, 11, 11, 1, 0, 1), -1)
	kernel.call("push_input", _frame(1, 12, 12, 1, 0, 1), -1)

	kernel.call("ack_peer", 1, 11)
	kernel.call("ack_peer", 1, 10)

	var metrics: Dictionary = kernel.call("get_metrics")
	assert_eq(int(metrics.get("stale_ack_count", 0)), 1)

	var collected := _collect_one(kernel, 1, 12)
	assert_eq(int(collected.get("tick_id", 0)), 12)


func test_fallback_action_cleared() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("register_peer", 1, 0)

	kernel.call("push_input", _frame(1, 10, 10, 1, 0, 1), -1)

	var fallback := _collect_one(kernel, 1, 11)
	assert_eq(int(fallback.get("action_bits", 0)), 0)
	assert_eq(int(fallback.get("move_x", 0)), 0)


func test_native_input_buffer_late_policy_metrics() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("register_peer", 1, 0)

	var too_late: Dictionary = kernel.call("push_input", _frame(1, 1, 1, 1, 0, 1), 10)
	var accepted: Dictionary = kernel.call("push_input", _frame(1, 12, 2, 1, 0, 1), 10)
	var stale: Dictionary = kernel.call("push_input", _frame(1, 12, 1, 1, 0, 1), 10)
	var metrics: Dictionary = kernel.call("get_metrics")

	assert_eq(String(too_late.get("status", "")), "drop_too_late")
	assert_eq(String(accepted.get("status", "")), "accepted")
	assert_false(bool(accepted.get("retargeted", true)))
	assert_eq(String(stale.get("status", "")), "drop_stale_seq")
	assert_eq(int(metrics.get("too_late_drop_count", 0)), 1)
	assert_eq(int(metrics.get("late_retarget_count", 0)), 0)
	assert_eq(int(metrics.get("stale_seq_drop_count", 0)), 1)


func test_native_input_buffer_ack_eviction() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeInputBuffer")
	kernel.call("configure", 4, 8, 2)
	kernel.call("register_peer", 1, 0)
	kernel.call("push_input", _frame(1, 5, 5, 1, 0, 1), -1)
	kernel.call("ack_peer", 1, 5)

	var fallback := _collect_one(kernel, 1, 5)
	var metrics: Dictionary = kernel.call("get_metrics")
	assert_eq(int(fallback.get("seq", 0)), 5)
	assert_eq(int(metrics.get("ack_evicted_count", 0)), 1)


func _collect_one(kernel: Object, peer_id: int, tick_id: int) -> Dictionary:
	var frames: Array = kernel.call("collect_inputs_for_tick", [peer_id], tick_id)
	assert_eq(frames.size(), 1)
	return frames[0]


func _frame(peer_id: int, tick_id: int, seq: int, move_x: int, move_y: int, action_bits: int) -> Dictionary:
	return {
		"peer_id": peer_id,
		"tick_id": tick_id,
		"seq": seq,
		"move_x": move_x,
		"move_y": move_y,
		"action_bits": action_bits,
	}
