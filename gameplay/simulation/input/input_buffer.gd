class_name InputBuffer
extends RefCounted

const NativeInputBufferBridgeScript = preload("res://gameplay/native_bridge/native_input_buffer_bridge.gd")
const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")

# LegacyMigration compatibility: tick -> InputFrame
var frames: Dictionary = {}

# LegacyMigration sync model: peer_id -> (tick_id -> PlayerInputFrame)
var frames_by_peer: Dictionary = {}
var last_ack_tick_by_peer: Dictionary = {}
var last_input_by_peer: Dictionary = {}
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


func push_input(frame: PlayerInputFrame) -> void:
	if frame == null:
		return

	frame.sanitize()

	if not frames_by_peer.has(frame.peer_id):
		frames_by_peer[frame.peer_id] = {}

	var peer_frames: Dictionary = frames_by_peer[frame.peer_id]
	if peer_frames.has(frame.tick_id):
		_merge_input_frame(peer_frames[frame.tick_id], frame)
		last_input_by_peer[frame.peer_id] = peer_frames[frame.tick_id]
		return

	peer_frames[frame.tick_id] = frame
	last_input_by_peer[frame.peer_id] = frame
	_shadow_push_input(frame)


func get_input(peer_id: int, tick_id: int) -> PlayerInputFrame:
	if not frames_by_peer.has(peer_id):
		return _make_idle_input(peer_id, tick_id)

	var peer_frames: Dictionary = frames_by_peer[peer_id]
	if peer_frames.has(tick_id):
		return peer_frames[tick_id]

	return _fallback_input(peer_id, tick_id)


func collect_inputs_for_tick(peer_ids: Array[int], tick_id: int) -> Dictionary:
	var result: Dictionary = {}
	for peer_id in peer_ids:
		result[peer_id] = get_input(peer_id, tick_id)
	return _shadow_collect_inputs(peer_ids, tick_id, result)


func ack_peer(peer_id: int, ack_tick: int) -> void:
	last_ack_tick_by_peer[peer_id] = ack_tick

	if not frames_by_peer.has(peer_id):
		return

	var peer_frames: Dictionary = frames_by_peer[peer_id]
	var to_remove: Array[int] = []
	for tick in peer_frames.keys():
		if tick <= ack_tick:
			to_remove.append(tick)

	for tick in to_remove:
		peer_frames.erase(tick)
	_shadow_ack_peer(peer_id, ack_tick)


func get_last_ack_tick(peer_id: int) -> int:
	return int(last_ack_tick_by_peer.get(peer_id, -1))


func _fallback_input(peer_id: int, tick_id: int) -> PlayerInputFrame:
	if not last_input_by_peer.has(peer_id):
		return _make_idle_input(peer_id, tick_id)

	var last: PlayerInputFrame = last_input_by_peer[peer_id]
	var fallback := PlayerInputFrame.new()
	fallback.peer_id = peer_id
	fallback.tick_id = tick_id
	fallback.seq = last.seq
	fallback.move_x = last.move_x
	fallback.move_y = last.move_y
	fallback.action_place = false
	fallback.action_skill1 = false
	fallback.action_skill2 = false
	fallback.sanitize()
	return fallback


func _make_idle_input(peer_id: int, tick_id: int) -> PlayerInputFrame:
	var idle := PlayerInputFrame.new()
	idle.peer_id = peer_id
	idle.tick_id = tick_id
	idle.seq = 0
	idle.move_x = 0
	idle.move_y = 0
	idle.action_place = false
	idle.action_skill1 = false
	idle.action_skill2 = false
	return idle


func clear() -> void:
	frames.clear()
	frames_by_peer.clear()
	last_ack_tick_by_peer.clear()
	last_input_by_peer.clear()
	if _native_bridge != null:
		_native_bridge.clear()


func _merge_input_frame(existing: PlayerInputFrame, incoming: PlayerInputFrame) -> void:
	if existing == null or incoming == null:
		return
	if incoming.seq >= existing.seq:
		existing.seq = incoming.seq
		existing.move_x = incoming.move_x
		existing.move_y = incoming.move_y
	existing.action_place = existing.action_place or incoming.action_place
	existing.action_skill1 = existing.action_skill1 or incoming.action_skill1
	existing.action_skill2 = existing.action_skill2 or incoming.action_skill2
	existing.sanitize()
	_shadow_push_input(incoming)


func get_native_shadow_metrics() -> Dictionary:
	if _native_bridge == null:
		return {}
	return _native_bridge.get_metrics()


func _ensure_native_bridge() -> void:
	if _native_bridge != null:
		return
	_native_bridge = NativeInputBufferBridgeScript.new()
	_native_bridge.configure(8, 64, 2, false)


func _shadow_push_input(frame: PlayerInputFrame) -> void:
	_ensure_native_bridge()
	if _native_bridge != null:
		_native_bridge.push_input_dict(frame.to_dict(), -1)


func _shadow_ack_peer(peer_id: int, ack_tick: int) -> void:
	_ensure_native_bridge()
	if _native_bridge != null:
		_native_bridge.ack_peer(peer_id, ack_tick)


func _shadow_collect_inputs(peer_ids: Array[int], tick_id: int, baseline_result: Dictionary) -> Dictionary:
	_ensure_native_bridge()
	if _native_bridge == null:
		return baseline_result
	var native_result := _native_bridge.collect_native_inputs_for_tick(peer_ids, tick_id)
	if NativeFeatureFlagsScript.enable_native_input_buffer_shadow:
		_native_bridge.note_shadow_result(_normalized_frame_map(baseline_result) == _normalized_frame_map(native_result))
	if NativeFeatureFlagsScript.enable_native_input_buffer_execute:
		return native_result
	return baseline_result


func _normalized_frame_map(frame_map: Dictionary) -> Array:
	var keys := frame_map.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		var frame: PlayerInputFrame = frame_map[key]
		if frame == null:
			continue
		result.append([
			int(key),
			frame.peer_id,
			frame.tick_id,
			frame.seq,
			frame.move_x,
			frame.move_y,
			frame.action_place,
			frame.action_skill1,
			frame.action_skill2,
		])
	return result
