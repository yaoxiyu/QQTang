class_name NativeMovementBridge
extends RefCounted

const LogSimulationScript = preload("res://app/logging/log_simulation.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")
const NativeWireContractScript = preload("res://gameplay/native_bridge/native_wire_contract.gd")
const MovementTuning = preload("res://gameplay/simulation/movement/movement_tuning.gd")
const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")

const LOG_TAG := "simulation.native.movement"
const MOVEMENT_PAYLOAD_MAGIC := 1297371473 # "QQTM" little-endian i32 marker.


func step_players(ctx: SimContext, player_ids: Array[int]) -> Dictionary:
	var empty_result := {
		"player_updates": [],
		"blocked_events": [],
		"cell_changes": [],
		"bubble_ignore_removals": [],
	}
	if ctx == null or ctx.state == null or ctx.queries == null:
		return empty_result

	var kernel := NativeKernelRuntimeScript.get_movement_kernel()
	if kernel == null:
		return empty_result

	var player_records := _pack_player_records(ctx, player_ids)
	var bubble_records := _pack_bubble_records(ctx)
	var bubble_ignore_values := _pack_bubble_ignore_values(ctx)
	var blocked_grid_records := _pack_blocked_grid_records(ctx)
	var tuning := _pack_tuning()
	var result_blob_variant: Variant = null
	if kernel.has_method("step_players_packed"):
		result_blob_variant = kernel.step_players_packed(
			player_records,
			bubble_records,
			bubble_ignore_values,
			blocked_grid_records,
			int(tuning.get("movement_step_units", 0)),
			int(tuning.get("turn_snap_window_units", 0)),
			int(tuning.get("pass_absorb_window_units", 0))
		)
	else:
		result_blob_variant = kernel.step_players(
			_encode_input_blob(
				player_records,
				bubble_records,
				bubble_ignore_values,
				blocked_grid_records,
				tuning
			)
		)
	if not (result_blob_variant is PackedByteArray):
		LogSimulationScript.warn(
			"[native_movement_bridge] movement kernel returned non-byte result, fallback to GDScript",
			"",
			0,
			LOG_TAG
		)
		return empty_result

	var result_variant: Variant = bytes_to_var(result_blob_variant)
	if not (result_variant is Dictionary):
		LogSimulationScript.warn(
			"[native_movement_bridge] movement kernel decoded non-dictionary result, fallback to GDScript",
			"",
			0,
			LOG_TAG
		)
		return empty_result

	return _decode_result(result_variant)


func _pack_player_records(ctx: SimContext, player_ids: Array[int]) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for player_id in player_ids:
		var player := ctx.state.players.get_player(int(player_id))
		if player == null:
			continue
		var command := player.last_applied_command
		packed.append(player.entity_id)
		packed.append(player.player_slot)
		packed.append(int(player.alive))
		packed.append(player.life_state)
		packed.append(player.cell_x)
		packed.append(player.cell_y)
		packed.append(player.offset_x)
		packed.append(player.offset_y)
		packed.append(player.last_non_zero_move_x)
		packed.append(player.last_non_zero_move_y)
		packed.append(player.facing)
		packed.append(player.move_state)
		packed.append(player.move_phase_ticks)
		packed.append(player.speed_level)
		packed.append(_sanitize_axis(command.move_x, command.move_y).x)
		packed.append(_sanitize_axis(command.move_x, command.move_y).y)
	return packed


func _pack_bubble_records(ctx: SimContext) -> PackedInt32Array:
	var packed := PackedInt32Array()
	var ignore_offset := 0
	for bubble in _get_sorted_bubbles(ctx):
		if bubble == null:
			continue
		packed.append(bubble.entity_id)
		packed.append(int(bubble.alive))
		packed.append(bubble.cell_x)
		packed.append(bubble.cell_y)
		packed.append(bubble.ignore_player_ids.size())
		packed.append(ignore_offset)
		ignore_offset += bubble.ignore_player_ids.size()
	return packed


func _pack_bubble_ignore_values(ctx: SimContext) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for bubble in _get_sorted_bubbles(ctx):
		if bubble == null:
			continue
		for ignored_player_id in bubble.ignore_player_ids:
			packed.append(int(ignored_player_id))
	return packed


func _pack_blocked_grid_records(ctx: SimContext) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for y in range(ctx.state.grid.height):
		for x in range(ctx.state.grid.width):
			var cell := ctx.state.grid.get_static_cell(x, y)
			packed.append(x)
			packed.append(y)
			packed.append(int((cell.tile_flags & TileConstants.TILE_BLOCK_MOVE) != 0))
			packed.append(ctx.queries.get_bubble_at(x, y))
			packed.append(0)
	return packed


func _pack_command_records(ctx: SimContext, player_ids: Array[int]) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for player_id in player_ids:
		var player := ctx.state.players.get_player(int(player_id))
		if player == null:
			continue
		var sanitized := _sanitize_axis(player.last_applied_command.move_x, player.last_applied_command.move_y)
		packed.append(player.entity_id)
		packed.append(sanitized.x)
		packed.append(sanitized.y)
	return packed


func _pack_tuning() -> Dictionary:
	return {
		"movement_step_units": MovementTuning.movement_step_units(),
		"turn_snap_window_units": MovementTuning.turn_snap_window_units(),
		"pass_absorb_window_units": MovementTuning.pass_absorb_window_units(),
	}


func _encode_input_blob(
	player_records: PackedInt32Array,
	bubble_records: PackedInt32Array,
	bubble_ignore_values: PackedInt32Array,
	blocked_grid_records: PackedInt32Array,
	tuning: Dictionary
) -> PackedByteArray:
	var blob := PackedByteArray()
	var total_i32_count := 5
	total_i32_count += 1 + player_records.size()
	total_i32_count += 1 + bubble_records.size()
	total_i32_count += 1 + bubble_ignore_values.size()
	total_i32_count += 1 + blocked_grid_records.size()
	blob.resize(total_i32_count * 4)
	var offset := 0
	offset = _write_i32(blob, offset, MOVEMENT_PAYLOAD_MAGIC)
	offset = _write_i32(blob, offset, NativeWireContractScript.MOVEMENT_WIRE_VERSION)
	offset = _write_i32(blob, offset, int(tuning.get("movement_step_units", 0)))
	offset = _write_i32(blob, offset, int(tuning.get("turn_snap_window_units", 0)))
	offset = _write_i32(blob, offset, int(tuning.get("pass_absorb_window_units", 0)))
	offset = _write_i32_array(blob, offset, player_records)
	offset = _write_i32_array(blob, offset, bubble_records)
	offset = _write_i32_array(blob, offset, bubble_ignore_values)
	_write_i32_array(blob, offset, blocked_grid_records)
	return blob


func _write_i32(blob: PackedByteArray, offset: int, value: int) -> int:
	blob.encode_s32(offset, value)
	return offset + 4


func _write_i32_array(blob: PackedByteArray, offset: int, values: PackedInt32Array) -> int:
	offset = _write_i32(blob, offset, values.size())
	for value in values:
		offset = _write_i32(blob, offset, int(value))
	return offset


func _decode_result(raw_result: Dictionary) -> Dictionary:
	var version := int(raw_result.get("version", 0))
	if version != NativeWireContractScript.MOVEMENT_WIRE_VERSION:
		LogSimulationScript.warn(
			"[native_movement_bridge] movement result version mismatch: expected=%d actual=%d"
				% [NativeWireContractScript.MOVEMENT_WIRE_VERSION, version],
			"",
			0,
			LOG_TAG
		)
		return {
			"player_updates": [],
			"blocked_events": [],
			"cell_changes": [],
			"bubble_ignore_removals": [],
		}
	return {
		"player_updates": _coerce_dict_array(raw_result.get("player_updates", [])),
		"blocked_events": _coerce_dict_array(raw_result.get("blocked_events", [])),
		"cell_changes": _coerce_dict_array(raw_result.get("cell_changes", [])),
		"bubble_ignore_removals": _coerce_dict_array(raw_result.get("bubble_ignore_removals", [])),
	}


func _coerce_dict_array(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_value is Array:
		for entry in raw_value:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _sanitize_axis(move_x: int, move_y: int) -> Vector2i:
	move_x = clampi(move_x, -1, 1)
	move_y = clampi(move_y, -1, 1)
	if move_x != 0 and move_y != 0:
		return Vector2i.ZERO
	return Vector2i(move_x, move_y)


func _get_sorted_bubbles(ctx: SimContext) -> Array[BubbleState]:
	var bubbles: Array[BubbleState] = []
	for bubble_id in ctx.state.bubbles.active_ids:
		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
		if bubble != null:
			bubbles.append(bubble)
	bubbles.sort_custom(func(a: BubbleState, b: BubbleState): return a.entity_id < b.entity_id)
	return bubbles
