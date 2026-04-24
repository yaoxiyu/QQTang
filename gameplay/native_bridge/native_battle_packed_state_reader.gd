class_name NativeBattlePackedStateReader
extends RefCounted

const Schema = preload("res://gameplay/native_bridge/native_battle_packed_schema.gd")


static func get_tick_id(state: Dictionary) -> int:
	var header: PackedInt32Array = state.get("header", PackedInt32Array())
	if header.size() <= Schema.HEADER_TICK_ID:
		return 0
	return int(header[Schema.HEADER_TICK_ID])


static func get_player_count(state: Dictionary) -> int:
	var header: PackedInt32Array = state.get("header", PackedInt32Array())
	var count := int(header[Schema.HEADER_PLAYER_COUNT]) if header.size() > Schema.HEADER_PLAYER_COUNT else 0
	if count <= 0:
		var players: PackedInt32Array = state.get("players", PackedInt32Array())
		return players.size() / Schema.PLAYER_STRIDE
	return count


static func get_bubble_count(state: Dictionary) -> int:
	var header: PackedInt32Array = state.get("header", PackedInt32Array())
	var count := int(header[Schema.HEADER_BUBBLE_COUNT]) if header.size() > Schema.HEADER_BUBBLE_COUNT else 0
	if count <= 0:
		var bubbles: PackedInt32Array = state.get("bubbles", PackedInt32Array())
		return bubbles.size() / Schema.BUBBLE_STRIDE
	return count


static func get_item_count(state: Dictionary) -> int:
	var header: PackedInt32Array = state.get("header", PackedInt32Array())
	var count := int(header[Schema.HEADER_ITEM_COUNT]) if header.size() > Schema.HEADER_ITEM_COUNT else 0
	if count <= 0:
		var items: PackedInt32Array = state.get("items", PackedInt32Array())
		return items.size() / Schema.ITEM_STRIDE
	return count


static func get_grid_cell_count(state: Dictionary) -> int:
	var header: PackedInt32Array = state.get("header", PackedInt32Array())
	if header.size() <= Schema.HEADER_GRID_CELL_COUNT:
		return 0
	return int(header[Schema.HEADER_GRID_CELL_COUNT])
