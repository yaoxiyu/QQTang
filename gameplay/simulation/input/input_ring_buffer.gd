class_name InputRingBuffer
extends RefCounted

var capacity: int = 64
var frames: Dictionary = {}


func _init(p_capacity: int = 64) -> void:
	capacity = max(1, p_capacity)


func put(frame: PlayerInputFrame) -> void:
	if frame == null:
		return

	frame.sanitize()
	frames[frame.tick_id] = frame

	var min_tick := frame.tick_id - capacity
	var to_remove: Array[int] = []
	for tick in frames.keys():
		if tick < min_tick:
			to_remove.append(tick)

	for tick in to_remove:
		frames.erase(tick)


func get_frame(tick_id: int) -> PlayerInputFrame:
	return frames.get(tick_id, null)


func get_range(from_tick: int, to_tick: int) -> Array[PlayerInputFrame]:
	var out: Array[PlayerInputFrame] = []
	for tick in range(from_tick, to_tick + 1):
		var frame = get_frame(tick)
		if frame != null:
			out.append(frame)
	return out


func clear() -> void:
	frames.clear()
