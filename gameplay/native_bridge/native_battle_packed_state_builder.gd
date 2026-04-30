class_name NativeBattlePackedStateBuilder
extends RefCounted

const Schema = preload("res://gameplay/native_bridge/native_battle_packed_schema.gd")


func build_empty(tick_id: int, map_width: int, map_height: int) -> Dictionary:
	var header := PackedInt32Array()
	header.resize(Schema.HEADER_STRIDE)
	header[Schema.HEADER_SCHEMA_VERSION] = Schema.SCHEMA_VERSION
	header[Schema.HEADER_TICK_ID] = int(tick_id)
	header[Schema.HEADER_MAP_WIDTH] = int(map_width)
	header[Schema.HEADER_MAP_HEIGHT] = int(map_height)
	header[Schema.HEADER_GRID_CELL_COUNT] = int(map_width * map_height)
	return {
		"schema_version": Schema.SCHEMA_VERSION,
		"header": header,
		"players": PackedInt32Array(),
		"bubbles": PackedInt32Array(),
		"items": PackedInt32Array(),
		"grid": PackedInt32Array(),
		"events": PackedInt32Array(),
	}


func append_player(state: Dictionary, player: Dictionary) -> void:
	var players: PackedInt32Array = state["players"]
	var base := players.size()
	players.resize(base + Schema.PLAYER_STRIDE)
	players[base + Schema.PLAYER_ID_HASH] = Schema.stable_hash(_string_value(player, ["player_id", "entity_id", "peer_id"]))
	players[base + Schema.PLAYER_TEAM_ID_HASH] = Schema.stable_hash(_string_value(player, ["team_id"]))
	players[base + Schema.PLAYER_X_SUBCELL] = _int_value(player, ["x_subcell", "subcell_x", "cell_x", "x"])
	players[base + Schema.PLAYER_Y_SUBCELL] = _int_value(player, ["y_subcell", "subcell_y", "cell_y", "y"])
	players[base + Schema.PLAYER_DIR] = int(player.get("dir", 0))
	players[base + Schema.PLAYER_STATE] = int(player.get("state", 0))
	players[base + Schema.PLAYER_ALIVE] = 1 if bool(player.get("alive", true)) else 0
	players[base + Schema.PLAYER_TRAPPED] = 1 if bool(player.get("trapped", false)) else 0
	players[base + Schema.PLAYER_MOVE_SPEED_SUBCELL] = int(player.get("move_speed_subcell", 0))
	players[base + Schema.PLAYER_BOMB_CAPACITY] = int(player.get("bomb_capacity", 0))
	players[base + Schema.PLAYER_FIRE_POWER] = int(player.get("fire_power", 0))
	players[base + Schema.PLAYER_ACTIVE_BUBBLE_COUNT] = int(player.get("active_bubble_count", 0))
	players[base + Schema.PLAYER_INPUT_SEQ] = int(player.get("input_seq", 0))
	players[base + Schema.PLAYER_CHECKSUM_SALT] = int(player.get("checksum_salt", 0))
	state["players"] = players

	var header: PackedInt32Array = state["header"]
	header[Schema.HEADER_PLAYER_COUNT] = players.size() / Schema.PLAYER_STRIDE
	state["header"] = header


func append_bubble(state: Dictionary, bubble: Dictionary) -> void:
	var bubbles: PackedInt32Array = state["bubbles"]
	var base := bubbles.size()
	bubbles.resize(base + Schema.BUBBLE_STRIDE)
	bubbles[base + Schema.BUBBLE_ID_HASH] = Schema.stable_hash(_string_value(bubble, ["bubble_id", "entity_id"]))
	bubbles[base + Schema.BUBBLE_OWNER_PLAYER_ID_HASH] = Schema.stable_hash(_string_value(bubble, ["owner_player_id", "owner_id"]))
	bubbles[base + Schema.BUBBLE_X_CELL] = int(bubble.get("x_cell", bubble.get("cell_x", 0)))
	bubbles[base + Schema.BUBBLE_Y_CELL] = int(bubble.get("y_cell", bubble.get("cell_y", 0)))
	bubbles[base + Schema.BUBBLE_FIRE_POWER] = int(bubble.get("fire_power", bubble.get("power", 0)))
	bubbles[base + Schema.BUBBLE_STATE] = int(bubble.get("state", 0))
	bubbles[base + Schema.BUBBLE_PLACED_TICK] = int(bubble.get("placed_tick", 0))
	bubbles[base + Schema.BUBBLE_EXPLODE_TICK] = int(bubble.get("explode_tick", 0))
	bubbles[base + Schema.BUBBLE_CHAIN_TRIGGERED] = 1 if bool(bubble.get("chain_triggered", false)) else 0
	bubbles[base + Schema.BUBBLE_STYLE_ID_HASH] = Schema.stable_hash(_string_value(bubble, ["style_id"]))
	bubbles[base + Schema.BUBBLE_RESERVED0] = int(bubble.get("bubble_type", bubble.get("type", 0)))
	bubbles[base + Schema.BUBBLE_RESERVED1] = int(bubble.get("footprint_cells", 1))
	state["bubbles"] = bubbles

	var header: PackedInt32Array = state["header"]
	header[Schema.HEADER_BUBBLE_COUNT] = bubbles.size() / Schema.BUBBLE_STRIDE
	state["header"] = header


func append_item(state: Dictionary, item: Dictionary) -> void:
	var items: PackedInt32Array = state["items"]
	var base := items.size()
	items.resize(base + Schema.ITEM_STRIDE)
	items[base + Schema.ITEM_ID_HASH] = Schema.stable_hash(_string_value(item, ["item_id", "entity_id"]))
	items[base + Schema.ITEM_TYPE_HASH] = Schema.stable_hash(_string_value(item, ["item_type"]))
	items[base + Schema.ITEM_X_CELL] = int(item.get("x_cell", item.get("cell_x", 0)))
	items[base + Schema.ITEM_Y_CELL] = int(item.get("y_cell", item.get("cell_y", 0)))
	items[base + Schema.ITEM_STATE] = int(item.get("state", 0))
	items[base + Schema.ITEM_SPAWN_TICK] = int(item.get("spawn_tick", 0))
	state["items"] = items

	var header: PackedInt32Array = state["header"]
	header[Schema.HEADER_ITEM_COUNT] = items.size() / Schema.ITEM_STRIDE
	state["header"] = header


func append_grid_cell(state: Dictionary, cell: Dictionary) -> void:
	var grid: PackedInt32Array = state["grid"]
	var base := grid.size()
	grid.resize(base + Schema.GRID_STRIDE)
	grid[base + Schema.GRID_CELL_TYPE] = int(cell.get("cell_type", cell.get("tile_type", 0)))
	grid[base + Schema.GRID_BLOCKER_FLAGS] = int(cell.get("blocker_flags", cell.get("tile_flags", 0)))
	grid[base + Schema.GRID_OCCUPANT_FLAGS] = int(cell.get("occupant_flags", 0))
	state["grid"] = grid
	var header: PackedInt32Array = state["header"]
	if header[Schema.HEADER_GRID_CELL_COUNT] <= 0:
		header[Schema.HEADER_GRID_CELL_COUNT] = grid.size() / Schema.GRID_STRIDE
	state["header"] = header


func build_from_snapshot(snapshot: WorldSnapshot, map_width: int, map_height: int) -> Dictionary:
	if snapshot == null:
		return build_empty(0, map_width, map_height)
	var state := build_empty(int(snapshot.tick_id), map_width, map_height)
	for player in snapshot.players:
		if player is Dictionary:
			append_player(state, player)
	for bubble in snapshot.bubbles:
		if bubble is Dictionary:
			append_bubble(state, bubble)
	for item in snapshot.items:
		if item is Dictionary:
			append_item(state, item)
	for wall in snapshot.walls:
		if wall is Dictionary:
			append_grid_cell(state, wall)
	return state


func _string_value(source: Dictionary, keys: Array[String], fallback: String = "") -> String:
	for key in keys:
		if source.has(key):
			return str(source.get(key))
	return fallback


func _int_value(source: Dictionary, keys: Array[String], fallback: int = 0) -> int:
	for key in keys:
		if source.has(key):
			return int(source.get(key))
	return fallback
