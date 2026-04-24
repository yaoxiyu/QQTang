class_name NativeRollbackPlannerBridge
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

var _shadow_mismatch_count: int = 0
var _last_shadow_equal: bool = true


func plan(cursor: Dictionary, diff_result: Dictionary, baseline_plan: Dictionary = {}) -> Dictionary:
	if not NativeFeatureFlagsScript.enable_native_rollback_planner:
		return baseline_plan
	var kernel := NativeKernelRuntimeScript.get_rollback_planner_kernel()
	if kernel == null:
		return baseline_plan
	var native_plan: Dictionary = kernel.call("plan", cursor, diff_result)
	if NativeFeatureFlagsScript.enable_native_rollback_planner_shadow and not baseline_plan.is_empty():
		_last_shadow_equal = _normalize_plan(native_plan) == _normalize_plan(baseline_plan)
		if not _last_shadow_equal:
			_shadow_mismatch_count += 1
	if NativeFeatureFlagsScript.enable_native_rollback_planner_execute:
		return native_plan
	return baseline_plan


func get_metrics() -> Dictionary:
	return {
		"native_shadow_equal": _last_shadow_equal,
		"native_shadow_mismatch_count": _shadow_mismatch_count,
	}


func _normalize_plan(plan: Dictionary) -> Dictionary:
	return {
		"decision": int(plan.get("decision", -1)),
		"rollback_from_tick": int(plan.get("rollback_from_tick", -1)),
		"replay_to_tick": int(plan.get("replay_to_tick", -1)),
		"replay_tick_count": int(plan.get("replay_tick_count", -1)),
	}
