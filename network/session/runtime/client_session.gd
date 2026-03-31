class_name ClientSession
extends Node

var local_peer_id: int = 0
var last_confirmed_tick: int = 0
var latest_snapshot_tick: int = 0
var latest_checksum: int = 0
var outgoing_input_frames: Array[PlayerInputFrame] = []
var local_input_buffer: InputRingBuffer = InputRingBuffer.new()
var latest_player_summary: Array[Dictionary] = []


func configure(peer_id: int, ring_capacity: int = 64) -> void:
	local_peer_id = peer_id
	local_input_buffer = InputRingBuffer.new(ring_capacity)
	last_confirmed_tick = 0
	latest_snapshot_tick = 0
	latest_checksum = 0
	latest_player_summary.clear()
	outgoing_input_frames.clear()


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


func on_state_summary(summary: Dictionary) -> void:
	latest_snapshot_tick = int(summary.get("tick", 0))
	latest_player_summary = _coerce_player_summary(summary.get("player_summary", summary.get("players", [])))
	latest_checksum = int(summary.get("checksum", latest_checksum))


func on_snapshot(snapshot: Dictionary) -> void:
	on_state_summary(snapshot)


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

func _coerce_player_summary(raw_summary: Variant) -> Array[Dictionary]:
	var coerced: Array[Dictionary] = []
	if raw_summary is Array:
		for entry in raw_summary:
			if entry is Dictionary:
				coerced.append(entry)
	return coerced
