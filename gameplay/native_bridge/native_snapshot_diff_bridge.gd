class_name NativeSnapshotDiffBridge
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

var _shadow_mismatch_count: int = 0
var _last_shadow_equal: bool = true


func diff_snapshots(local_snapshot: Dictionary, authority_snapshot: Dictionary, options: Dictionary, baseline_result: Dictionary = {}) -> Dictionary:
	if not NativeFeatureFlagsScript.enable_native_snapshot_diff:
		return baseline_result
	var kernel := NativeKernelRuntimeScript.get_snapshot_diff_kernel()
	if kernel == null:
		return baseline_result
	var native_result: Dictionary = kernel.call("diff_snapshots", local_snapshot, authority_snapshot, options)
	if NativeFeatureFlagsScript.enable_native_snapshot_diff_shadow and not baseline_result.is_empty():
		_last_shadow_equal = _normalize_diff(native_result) == _normalize_diff(baseline_result)
		if not _last_shadow_equal:
			_shadow_mismatch_count += 1
	if NativeFeatureFlagsScript.enable_native_snapshot_diff_execute:
		return native_result
	return baseline_result


func get_metrics() -> Dictionary:
	return {
		"native_shadow_equal": _last_shadow_equal,
		"native_shadow_mismatch_count": _shadow_mismatch_count,
	}


func _normalize_diff(diff: Dictionary) -> Dictionary:
	return {
		"equal": bool(diff.get("equal", false)),
		"reason_mask": int(diff.get("reason_mask", 0)),
		"first_diff_section": String(diff.get("first_diff_section", "")),
	}
