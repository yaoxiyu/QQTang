class_name PlayerInputFrame
extends RefCounted

var peer_id: int = 0
var tick_id: int = 0
var seq: int = 0

var move_x: int = 0
var move_y: int = 0

var action_place: bool = false
var action_skill1: bool = false
var action_skill2: bool = false


func sanitize() -> void:
	move_x = clamp(move_x, -1, 1)
	move_y = clamp(move_y, -1, 1)

	if move_x != 0 and move_y != 0:
		move_y = 0


func duplicate_for_tick(new_tick_id: int) -> PlayerInputFrame:
	var copied := PlayerInputFrame.new()
	copied.peer_id = peer_id
	copied.tick_id = new_tick_id
	copied.seq = seq
	copied.move_x = move_x
	copied.move_y = move_y
	copied.action_place = action_place
	copied.action_skill1 = action_skill1
	copied.action_skill2 = action_skill2
	return copied


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"tick_id": tick_id,
		"seq": seq,
		"move_x": move_x,
		"move_y": move_y,
		"action_place": action_place,
		"action_skill1": action_skill1,
		"action_skill2": action_skill2,
	}


static func from_dict(data: Dictionary) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.peer_id = int(data.get("peer_id", 0))
	frame.tick_id = int(data.get("tick_id", 0))
	frame.seq = int(data.get("seq", frame.tick_id))
	frame.move_x = int(data.get("move_x", 0))
	frame.move_y = int(data.get("move_y", 0))
	frame.action_place = bool(data.get("action_place", false))
	frame.action_skill1 = bool(data.get("action_skill1", false))
	frame.action_skill2 = bool(data.get("action_skill2", false))
	frame.sanitize()
	return frame
