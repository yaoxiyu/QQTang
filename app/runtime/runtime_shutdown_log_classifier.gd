class_name RuntimeShutdownLogClassifier
extends RefCounted


static func classify(reason: String, forced: bool, failed_handles: Array = []) -> Dictionary:
	var expected_interruption := forced or String(reason).contains("forced")
	return {
		"reason": reason,
		"forced": forced,
		"expected_interruption": expected_interruption,
		"has_shutdown_failures": not failed_handles.is_empty(),
		"classification": "expected_interruption" if expected_interruption else ("shutdown_failed" if not failed_handles.is_empty() else "normal_shutdown"),
	}

