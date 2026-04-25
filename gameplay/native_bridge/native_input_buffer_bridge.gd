class_name NativeInputBufferBridge
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

var _native_kernel: Object = null


func configure(peer_capacity: int = 8, tick_capacity: int = 64, max_late_ticks: int = 2, _use_internal_baseline: bool = true) -> void:
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
	return push_input_dict(frame.to_dict(), authority_tick)


func push_input_dict(frame: Dictionary, authority_tick: int = -1) -> Dictionary:
	if not _should_use_native():
		push_error("[native_input_buffer_bridge] native input buffer kernel is unavailable")
		return {"status": "drop_native_unavailable"}
	return _native_kernel.call("push_input", frame, authority_tick)


func collect_inputs_for_tick(peer_ids: Array[int], tick_id: int) -> Dictionary:
	if not _should_use_native():
		push_error("[native_input_buffer_bridge] native input buffer kernel is unavailable")
		return {}
	var native_result := collect_native_inputs_for_tick(peer_ids, tick_id)
	return _dict_frames_from_native_map(native_result)


func collect_native_inputs_for_tick(peer_ids: Array[int], tick_id: int) -> Dictionary:
	if not _should_use_native():
		push_error("[native_input_buffer_bridge] native input buffer kernel is unavailable")
		return {}
	var native_array: Array = _native_kernel.call("collect_inputs_for_tick", peer_ids, tick_id)
	return _native_array_to_frame_map(native_array)


func ack_peer(peer_id: int, ack_tick: int) -> void:
	if _should_use_native():
		_native_kernel.call("ack_peer", peer_id, ack_tick)
	else:
		push_error("[native_input_buffer_bridge] native input buffer kernel is unavailable")


func get_metrics() -> Dictionary:
	var metrics := {}
	if _native_kernel != null:
		var native_metrics: Variant = _native_kernel.call("get_metrics")
		if native_metrics is Dictionary:
			for key in (native_metrics as Dictionary).keys():
				metrics[key] = native_metrics[key]
	return metrics


func clear() -> void:
	if _native_kernel != null:
		_native_kernel.call("clear")


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
