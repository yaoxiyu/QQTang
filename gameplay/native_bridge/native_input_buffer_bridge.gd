class_name NativeInputBufferBridge
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

var _baseline: InputBuffer = null
var _native_kernel: Object = null
var _shadow_mismatch_count: int = 0
var _last_shadow_equal: bool = true
var _use_internal_baseline: bool = true


func configure(peer_capacity: int = 8, tick_capacity: int = 64, max_late_ticks: int = 2, use_internal_baseline: bool = true) -> void:
	_use_internal_baseline = use_internal_baseline
	if _use_internal_baseline and _baseline == null:
		_baseline = load("res://gameplay/simulation/input/input_buffer.gd").new()
	_native_kernel = NativeKernelRuntimeScript.get_input_buffer_kernel()
	if _native_kernel != null:
		_native_kernel.call("configure", peer_capacity, tick_capacity, max_late_ticks)
		_native_kernel.call("clear")


func register_peer(peer_id: int, player_slot: int) -> void:
	if _native_kernel != null:
		_native_kernel.call("register_peer", peer_id, player_slot)


func push_input(frame: PlayerInputFrame, authority_tick: int = -1) -> Dictionary:
	if frame == null:
		return {"status": "drop_empty"}
	if _baseline != null:
		_baseline.push_input(frame)
	return push_input_dict(frame.to_dict(), authority_tick)


func push_input_dict(frame: Dictionary, authority_tick: int = -1) -> Dictionary:
	var native_status := {"status": "disabled"}
	if _should_use_native():
		native_status = _native_kernel.call("push_input", frame, authority_tick)
	return native_status


func collect_inputs_for_tick(peer_ids: Array[int], tick_id: int) -> Dictionary:
	var baseline_result: Dictionary = _baseline.collect_inputs_for_tick(peer_ids, tick_id) if _baseline != null else {}
	if not _should_use_native():
		return baseline_result
	var native_result := collect_native_inputs_for_tick(peer_ids, tick_id)
	if _baseline != null and NativeFeatureFlagsScript.enable_native_input_buffer_shadow:
		_last_shadow_equal = _normalized_frame_map(baseline_result) == _normalized_frame_map(native_result)
		if not _last_shadow_equal:
			_shadow_mismatch_count += 1
	if NativeFeatureFlagsScript.enable_native_input_buffer_execute:
		return _dict_frames_from_native_map(native_result)
	return baseline_result


func collect_native_inputs_for_tick(peer_ids: Array[int], tick_id: int) -> Dictionary:
	if not _should_use_native():
		return {}
	var native_array: Array = _native_kernel.call("collect_inputs_for_tick", peer_ids, tick_id)
	return _native_array_to_frame_map(native_array)


func note_shadow_result(equal: bool) -> void:
	_last_shadow_equal = equal
	if not equal:
		_shadow_mismatch_count += 1


func ack_peer(peer_id: int, ack_tick: int) -> void:
	if _baseline != null:
		_baseline.ack_peer(peer_id, ack_tick)
	if _should_use_native():
		_native_kernel.call("ack_peer", peer_id, ack_tick)


func get_metrics() -> Dictionary:
	var metrics := {
		"native_shadow_equal": _last_shadow_equal,
		"native_shadow_mismatch_count": _shadow_mismatch_count,
	}
	if _native_kernel != null:
		var native_metrics: Variant = _native_kernel.call("get_metrics")
		if native_metrics is Dictionary:
			for key in (native_metrics as Dictionary).keys():
				metrics[key] = native_metrics[key]
	return metrics


func clear() -> void:
	if _baseline != null:
		_baseline.clear()
	if _native_kernel != null:
		_native_kernel.call("clear")
	_shadow_mismatch_count = 0
	_last_shadow_equal = true


func _should_use_native() -> bool:
	return NativeFeatureFlagsScript.enable_native_input_buffer and _native_kernel != null


func _native_array_to_frame_map(native_array: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry in native_array:
		if not (entry is Dictionary):
			continue
		var frame := PlayerInputFrame.from_dict(entry)
		result[frame.peer_id] = frame
	return result


func _dict_frames_from_native_map(native_result: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for peer_id in native_result.keys():
		var frame: PlayerInputFrame = native_result[peer_id]
		result[peer_id] = frame
	return result


func _normalized_frame_map(frame_map: Dictionary) -> Array:
	var keys := frame_map.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		var frame: PlayerInputFrame = frame_map[key]
		if frame == null:
			continue
		result.append([
			int(key),
			frame.peer_id,
			frame.tick_id,
			frame.seq,
			frame.move_x,
			frame.move_y,
			frame.action_place,
			frame.action_skill1,
			frame.action_skill2,
		])
	return result
