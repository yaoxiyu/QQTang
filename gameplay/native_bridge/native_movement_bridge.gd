class_name NativeMovementBridge
extends RefCounted

const LogSimulationScript = preload("res://app/logging/log_simulation.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")
const MovementTuning = preload("res://gameplay/simulation/movement/movement_tuning.gd")
const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")

const LOG_TAG := "simulation.native.movement"
const WIRE_VERSION := 1


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

	var payload := {
		"version": WIRE_VERSION,
		"player_records": _pack_player_records(ctx, player_ids),
		"bubble_records": _pack_bubble_records(ctx),
		"bubble_ignore_values": _pack_bubble_ignore_values(ctx),
		"blocked_grid_records": _pack_blocked_grid_records(ctx),
		"command_records": _pack_command_records(ctx, player_ids),
		"tuning": _pack_tuning(),
	}
	var input_blob := var_to_bytes(payload)
	var result_blob_variant: Variant = kernel.step_players(input_blob)
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
	for bubble_id in ctx.state.bubbles.active_ids:
		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
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
	for bubble_id in ctx.state.bubbles.active_ids:
		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
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


func _decode_result(raw_result: Dictionary) -> Dictionary:
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
