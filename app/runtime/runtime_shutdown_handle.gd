class_name RuntimeShutdownHandle
extends RefCounted

var name: String = ""
var priority: int = 100
var target: Object = null
var shutdown_method: StringName = &"shutdown_runtime"
var metrics_method: StringName = &"get_shutdown_metrics"


func _init(handle_name: String = "", handle_priority: int = 100, handle_target: Object = null, method_name: StringName = &"shutdown_runtime") -> void:
	name = handle_name
	priority = handle_priority
	target = handle_target
	shutdown_method = method_name


func get_shutdown_name() -> String:
	return name


func get_shutdown_priority() -> int:
	return priority


func shutdown(context: Variant) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method(shutdown_method):
		target.call(shutdown_method)


func get_shutdown_metrics() -> Dictionary:
	if target != null and is_instance_valid(target) and target.has_method(metrics_method):
		return target.call(metrics_method)
	return {}
