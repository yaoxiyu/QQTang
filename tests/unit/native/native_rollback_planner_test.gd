extends QQTUnitTest


func test_native_rollback_planner_noop_for_equal_diff() -> void:
	var plan: Dictionary = _planner().call("plan", _cursor(), {"equal": true, "reason_mask": 0})
	assert_eq(int(plan.get("decision", -1)), 0)


func test_native_rollback_planner_force_resync_when_local_snapshot_missing() -> void:
	var cursor := _cursor()
	cursor["local_snapshot_exists"] = false
	var plan: Dictionary = _planner().call("plan", cursor, {"equal": false, "reason_mask": 1})
	assert_eq(int(plan.get("decision", -1)), 2)


func test_native_rollback_planner_force_resync_when_window_exceeded() -> void:
	var cursor := _cursor()
	cursor["predicted_until_tick"] = 40
	cursor["max_rollback_window"] = 4
	var plan: Dictionary = _planner().call("plan", cursor, {"equal": false, "reason_mask": 2})
	assert_eq(int(plan.get("decision", -1)), 2)


func test_native_rollback_planner_force_resync_when_cursor_requests_it() -> void:
	var cursor := _cursor()
	cursor["force_resync"] = true
	var plan: Dictionary = _planner().call("plan", cursor, {"equal": false, "reason_mask": 16})
	assert_eq(int(plan.get("decision", -1)), 2)


func test_native_rollback_planner_rollback_for_in_window_diff() -> void:
	var cursor := _cursor()
	cursor["predicted_until_tick"] = 12
	var plan: Dictionary = _planner().call("plan", cursor, {"equal": false, "reason_mask": 2})
	assert_eq(int(plan.get("decision", -1)), 1)
	assert_eq(int(plan.get("replay_tick_count", -1)), 2)


func _planner() -> Object:
	var kernel: Object = ClassDB.instantiate("QQTNativeRollbackPlanner")
	assert_not_null(kernel)
	assert_eq(String(kernel.call("get_kernel_version")), "phase32_sync_kernel_v1")
	return kernel


func _cursor() -> Dictionary:
	return {
		"authoritative_tick": 10,
		"latest_authoritative_tick": -1,
		"predicted_until_tick": 10,
		"max_rollback_window": 16,
		"local_snapshot_exists": true,
	}
