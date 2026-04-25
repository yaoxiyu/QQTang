class_name NativeSnapshotDiffBridge
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")


func diff_snapshots(local_snapshot: Dictionary, authority_snapshot: Dictionary, options: Dictionary) -> Dictionary:
	if not NativeFeatureFlagsScript.enable_native_snapshot_diff:
		push_error("[native_snapshot_diff_bridge] native snapshot diff is disabled")
		return {}
	var kernel := NativeKernelRuntimeScript.get_snapshot_diff_kernel()
	if kernel == null:
		push_error("[native_snapshot_diff_bridge] native snapshot diff kernel is unavailable")
		return {}
	var native_result: Dictionary = kernel.call("diff_snapshots", local_snapshot, authority_snapshot, options)
	return native_result


func get_metrics() -> Dictionary:
	return {}
