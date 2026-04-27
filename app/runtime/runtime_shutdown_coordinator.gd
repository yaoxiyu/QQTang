class_name RuntimeShutdownCoordinator
extends RefCounted

const RuntimeShutdownContextScript = preload("res://app/runtime/runtime_shutdown_context.gd")
const RuntimeShutdownLogClassifierScript = preload("res://app/runtime/runtime_shutdown_log_classifier.gd")

var _handles: Array[Object] = []
var _shutdown_started: bool = false
var _shutdown_complete: bool = false
var _last_metrics: Dictionary = {}


func register_handle(handle: Object) -> void:
	if handle == null or _handles.has(handle):
		return
	_handles.append(handle)


func unregister_handle(handle: Object) -> void:
	if handle == null:
		return
	_handles.erase(handle)


func shutdown_all(reason: String, forced: bool = false) -> Dictionary:
	if _shutdown_complete:
		return _last_metrics.duplicate(true)
	_shutdown_started = true
	var context = RuntimeShutdownContextScript.new(reason, forced)
	var started_msec := Time.get_ticks_msec()
	var ordered := _live_handles()
	ordered.sort_custom(func(a: Object, b: Object) -> bool:
		return _priority_of(a) < _priority_of(b)
	)
	var failed_handles: Array[String] = []
	var handled: Array[String] = []
	for handle in ordered:
		var name := _name_of(handle)
		handled.append(name)
		if not handle.has_method("shutdown"):
			failed_handles.append(name)
			continue
		handle.call("shutdown", context)
		if handle.has_method("get_shutdown_metrics"):
			var metrics: Variant = handle.call("get_shutdown_metrics")
			if metrics is Dictionary and bool((metrics as Dictionary).get("shutdown_failed", false)):
				failed_handles.append(name)
	_shutdown_complete = true
	var duration := Time.get_ticks_msec() - started_msec
	_last_metrics = {
		"shutdown_reason": reason,
		"shutdown_forced": forced,
		"shutdown_handle_count": ordered.size(),
		"shutdown_handles": handled,
		"shutdown_failed_handles": failed_handles,
		"shutdown_duration_msec": duration,
		"leak_log_classification": RuntimeShutdownLogClassifierScript.classify(reason, forced, failed_handles),
	}
	return _last_metrics.duplicate(true)


func reset() -> void:
	_handles.clear()
	_shutdown_started = false
	_shutdown_complete = false
	_last_metrics.clear()


func build_metrics() -> Dictionary:
	if _last_metrics.is_empty():
		return {
			"shutdown_reason": "",
			"shutdown_forced": false,
			"shutdown_handle_count": _live_handles().size(),
			"shutdown_failed_handles": [],
			"shutdown_duration_msec": 0,
			"leak_log_classification": {},
		}
	return _last_metrics.duplicate(true)


func _live_handles() -> Array[Object]:
	var live: Array[Object] = []
	for handle in _handles:
		if handle != null and is_instance_valid(handle):
			live.append(handle)
	_handles = live.duplicate()
	return live


func _priority_of(handle: Object) -> int:
	return int(handle.call("get_shutdown_priority")) if handle != null and handle.has_method("get_shutdown_priority") else 100


func _name_of(handle: Object) -> String:
	return String(handle.call("get_shutdown_name")) if handle != null and handle.has_method("get_shutdown_name") else "<unnamed>"
