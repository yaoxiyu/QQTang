class_name PlayerInputFrame
extends RefCounted

const BIT_PLACE  := 1 << 0
const BIT_SKILL1 := 1 << 1
const BIT_SKILL2 := 1 << 2

var peer_id: int = 0
var tick_id: int = 0
var seq: int = 0

var move_x: int = 0
var move_y: int = 0

var action_bits: int = 0


func sanitize() -> void:
	move_x = clamp(move_x, -1, 1)
	move_y = clamp(move_y, -1, 1)

	if move_x != 0 and move_y != 0:
		move_y = 0
	action_bits &= 0x7


func duplicate_for_tick(new_tick_id: int) -> PlayerInputFrame:
	var copied := PlayerInputFrame.new()
	copied.peer_id = peer_id
	copied.tick_id = new_tick_id
	copied.seq = seq
	copied.move_x = move_x
	copied.move_y = move_y
	copied.action_bits = action_bits
	return copied


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"tick_id": tick_id,
		"seq": seq,
		"move_x": move_x,
		"move_y": move_y,
		"action_bits": action_bits,
	}


static func from_dict(data: Dictionary) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.peer_id = int(data.get("peer_id", 0))
	frame.tick_id = int(data.get("tick_id", 0))
	frame.seq = int(data.get("seq", frame.tick_id))
	frame.move_x = int(data.get("move_x", 0))
	frame.move_y = int(data.get("move_y", 0))
	frame.action_bits = int(data.get("action_bits", 0))
	frame.sanitize()
	return frame


static func idle(peer_id: int, tick_id: int) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.peer_id = peer_id
	frame.tick_id = tick_id
	frame.seq = tick_id
	frame.move_x = 0
	frame.move_y = 0
	frame.action_bits = 0
	return frame
