extends RefCounted


static func snapshot_from_message(message: Dictionary) -> WorldSnapshot:
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = int(message.get("tick", 0))
	snapshot.players = coerce_dictionary_array(message.get("players", []))
	snapshot.bubbles = coerce_dictionary_array(message.get("bubbles", []))
	snapshot.items = coerce_dictionary_array(message.get("items", []))
	snapshot.walls = coerce_dictionary_array(message.get("walls", []))
	snapshot.breakable_blocks_remaining = int(message.get("breakable_blocks_remaining", -1))
	snapshot.match_state = coerce_dictionary(message.get("match_state", {}))
	snapshot.mode_state = coerce_dictionary(message.get("mode_state", {}))
	snapshot.rng_state = int(message.get("rng_state", 0))
	snapshot.checksum = int(message.get("checksum", 0))
	return snapshot


static func coerce_dictionary_array(raw_value: Variant) -> Array[Dictionary]:
	var coerced: Array[Dictionary] = []
	if raw_value is Array:
		for entry in raw_value:
			if entry is Dictionary:
				coerced.append(normalize_snapshot_dictionary(entry))
	return coerced


static func coerce_dictionary(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return normalize_snapshot_dictionary(raw_value)
	return {}


static func normalize_snapshot_dictionary(raw_value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key in raw_value.keys():
		normalized[key] = normalize_snapshot_value(raw_value[key])
	return normalized


static func normalize_snapshot_value(raw_value: Variant) -> Variant:
	if raw_value is Dictionary:
		return normalize_snapshot_dictionary(raw_value)
	if raw_value is Array:
		var normalized_array: Array = []
		for entry in raw_value:
			normalized_array.append(normalize_snapshot_value(entry))
		return normalized_array
	if raw_value is float and is_equal_approx(raw_value, round(raw_value)):
		return int(round(raw_value))
	return raw_value


static func decode_events(raw_events: Variant) -> Array:
	var decoded: Array = []
	if not (raw_events is Array):
		return decoded
	for raw_event in raw_events:
		if not (raw_event is Dictionary):
			continue
		var event := SimEvent.new(
			int(raw_event.get("tick", 0)),
			int(raw_event.get("event_type", 0))
		)
		event.payload = denormalize_variant(raw_event.get("payload", {}))
		decoded.append(event)
	return decoded


static func apply_authority_sideband(
	world: SimWorld,
	message: Dictionary,
	include_walls: bool,
	include_mode_state: bool
) -> int:
	if world == null:
		return -1
	var message_tick := int(message.get("tick", 0))
	var has_bubbles := message.has("bubbles")
	var has_items := message.has("items")
	var has_walls := include_walls and message.has("walls")
	var has_match_state := message.has("match_state")
	var has_mode_state := include_mode_state and message.has("mode_state")
	var bubbles: Array[Dictionary] = coerce_dictionary_array(message.get("bubbles", []))
	var items: Array[Dictionary] = coerce_dictionary_array(message.get("items", []))
	var walls: Array[Dictionary] = []
	var match_state: Dictionary = coerce_dictionary(message.get("match_state", {}))
	var mode_state: Dictionary = {}
	if has_walls:
		walls = coerce_dictionary_array(message.get("walls", []))
	if has_mode_state:
		mode_state = coerce_dictionary(message.get("mode_state", {}))
	if not has_bubbles and not has_items and not has_walls and not has_match_state and not has_mode_state:
		return -1
	if has_bubbles:
		restore_bubbles(world, bubbles)
	if has_items:
		restore_items(world, items)
	if has_walls:
		restore_walls(world, walls)
	if has_match_state:
		restore_match_state(world, match_state, message_tick)
	if has_mode_state:
		restore_mode_state(world, mode_state)
	world.rebuild_runtime_indexes()
	return message_tick


static func apply_authority_delta_sideband(world: SimWorld, message: Dictionary) -> int:
	if world == null or message.is_empty():
		return -1
	var message_tick := int(message.get("tick", 0))
	for bubble_id in _coerce_int_array(message.get("removed_bubble_ids", [])):
		world.state.bubbles.despawn_bubble(bubble_id)
	for item_id in _coerce_int_array(message.get("removed_item_ids", [])):
		world.state.items.despawn_item(item_id)
	for bubble in coerce_dictionary_array(message.get("changed_bubbles", [])):
		world.state.bubbles.restore_bubble_from_snapshot(bubble)
	for item in coerce_dictionary_array(message.get("changed_items", [])):
		world.state.items.restore_item_from_snapshot(item)
	world.rebuild_runtime_indexes()
	return message_tick


static func restore_bubbles(world: SimWorld, bubbles: Array[Dictionary]) -> void:
	world.state.bubbles.clear()
	for data in bubbles:
		world.state.bubbles.restore_bubble_from_snapshot(data)


static func _coerce_int_array(raw_value: Variant) -> Array[int]:
	var result: Array[int] = []
	if not (raw_value is Array):
		return result
	for entry in raw_value:
		result.append(int(entry))
	return result


static func restore_items(world: SimWorld, items: Array[Dictionary]) -> void:
	world.state.items.clear()
	for data in items:
		world.state.items.restore_item_from_snapshot(data)


static func restore_walls(world: SimWorld, walls: Array[Dictionary]) -> void:
	for wall in walls:
		var cell_x := int(wall.get("cell_x", 0))
		var cell_y := int(wall.get("cell_y", 0))
		var cell = world.state.grid.get_static_cell(cell_x, cell_y)
		cell.tile_type = int(wall.get("tile_type", cell.tile_type))
		cell.tile_flags = int(wall.get("tile_flags", cell.tile_flags))
		cell.theme_variant = int(wall.get("theme_variant", cell.theme_variant))
		world.state.grid.set_static_cell(cell_x, cell_y, cell)


static func restore_mode_state(world: SimWorld, mode_state: Dictionary) -> void:
	if mode_state.is_empty():
		return
	world.state.mode.mode_runtime_type = StringName(mode_state.get("mode_runtime_type", "default"))
	world.state.mode.team_alive_counts = mode_state.get("team_alive_counts", {}).duplicate(true)
	world.state.mode.mode_timer_ticks = int(mode_state.get("mode_timer_ticks", 0))
	world.state.mode.payload_owner_id = int(mode_state.get("payload_owner_id", -1))
	world.state.mode.payload_cell_x = int(mode_state.get("payload_cell_x", -1))
	world.state.mode.payload_cell_y = int(mode_state.get("payload_cell_y", -1))
	world.state.mode.sudden_death_active = bool(mode_state.get("sudden_death_active", false))
	world.state.mode.custom_ints = mode_state.get("custom_ints", {}).duplicate(true)
	world.state.mode.custom_flags = mode_state.get("custom_flags", {}).duplicate(true)


static func restore_match_state(world: SimWorld, match_state: Dictionary, tick_id: int) -> void:
	if world == null or match_state.is_empty():
		return
	world.state.match_state.tick = tick_id
	world.state.match_state.phase = int(match_state.get("phase", world.state.match_state.phase))
	world.state.match_state.winner_team_id = int(match_state.get("winner_team_id", world.state.match_state.winner_team_id))
	world.state.match_state.winner_player_id = int(match_state.get("winner_player_id", world.state.match_state.winner_player_id))
	world.state.match_state.ended_reason = int(match_state.get("ended_reason", world.state.match_state.ended_reason))
	world.state.match_state.remaining_ticks = int(match_state.get("remaining_ticks", world.state.match_state.remaining_ticks))


static func denormalize_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var tagged_type := String(value.get("__type", ""))
		if tagged_type == "Vector2i":
			return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
		if tagged_type == "Vector2":
			return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
		var denormalized: Dictionary = {}
		for key in value.keys():
			if String(key) == "__type":
				continue
			denormalized[key] = denormalize_variant(value[key])
		return denormalized
	if value is Array:
		var denormalized_array: Array = []
		for entry in value:
			denormalized_array.append(denormalize_variant(entry))
		return denormalized_array
	return value


static func apply_remote_player_summary(predicted_world: SimWorld, player_summary: Array[Dictionary]) -> bool:
	if predicted_world == null or player_summary.is_empty():
		return false
	var controlled_slot := int(predicted_world.state.runtime_flags.client_controlled_player_slot)
	var any_updated := false
	for entry in player_summary:
		var player := find_predicted_player_for_summary(predicted_world, entry)
		if player == null:
			continue
		if player.player_slot == controlled_slot:
			apply_local_authoritative_player_resource_summary(player, entry)
			predicted_world.state.players.update_player(player)
			any_updated = true
			continue
		var resolved_grid := resolve_summary_vector2i(entry, "grid_pos", "grid_cell_x", "grid_cell_y", Vector2i(player.cell_x, player.cell_y))
		var resolved_move_progress := resolve_summary_vector2i(entry, "move_progress", "move_progress_x", "move_progress_y", Vector2i(player.offset_x, player.offset_y))
		var resolved_move_dir := resolve_summary_vector2i(entry, "move_dir", "move_dir_x", "move_dir_y", Vector2i(player.last_non_zero_move_x, player.last_non_zero_move_y))
		player.cell_x = resolved_grid.x
		player.cell_y = resolved_grid.y
		player.offset_x = resolved_move_progress.x
		player.offset_y = resolved_move_progress.y
		player.last_non_zero_move_x = resolved_move_dir.x
		player.last_non_zero_move_y = resolved_move_dir.y
		player.alive = bool(entry.get("alive", player.alive))
		player.life_state = int(entry.get("life_state", player.life_state))
		player.facing = int(entry.get("facing", player.facing))
		player.move_state = int(entry.get("move_state", player.move_state))
		player.move_remainder_units = int(entry.get("move_remainder_units", player.move_remainder_units))
		predicted_world.state.players.update_player(player)
		any_updated = true
	if any_updated:
		predicted_world.rebuild_runtime_indexes()
	return any_updated


static func apply_local_authoritative_player_resource_summary(player: PlayerState, entry: Dictionary) -> void:
	if player == null or entry.is_empty():
		return
	if entry.has("speed_level"):
		player.speed_level = int(entry.get("speed_level", player.speed_level))
	if entry.has("max_speed_level"):
		player.max_speed_level = int(entry.get("max_speed_level", player.max_speed_level))
	if entry.has("bomb_capacity"):
		player.bomb_capacity = int(entry.get("bomb_capacity", player.bomb_capacity))
	if entry.has("max_bomb_capacity"):
		player.max_bomb_capacity = int(entry.get("max_bomb_capacity", player.max_bomb_capacity))
	if entry.has("bomb_available"):
		player.bomb_available = int(entry.get("bomb_available", player.bomb_available))
	if entry.has("bomb_range"):
		player.bomb_range = int(entry.get("bomb_range", player.bomb_range))
	if entry.has("max_bomb_range"):
		player.max_bomb_range = int(entry.get("max_bomb_range", player.max_bomb_range))


static func resolve_summary_vector2i(
	entry: Dictionary,
	legacy_vector_key: String,
	x_key: String,
	y_key: String,
	default_value: Vector2i
) -> Vector2i:
	if entry.has(x_key) or entry.has(y_key):
		return Vector2i(int(entry.get(x_key, default_value.x)), int(entry.get(y_key, default_value.y)))
	var raw_value: Variant = entry.get(legacy_vector_key, default_value)
	if raw_value is Vector2i:
		return raw_value
	if raw_value is Vector2:
		return Vector2i(int(raw_value.x), int(raw_value.y))
	if raw_value is Dictionary:
		return Vector2i(int(raw_value.get("x", default_value.x)), int(raw_value.get("y", default_value.y)))
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2i(int(raw_value[0]), int(raw_value[1]))
	return default_value


static func find_predicted_player_for_summary(predicted_world: SimWorld, entry: Dictionary) -> PlayerState:
	if predicted_world == null:
		return null
	var entity_id := int(entry.get("entity_id", -1))
	if entity_id >= 0:
		var by_entity := predicted_world.state.players.get_player(entity_id)
		if by_entity != null:
			return by_entity
	var player_slot := int(entry.get("player_slot", -1))
	if player_slot < 0:
		return null
	for player_id in predicted_world.state.players.active_ids:
		var player := predicted_world.state.players.get_player(player_id)
		if player != null and player.player_slot == player_slot:
			return player
	return null
