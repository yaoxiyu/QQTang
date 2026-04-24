class_name LogSamplingPolicy
extends RefCounted

static var _tag_counters: Dictionary = {}


static func should_log(tag: String, sample_every: int = 1) -> bool:
	var n: int = max(1, int(sample_every))
	var key: String = String(tag)
	var count: int = int(_tag_counters.get(key, 0)) + 1
	_tag_counters[key] = count
	return count % n == 0


static func reset() -> void:
	_tag_counters.clear()
