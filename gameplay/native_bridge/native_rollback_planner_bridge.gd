class_name NativeRollbackPlannerBridge
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")


func plan(cursor: Dictionary, diff_result: Dictionary) -> Dictionary:
	if not NativeFeatureFlagsScript.enable_native_rollback_planner:
		push_error("[native_rollback_planner_bridge] native rollback planner is disabled")
		return {}
	var kernel := NativeKernelRuntimeScript.get_rollback_planner_kernel()
	if kernel == null:
		push_error("[native_rollback_planner_bridge] native rollback planner kernel is unavailable")
		return {}
	var native_plan: Dictionary = kernel.call("plan", cursor, diff_result)
	return native_plan


func get_metrics() -> Dictionary:
	return {}
