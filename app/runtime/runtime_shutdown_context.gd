class_name RuntimeShutdownContext
extends RefCounted

var reason: String = ""
var forced: bool = false
var started_msec: int = 0
var metadata: Dictionary = {}


func _init(shutdown_reason: String = "", shutdown_forced: bool = false, shutdown_metadata: Dictionary = {}) -> void:
	reason = shutdown_reason
	forced = shutdown_forced
	started_msec = Time.get_ticks_msec()
	metadata = shutdown_metadata.duplicate(true)

