class_name NativeAuthorityBatchBridge
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")


func coalesce_client_authority_batch(messages: Array, cursor: Dictionary = {}) -> Dictionary:
	if not NativeFeatureFlagsScript.enable_native_authority_batch_coalescer:
		push_error("[native_authority_batch_bridge] native authority batch coalescer is disabled")
		return {}
	var native_kernel: Object = NativeKernelRuntimeScript.get_authority_batch_coalescer_kernel()
	if native_kernel == null:
		push_error("[native_authority_batch_bridge] native authority batch coalescer kernel is unavailable")
		return {}
	var raw_native_result: Variant = native_kernel.call("coalesce_client_authority_batch", messages, cursor)
	if not (raw_native_result is Dictionary):
		push_error("[native_authority_batch_bridge] native authority batch coalescer returned non-dictionary result")
		return {}
	return raw_native_result


func get_metrics() -> Dictionary:
	return {}
