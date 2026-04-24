class_name ViewRevisionGuard
extends RefCounted

var _last_key := ""
var _last_revision := -1


func should_skip(key: String, revision: int) -> bool:
	var normalized_key := String(key)
	if normalized_key == _last_key and int(revision) == _last_revision:
		return true
	_last_key = normalized_key
	_last_revision = int(revision)
	return false


func reset() -> void:
	_last_key = ""
	_last_revision = -1
