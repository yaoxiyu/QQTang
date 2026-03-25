class_name TestAssert
extends RefCounted


static func is_true(condition: bool, message: String, prefix: String = "test") -> bool:
	if condition:
		return true
	push_error("%s: FAIL - %s" % [prefix, message])
	return false
