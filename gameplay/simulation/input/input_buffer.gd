class_name InputBuffer
extends RefCounted

const NativeInputBufferBridgeScript = preload("res://gameplay/native_bridge/native_input_buffer_bridge.gd")

var frames: Dictionary = {}

var last_ack_tick_by_peer: Dictionary = {}
var _native_bridge: NativeInputBufferBridge = null


func _init() -> void:
	_ensure_native_bridge()


func push_input_frame(frame: InputFrame) -> void:
	frames[frame.tick] = frame


func consume_or_build_for_tick(tick: int, player_slots: Array[int]) -> InputFrame:
	var frame: InputFrame

	if tick in frames:
		frame = frames[tick]
		for slot in player_slots:
			if not frame.has_command(slot):
				frame.set_command(slot, PlayerCommand.neutral())
		return frame

	frame = InputFrame.new()
	frame.tick = tick
	for slot in player_slots:
		frame.set_command(slot, PlayerCommand.neutral())

	frames[tick] = frame
	return frame


func clear_before_tick(tick: int) -> void:
	var to_remove: Array[int] = []
	for frame_tick in frames:
		if frame_tick < tick:
			to_remove.append(frame_tick)

	for frame_tick in to_remove:
		frames.erase(frame_tick)


func get_recorded_ticks() -> Array[int]:
	var ticks: Array[int] = []
	for tick in frames:
		ticks.append(tick)
	ticks.sort()
	return ticks


func push_input(frame: PlayerInputFrame, authority_tick: int = -1) -> Dictionary:
	if frame == null:
		return {"status": "drop_empty"}
	return _push_native_input(frame, authority_tick)


func get_input(peer_id: int, tick_id: int) -> PlayerInputFrame:
	var collected := collect_inputs_for_tick([peer_id], tick_id)
	if not collected.has(peer_id):
		return _make_idle_input(peer_id, tick_id)
	return collected[peer_id]


func collect_inputs_for_tick(peer_ids: Array[int], tick_id: int) -> Dictionary:
	_ensure_native_bridge()
	if _native_bridge == null:
		return {}
	return _native_bridge.collect_inputs_for_tick(peer_ids, tick_id)


func ack_peer(peer_id: int, ack_tick: int) -> void:
	var current := int(last_ack_tick_by_peer.get(peer_id, -1))
	if ack_tick <= current:
		return
	last_ack_tick_by_peer[peer_id] = ack_tick
	_ack_native_peer(peer_id, ack_tick)


func get_last_ack_tick(peer_id: int) -> int:
	return int(last_ack_tick_by_peer.get(peer_id, -1))


func _make_idle_input(peer_id: int, tick_id: int) -> PlayerInputFrame:
	var idle := PlayerInputFrame.new()
	idle.peer_id = peer_id
	idle.tick_id = tick_id
	idle.seq = 0
	idle.move_x = 0
	idle.move_y = 0
	idle.action_bits = 0
	return idle


func clear() -> void:
	frames.clear()
	last_ack_tick_by_peer.clear()
	if _native_bridge != null:
		_native_bridge.clear()


func get_native_metrics() -> Dictionary:
	if _native_bridge == null:
		return {}
	return _native_bridge.get_metrics()


func _ensure_native_bridge() -> void:
	if _native_bridge != null:
		return
	_native_bridge = NativeInputBufferBridgeScript.new()
	_native_bridge.configure(8, 64, 2, false)


func _push_native_input(frame: PlayerInputFrame, authority_tick: int = -1) -> Dictionary:
	_ensure_native_bridge()
	if _native_bridge != null:
		return _native_bridge.push_input_dict(frame.to_dict(), authority_tick)
	return {"status": "drop_native_unavailable"}


func _ack_native_peer(peer_id: int, ack_tick: int) -> void:
	_ensure_native_bridge()
	if _native_bridge != null:
		_native_bridge.ack_peer(peer_id, ack_tick)
