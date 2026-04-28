extends QQTUnitTest


func test_native_snapshot_diff_reports_equal_snapshot() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeSnapshotDiff")
	assert_not_null(kernel)
	assert_eq(String(kernel.call("get_kernel_version")), "sync_kernel_v1")
	var diff: Dictionary = kernel.call("diff_snapshots", _snapshot(1), _snapshot(1), _options())
	assert_true(bool(diff.get("equal", false)))
	assert_eq(int(diff.get("reason_mask", -1)), 0)


func test_native_snapshot_diff_reports_local_player_diff() -> void:
	var local := _snapshot(1)
	var authority := _snapshot(1)
	authority["players"][0]["cell_x"] = 5
	var kernel: Object = ClassDB.instantiate("QQTNativeSnapshotDiff")
	var diff: Dictionary = kernel.call("diff_snapshots", local, authority, _options())
	assert_false(bool(diff.get("equal", true)))
	assert_eq(String(diff.get("first_diff_section", "")), "local_player")


func test_native_snapshot_diff_ignores_configured_local_player_keys() -> void:
	var local := _snapshot(1)
	var authority := _snapshot(1)
	authority["players"][0]["bomb_available"] = 0
	var options := _options()
	options["ignored_local_player_keys"] = ["bomb_available"]
	var kernel: Object = ClassDB.instantiate("QQTNativeSnapshotDiff")
	var diff: Dictionary = kernel.call("diff_snapshots", local, authority, options)
	assert_true(bool(diff.get("equal", false)))


func test_native_snapshot_diff_reports_bubble_diff_when_enabled() -> void:
	var local := _snapshot(1)
	var authority := _snapshot(1)
	authority["bubbles"].append({"entity_id": 10})
	var kernel: Object = ClassDB.instantiate("QQTNativeSnapshotDiff")
	var diff: Dictionary = kernel.call("diff_snapshots", local, authority, _options())
	assert_false(bool(diff.get("equal", true)))
	assert_eq(String(diff.get("first_diff_section", "")), "bubbles")


func test_native_snapshot_diff_reports_item_diff_when_enabled() -> void:
	var local := _snapshot(1)
	var authority := _snapshot(1)
	authority["items"].append({"entity_id": 20})
	var kernel: Object = ClassDB.instantiate("QQTNativeSnapshotDiff")
	var diff: Dictionary = kernel.call("diff_snapshots", local, authority, _options())
	assert_false(bool(diff.get("equal", true)))
	assert_eq(String(diff.get("first_diff_section", "")), "items")


func test_native_snapshot_diff_reports_rng_diff_when_both_nonzero() -> void:
	var local := _snapshot(1)
	var authority := _snapshot(1)
	local["rng_state"] = 10
	authority["rng_state"] = 11
	var kernel: Object = ClassDB.instantiate("QQTNativeSnapshotDiff")
	var diff: Dictionary = kernel.call("diff_snapshots", local, authority, _options())
	assert_false(bool(diff.get("equal", true)))
	assert_eq(String(diff.get("first_diff_section", "")), "rng_state")


func test_native_snapshot_diff_reports_missing_snapshot() -> void:
	var kernel: Object = ClassDB.instantiate("QQTNativeSnapshotDiff")
	var diff: Dictionary = kernel.call("diff_snapshots", {}, _snapshot(1), _options())
	assert_false(bool(diff.get("equal", true)))
	assert_eq(String(diff.get("first_diff_section", "")), "missing")
	assert_eq(int(diff.get("reason_mask", 0)), 1)


func test_native_snapshot_diff_treats_int_and_float_numeric_values_as_equal() -> void:
	var local := _snapshot(1)
	var authority := _snapshot(1)
	local["players"][0]["cell_x"] = 1
	authority["players"][0]["cell_x"] = 1.0
	var kernel: Object = ClassDB.instantiate("QQTNativeSnapshotDiff")
	var diff: Dictionary = kernel.call("diff_snapshots", local, authority, _options())
	assert_true(bool(diff.get("equal", false)))


func _snapshot(tick: int) -> Dictionary:
	return {
		"tick": tick,
		"players": [{
			"player_slot": 1,
			"cell_x": 1,
			"cell_y": 1,
			"bomb_available": 1,
		}],
		"bubbles": [],
		"items": [],
		"rng_state": 0,
	}


func _options() -> Dictionary:
	return {
		"local_peer_id": 1,
		"compare_bubbles": true,
		"compare_items": true,
		"ignored_local_player_keys": [],
	}

