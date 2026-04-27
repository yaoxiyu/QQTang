class_name ClientRuntimeShutdownHandle
extends RefCounted

var _runtime: Object = null


func configure(runtime: Object) -> void:
	_runtime = runtime


func get_shutdown_name() -> String:
	return "client_runtime"


func get_shutdown_priority() -> int:
	return 60


func shutdown(context: Variant) -> void:
	if _runtime == null or not is_instance_valid(_runtime):
		return
	if _runtime.has_method("_shutdown_runtime_internal"):
		_runtime.call("_shutdown_runtime_internal", context)


func get_shutdown_metrics() -> Dictionary:
	if _runtime != null and is_instance_valid(_runtime) and _runtime.has_method("_build_shutdown_metrics"):
		return _runtime.call("_build_shutdown_metrics")
	return {
		"shutdown_failed": false,
	}
