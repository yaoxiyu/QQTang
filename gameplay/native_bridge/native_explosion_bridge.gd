class_name NativeExplosionBridge
extends RefCounted

const LogSimulationScript = preload("res://app/logging/log_simulation.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")
const NativeWireContractScript = preload("res://gameplay/native_bridge/native_wire_contract.gd")

const LOG_TAG := "simulation.native.explosion"
const EXPLOSION_PAYLOAD_MAGIC := 1163153745 # "QQTE" little-endian i32 marker.
const BUBBLE_RECORD_STRIDE := 12
const PLAYER_RECORD_STRIDE := 6
const ITEM_RECORD_STRIDE := 5
const GRID_RECORD_STRIDE := 4


func resolve(ctx: SimContext, pending_bubble_ids: Array[int] = []) -> Dictionary:
	var empty_result := {
		"covered_cells": [],
		"hit_entries": [],
		"destroy_cells": [],
		"chain_bubble_ids": [],
		"processed_bubble_ids": [],
	}
	if ctx == null or ctx.state == null or ctx.scratch == null or ctx.queries == null:
		return empty_result

	var kernel := NativeKernelRuntimeScript.get_explosion_kernel()
	if kernel == null:
		push_error("[native_explosion_bridge] native explosion kernel is unavailable")
		return empty_result

	var input_blob := _encode_input_blob(
		ctx.tick,
		PackedInt32Array(pending_bubble_ids if not pending_bubble_ids.is_empty() else ctx.scratch.bubbles_to_explode),
		_pack_bubble_records(ctx),
		_pack_player_records(ctx),
		_pack_item_records(ctx),
		_pack_grid_records(ctx)
	)
	var result_blob_variant: Variant = kernel.resolve_explosions(input_blob)
	if not (result_blob_variant is PackedByteArray):
		push_error("[native_explosion_bridge] explosion kernel returned non-byte result")
		return empty_result

	var result_variant: Variant = bytes_to_var(result_blob_variant)
	if not (result_variant is Dictionary):
		push_error("[native_explosion_bridge] explosion kernel decoded non-dictionary result")
		return empty_result

	return _decode_result(result_variant)


func _pack_bubble_records(ctx: SimContext) -> PackedInt32Array:
	var records := PackedInt32Array()
	for bubble in _get_sorted_bubbles(ctx):
		if bubble == null:
			continue
		records.append(bubble.entity_id)
		records.append(int(bubble.alive))
		records.append(bubble.owner_player_id)
		records.append(bubble.cell_x)
		records.append(bubble.cell_y)
		records.append(bubble.explode_tick)
		records.append(bubble.bubble_range)
		records.append(int(bubble.pierce))
		records.append(int(bubble.chain_triggered))
		records.append(bubble.bubble_type)
		records.append(bubble.power)
		records.append(bubble.footprint_cells)
	return records


func _pack_player_records(ctx: SimContext) -> PackedInt32Array:
	var records := PackedInt32Array()
	for player in _get_sorted_players(ctx):
		if player == null:
			continue
		records.append(player.entity_id)
		records.append(int(player.alive))
		records.append(player.life_state)
		records.append(player.player_slot)
		records.append(player.cell_x)
		records.append(player.cell_y)
	return records


func _pack_item_records(ctx: SimContext) -> PackedInt32Array:
	var records := PackedInt32Array()
	for item in _get_sorted_items(ctx):
		if item == null:
			continue
		records.append(item.entity_id)
		records.append(int(item.alive))
		records.append(item.item_type)
		records.append(item.cell_x)
		records.append(item.cell_y)
	return records


func _pack_grid_records(ctx: SimContext) -> PackedInt32Array:
	var records := PackedInt32Array()
	for y in range(ctx.state.grid.height):
		for x in range(ctx.state.grid.width):
			var static_cell = ctx.state.grid.get_static_cell(x, y)
			records.append(x)
			records.append(y)
			records.append(static_cell.tile_type)
			records.append(static_cell.tile_flags)
	return records


func _decode_result(raw_result: Dictionary) -> Dictionary:
	var version := int(raw_result.get("version", 0))
	if version != NativeWireContractScript.EXPLOSION_WIRE_VERSION:
		LogSimulationScript.warn(
			"[native_explosion_bridge] explosion result version mismatch: expected=%d actual=%d"
				% [NativeWireContractScript.EXPLOSION_WIRE_VERSION, version],
			"",
			0,
			LOG_TAG
		)
		return {
			"covered_cells": [],
			"hit_entries": [],
			"destroy_cells": [],
			"chain_bubble_ids": [],
			"processed_bubble_ids": [],
		}
	return {
		"covered_cells": _coerce_dict_array(raw_result.get("covered_cells", [])),
		"hit_entries": _coerce_dict_array(raw_result.get("hit_entries", [])),
		"destroy_cells": _coerce_dict_array(raw_result.get("destroy_cells", [])),
		"chain_bubble_ids": _coerce_int_array(raw_result.get("chain_bubble_ids", [])),
		"processed_bubble_ids": _coerce_int_array(raw_result.get("processed_bubble_ids", [])),
	}


func _encode_input_blob(
	tick: int,
	pending_bubble_ids: PackedInt32Array,
	bubble_records: PackedInt32Array,
	player_records: PackedInt32Array,
	item_records: PackedInt32Array,
	grid_records: PackedInt32Array
) -> PackedByteArray:
	var blob := PackedByteArray()
	var total_i32_count := 3
	total_i32_count += 1 + pending_bubble_ids.size()
	total_i32_count += 1 + bubble_records.size()
	total_i32_count += 1 + player_records.size()
	total_i32_count += 1 + item_records.size()
	total_i32_count += 1 + grid_records.size()
	blob.resize(total_i32_count * 4)
	var offset := 0
	offset = _write_i32(blob, offset, EXPLOSION_PAYLOAD_MAGIC)
	offset = _write_i32(blob, offset, NativeWireContractScript.EXPLOSION_WIRE_VERSION)
	offset = _write_i32(blob, offset, tick)
	offset = _write_i32_array(blob, offset, pending_bubble_ids)
	offset = _write_i32_array(blob, offset, bubble_records)
	offset = _write_i32_array(blob, offset, player_records)
	offset = _write_i32_array(blob, offset, item_records)
	_write_i32_array(blob, offset, grid_records)
	return blob


func _write_i32(blob: PackedByteArray, offset: int, value: int) -> int:
	blob.encode_s32(offset, value)
	return offset + 4


func _write_i32_array(blob: PackedByteArray, offset: int, values: PackedInt32Array) -> int:
	offset = _write_i32(blob, offset, values.size())
	for value in values:
		offset = _write_i32(blob, offset, int(value))
	return offset


func _coerce_dict_array(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_value is Array:
		for entry in raw_value:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _coerce_int_array(raw_value: Variant) -> Array[int]:
	var result: Array[int] = []
	if raw_value is Array:
		for entry in raw_value:
			result.append(int(entry))
	return result


func _get_sorted_bubbles(ctx: SimContext) -> Array[BubbleState]:
	var bubbles: Array[BubbleState] = []
	for bubble_id in ctx.state.bubbles.active_ids:
		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
		if bubble != null:
			bubbles.append(bubble)
	bubbles.sort_custom(func(a: BubbleState, b: BubbleState): return a.entity_id < b.entity_id)
	return bubbles


func _get_sorted_players(ctx: SimContext) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for player_id in ctx.state.players.active_ids:
		var player := ctx.state.players.get_player(player_id)
		if player != null:
			players.append(player)
	players.sort_custom(func(a: PlayerState, b: PlayerState): return a.entity_id < b.entity_id)
	return players


func _get_sorted_items(ctx: SimContext) -> Array[ItemState]:
	var items: Array[ItemState] = []
	for item_id in ctx.state.items.active_ids:
		var item := ctx.state.items.get_item(item_id)
		if item != null:
			items.append(item)
	items.sort_custom(func(a: ItemState, b: ItemState): return a.entity_id < b.entity_id)
	return items
