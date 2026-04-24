class_name NativeAuthorityBatchBridge
extends RefCounted

const AuthorityBatchCoalescerScript = preload("res://network/session/runtime/authority_batch_coalescer.gd")
const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

var _baseline: RefCounted = AuthorityBatchCoalescerScript.new()
var _shadow_mismatch_count: int = 0


func coalesce_client_authority_batch(messages: Array, cursor: Dictionary = {}) -> Dictionary:
	var baseline_result: Dictionary = _baseline.coalesce_client_authority_batch(messages, cursor)
	if not NativeFeatureFlagsScript.enable_native_authority_batch_coalescer:
		return baseline_result
	var native_kernel: Object = NativeKernelRuntimeScript.get_authority_batch_coalescer_kernel()
	if native_kernel == null:
		return baseline_result
	var raw_native_result: Variant = native_kernel.call("coalesce_client_authority_batch", messages, cursor)
	if not (raw_native_result is Dictionary):
		return baseline_result
	var native_result: Dictionary = raw_native_result
	var shadow_equal: bool = true
	if NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow:
		shadow_equal = _normalized_equal(baseline_result, native_result)
		if not shadow_equal:
			_shadow_mismatch_count += 1
	_apply_shadow_metrics(baseline_result, shadow_equal)
	if NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute and native_result is Dictionary:
		_apply_shadow_metrics(native_result, shadow_equal)
		return native_result
	return baseline_result


func get_metrics() -> Dictionary:
	return {
		"native_shadow_mismatch_count": _shadow_mismatch_count,
	}


func _apply_shadow_metrics(result: Dictionary, shadow_equal: bool) -> void:
	var raw_metrics: Variant = result.get("metrics", {})
	if not (raw_metrics is Dictionary):
		return
	var metrics: Dictionary = raw_metrics
	metrics["native_shadow_equal"] = shadow_equal
	metrics["native_shadow_mismatch_count"] = _shadow_mismatch_count
	result["metrics"] = metrics


func _normalized_equal(left: Variant, right: Variant) -> bool:
	return _normalize_value(left, "") == _normalize_value(right, "")


func _normalize_value(value: Variant, key_name: String) -> Variant:
	if key_name == "coalesce_usec":
		return 0
	if value is PackedInt32Array:
		var packed: PackedInt32Array = value
		var result: Array = []
		for item in packed:
			result.append(int(item))
		return result
	if value is Array:
		var array_result: Array = []
		for item in value:
			array_result.append(_normalize_value(item, ""))
		return array_result
	if value is Dictionary:
		var dict: Dictionary = value
		var keys: Array = dict.keys()
		keys.sort()
		var normalized: Array = []
		for key in keys:
			normalized.append([String(key), _normalize_value(dict[key], String(key))])
		return normalized
	return value
