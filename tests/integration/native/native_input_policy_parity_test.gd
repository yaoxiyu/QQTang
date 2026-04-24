extends QQTIntegrationTest

const NativeInputBufferBridgeScript = preload("res://gameplay/native_bridge/native_input_buffer_bridge.gd")
const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")


func test_native_input_buffer_shadow_matches_gdscript_for_normal_inputs() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_input_buffer
	var old_shadow := NativeFeatureFlagsScript.enable_native_input_buffer_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_input_buffer_execute
	NativeFeatureFlagsScript.enable_native_input_buffer = true
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = true
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = false

	var bridge: RefCounted = NativeInputBufferBridgeScript.new()
	bridge.configure(4, 8, 2)
	bridge.push_input(_player_frame(1001, 5, 42, 1, 0, true), -1)
	bridge.push_input(_player_frame(1001, 5, 99, -1, 0, false), -1)
	bridge.push_input(_player_frame(2002, 5, 1, 0, 1, false), -1)

	var collected: Dictionary = bridge.collect_inputs_for_tick([1001, 2002, 3003], 6)
	var metrics: Dictionary = bridge.get_metrics()

	assert_eq(collected.size(), 3)
	assert_eq(collected[1001].move_x, -1)
	assert_false(collected[1001].action_place)
	assert_eq(collected[2002].move_y, 1)
	assert_eq(collected[3003].move_x, 0)
	assert_true(bool(metrics.get("native_shadow_equal", false)))
	assert_eq(int(metrics.get("native_shadow_mismatch_count", -1)), 0)

	NativeFeatureFlagsScript.enable_native_input_buffer = old_enabled
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = old_execute


func test_native_input_buffer_execute_can_return_native_frames() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_input_buffer
	var old_shadow := NativeFeatureFlagsScript.enable_native_input_buffer_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_input_buffer_execute
	NativeFeatureFlagsScript.enable_native_input_buffer = true
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = true
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = true

	var bridge: RefCounted = NativeInputBufferBridgeScript.new()
	bridge.configure(4, 8, 2)
	bridge.push_input(_player_frame(1001, 5, 42, 1, 0, true), -1)
	var collected: Dictionary = bridge.collect_inputs_for_tick([1001], 5)

	assert_eq(collected[1001].seq, 42)
	assert_true(bool(bridge.get_metrics().get("native_shadow_equal", false)))

	NativeFeatureFlagsScript.enable_native_input_buffer = old_enabled
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = old_execute


func _player_frame(peer_id: int, tick_id: int, seq: int, move_x: int, move_y: int, action_place: bool) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.peer_id = peer_id
	frame.tick_id = tick_id
	frame.seq = seq
	frame.move_x = move_x
	frame.move_y = move_y
	frame.action_place = action_place
	frame.sanitize()
	return frame
