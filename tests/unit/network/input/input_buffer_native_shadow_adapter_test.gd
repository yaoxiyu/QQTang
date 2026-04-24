extends "res://tests/gut/base/qqt_unit_test.gd"

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")


func test_input_buffer_native_shadow_matches_baseline_for_merge_fallback_and_ack() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_input_buffer
	var old_shadow := NativeFeatureFlagsScript.enable_native_input_buffer_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_input_buffer_execute
	NativeFeatureFlagsScript.enable_native_input_buffer = true
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = true
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = false

	var buffer := InputBuffer.new()
	buffer.push_input(_frame(1001, 5, 42, 1, 0, true))
	buffer.push_input(_frame(1001, 5, 99, -1, 0, false))
	buffer.push_input(_frame(2002, 5, 1, 0, 1, false))

	var collected := buffer.collect_inputs_for_tick([1001, 2002, 3003], 6)
	assert_eq(collected.size(), 3)
	assert_eq(collected[1001].move_x, -1)
	assert_false(collected[1001].action_place)
	assert_eq(collected[2002].move_y, 1)
	assert_eq(collected[3003].move_x, 0)

	buffer.ack_peer(1001, 5)
	var after_ack := buffer.collect_inputs_for_tick([1001], 5)
	assert_eq(after_ack[1001].seq, 99)

	var metrics := buffer.get_native_shadow_metrics()
	assert_true(bool(metrics.get("native_shadow_equal", false)))
	assert_eq(int(metrics.get("native_shadow_mismatch_count", -1)), 0)
	assert_true(int(metrics.get("accepted_count", 0)) >= 2)
	assert_true(int(metrics.get("ack_evicted_count", 0)) >= 1)

	NativeFeatureFlagsScript.enable_native_input_buffer = old_enabled
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = old_execute


func test_input_buffer_native_execute_returns_native_collection_with_shadow_clean() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_input_buffer
	var old_shadow := NativeFeatureFlagsScript.enable_native_input_buffer_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_input_buffer_execute
	NativeFeatureFlagsScript.enable_native_input_buffer = true
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = true
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = true

	var buffer := InputBuffer.new()
	buffer.push_input(_frame(1001, 8, 8, 1, 0, false))
	var collected := buffer.collect_inputs_for_tick([1001], 8)
	var metrics := buffer.get_native_shadow_metrics()

	assert_eq(collected.size(), 1)
	assert_eq(collected[1001].move_x, 1)
	assert_true(bool(metrics.get("native_shadow_equal", false)))
	assert_eq(int(metrics.get("native_shadow_mismatch_count", -1)), 0)

	NativeFeatureFlagsScript.enable_native_input_buffer = old_enabled
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = old_execute


func _frame(peer_id: int, tick_id: int, seq: int, move_x: int, move_y: int, action_place: bool) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.peer_id = peer_id
	frame.tick_id = tick_id
	frame.seq = seq
	frame.move_x = move_x
	frame.move_y = move_y
	frame.action_place = action_place
	frame.sanitize()
	return frame
