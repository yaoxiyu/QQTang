class_name Phase2PredictedClient
extends RefCounted

var local_peer_id: int = 0
var local_slot: int = -1
var confirmed_tick: int = 0
var predicted_tick: int = 0
var confirmed_checksum: int = 0
var correction_count: int = 0
var last_correction_tick: int = -1

var confirmed_summary: Array[Dictionary] = []
var predicted_summary: Array[Dictionary] = []
var input_history: Dictionary = {}
var predicted_history: Dictionary = {}


func configure(peer_id: int, slot: int) -> void:
	local_peer_id = peer_id
	local_slot = slot
	reset()


func reset() -> void:
	confirmed_tick = 0
	predicted_tick = 0
	confirmed_checksum = 0
	correction_count = 0
	last_correction_tick = -1
	confirmed_summary.clear()
	predicted_summary.clear()
	input_history.clear()
	predicted_history.clear()


func record_local_input(frame: PlayerInputFrame, blocking_summary: Array[Dictionary], grid: GridState) -> void:
	if frame == null:
		return

	input_history[frame.tick_id] = frame.duplicate_for_tick(frame.tick_id)
	if predicted_summary.is_empty():
		if confirmed_summary.is_empty():
			return
		predicted_summary = _duplicate_summary(confirmed_summary)
		predicted_tick = confirmed_tick
		_store_predicted_position(predicted_tick)

	while predicted_tick < frame.tick_id:
		predicted_tick += 1
		var tick_frame: PlayerInputFrame = input_history.get(predicted_tick, null)
		_apply_frame_to_predicted_summary(tick_frame, blocking_summary, grid)
		_store_predicted_position(predicted_tick)


func on_authoritative_state(tick_id: int, summary: Array[Dictionary], checksum: int, blocking_summary: Array[Dictionary], grid: GridState) -> void:
	confirmed_tick = tick_id
	confirmed_checksum = checksum
	confirmed_summary = _duplicate_summary(summary)

	if predicted_summary.is_empty():
		predicted_summary = _duplicate_summary(summary)
		predicted_tick = tick_id
		_store_predicted_position(predicted_tick)
		return

	var authoritative_pos := _find_player_position(confirmed_summary, local_slot)
	var predicted_at_tick: Vector2i = predicted_history.get(tick_id, authoritative_pos)
	if predicted_at_tick != authoritative_pos:
		correction_count += 1
		last_correction_tick = tick_id

	predicted_summary = _duplicate_summary(confirmed_summary)
	predicted_tick = confirmed_tick
	_prune_history_before(confirmed_tick)
	_store_predicted_position(predicted_tick)

	var replay_ticks: Array = input_history.keys()
	replay_ticks.sort()
	for replay_tick in replay_ticks:
		if replay_tick <= confirmed_tick:
			continue
		predicted_tick = replay_tick
		var tick_frame: PlayerInputFrame = input_history.get(replay_tick, null)
		_apply_frame_to_predicted_summary(tick_frame, blocking_summary, grid)
		_store_predicted_position(replay_tick)


func build_confirmed_lines() -> Array[String]:
	return _summary_to_lines(confirmed_summary)


func build_predicted_lines() -> Array[String]:
	return _summary_to_lines(predicted_summary)


func has_prediction_gap() -> bool:
	return _find_player_position(confirmed_summary, local_slot) != _find_player_position(predicted_summary, local_slot)


func get_prediction_gap_text() -> String:
	var confirmed_pos := _find_player_position(confirmed_summary, local_slot)
	var predicted_pos := _find_player_position(predicted_summary, local_slot)
	return "P%d %s -> %s" % [local_slot + 1, str(confirmed_pos), str(predicted_pos)]


func _apply_frame_to_predicted_summary(frame: PlayerInputFrame, blocking_summary: Array[Dictionary], grid: GridState) -> void:
	var summary := predicted_summary
	var player_index := _find_player_index(summary, local_slot)
	if player_index < 0:
		return

	var entry: Dictionary = summary[player_index]
	var current_pos: Vector2i = entry.get("grid_pos", Vector2i(-1, -1))
	if frame == null:
		entry["move_dir"] = Vector2i.ZERO
		summary[player_index] = entry
		predicted_summary = summary
		return

	var move := Vector2i(frame.move_x, frame.move_y)
	if move.x != 0:
		move.y = 0
	if move == Vector2i.ZERO:
		entry["move_dir"] = Vector2i.ZERO
		summary[player_index] = entry
		predicted_summary = summary
		return

	var target := current_pos + move
	if _is_move_blocked(target, summary, blocking_summary, grid, local_slot):
		entry["move_dir"] = Vector2i.ZERO
	else:
		entry["grid_pos"] = target
		entry["move_dir"] = move

	summary[player_index] = entry
	predicted_summary = summary


func _is_move_blocked(target: Vector2i, summary: Array[Dictionary], blocking_summary: Array[Dictionary], grid: GridState, slot: int) -> bool:
	if grid == null or not grid.is_in_bounds(target.x, target.y):
		return true

	var cell := grid.get_static_cell(target.x, target.y)
	if (cell.tile_flags & TileConstants.TILE_BLOCK_MOVE) != 0:
		return true

	for entry in summary:
		if int(entry.get("player_slot", -1)) == slot:
			continue
		if entry.get("grid_pos", Vector2i(-1, -1)) == target:
			return true

	for entry in blocking_summary:
		if int(entry.get("player_slot", -1)) == slot:
			continue
		if entry.get("grid_pos", Vector2i(-1, -1)) == target:
			return true

	return false


func _store_predicted_position(tick_id: int) -> void:
	predicted_history[tick_id] = _find_player_position(predicted_summary, local_slot)


func _find_player_index(summary: Array[Dictionary], slot: int) -> int:
	for i in range(summary.size()):
		if int(summary[i].get("player_slot", -1)) == slot:
			return i
	return -1


func _find_player_position(summary: Array[Dictionary], slot: int) -> Vector2i:
	var index := _find_player_index(summary, slot)
	if index < 0:
		return Vector2i(-1, -1)
	return summary[index].get("grid_pos", Vector2i(-1, -1))


func _summary_to_lines(summary: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	var ordered := _duplicate_summary(summary)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("player_slot", -1)) < int(b.get("player_slot", -1)))
	for entry in ordered:
		lines.append("P%d %s" % [int(entry.get("player_slot", 0)) + 1, str(entry.get("grid_pos", Vector2i(-1, -1)))])
	return lines


func _duplicate_summary(summary: Array[Dictionary]) -> Array[Dictionary]:
	return summary.duplicate(true)


func _prune_history_before(tick_id: int) -> void:
	var old_input_ticks: Array[int] = []
	for key in input_history.keys():
		if key <= tick_id:
			old_input_ticks.append(key)
	for key in old_input_ticks:
		input_history.erase(key)

	var old_predicted_ticks: Array[int] = []
	for key in predicted_history.keys():
		if key < tick_id:
			old_predicted_ticks.append(key)
	for key in old_predicted_ticks:
		predicted_history.erase(key)
