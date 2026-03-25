class_name ClientSession
extends Node

var local_peer_id: int = 0
var last_confirmed_tick: int = 0
var latest_snapshot_tick: int = 0
var outgoing_input_frames: Array[PlayerInputFrame] = []
var local_input_buffer: InputRingBuffer = InputRingBuffer.new()
var latest_player_summary: Array[Dictionary] = []


func configure(peer_id: int, ring_capacity: int = 64) -> void:
	local_peer_id = peer_id
	local_input_buffer = InputRingBuffer.new(ring_capacity)


func send_input(frame: PlayerInputFrame) -> void:
	frame.peer_id = local_peer_id
	frame.sanitize()
	local_input_buffer.put(frame)
	outgoing_input_frames.append(frame)


func flush_outgoing_inputs() -> Array[PlayerInputFrame]:
	var frames := outgoing_input_frames.duplicate()
	outgoing_input_frames.clear()
	return frames


func on_input_ack(ack_tick: int) -> void:
	last_confirmed_tick = ack_tick


func on_snapshot(snapshot: Dictionary) -> void:
	latest_snapshot_tick = int(snapshot.get("tick", 0))
	latest_player_summary = snapshot.get("players", [])


func sample_input_for_tick(tick_id: int, move_x: int, move_y: int, action_place: bool = false) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.peer_id = local_peer_id
	frame.tick_id = tick_id
	frame.seq = tick_id
	frame.move_x = move_x
	frame.move_y = move_y
	frame.action_place = action_place
	frame.sanitize()
	return frame


func get_local_frame(tick_id: int) -> PlayerInputFrame:
	return local_input_buffer.get_frame(tick_id)
