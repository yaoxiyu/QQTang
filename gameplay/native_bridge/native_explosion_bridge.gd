class_name NativeExplosionBridge
extends RefCounted

const LogSimulationScript = preload("res://app/logging/log_simulation.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

const LOG_TAG := "simulation.native.explosion"
const WIRE_VERSION := 1


func resolve(ctx: SimContext) -> Dictionary:
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
		return empty_result

	var payload := {
		"version": WIRE_VERSION,
		"tick": ctx.tick,
		"pending_bubble_ids": PackedInt32Array(ctx.scratch.bubbles_to_explode),
		"bubble_records": _pack_bubble_records(ctx),
		"player_records": _pack_player_records(ctx),
		"item_records": _pack_item_records(ctx),
		"grid_records": _pack_grid_records(ctx),
	}
	var input_blob := var_to_bytes(payload)
	var result_blob_variant: Variant = kernel.resolve_explosions(input_blob)
	if not (result_blob_variant is PackedByteArray):
		LogSimulationScript.warn(
			"[native_explosion_bridge] explosion kernel returned non-byte result, fallback to GDScript",
			"",
			0,
			LOG_TAG
		)
		return empty_result

	var result_variant: Variant = bytes_to_var(result_blob_variant)
	if not (result_variant is Dictionary):
		LogSimulationScript.warn(
			"[native_explosion_bridge] explosion kernel decoded non-dictionary result, fallback to GDScript",
			"",
			0,
			LOG_TAG
		)
		return empty_result

	return _decode_result(result_variant)


func _pack_bubble_records(ctx: SimContext) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for bubble_id in ctx.state.bubbles.active_ids:
		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			continue
		records.append({
			"entity_id": bubble.entity_id,
			"alive": bubble.alive,
			"owner_player_id": bubble.owner_player_id,
			"cell_x": bubble.cell_x,
			"cell_y": bubble.cell_y,
			"explode_tick": bubble.explode_tick,
			"bubble_range": bubble.bubble_range,
			"pierce": bubble.pierce,
			"chain_triggered": bubble.chain_triggered,
		})
	return records


func _pack_player_records(ctx: SimContext) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for player_id in ctx.state.players.active_ids:
		var player := ctx.state.players.get_player(player_id)
		if player == null:
			continue
		records.append({
			"entity_id": player.entity_id,
			"alive": player.alive,
			"life_state": player.life_state,
			"player_slot": player.player_slot,
			"cell_x": player.cell_x,
			"cell_y": player.cell_y,
			"offset_x": player.offset_x,
			"offset_y": player.offset_y,
		})
	return records


func _pack_item_records(ctx: SimContext) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for item_id in ctx.state.items.active_ids:
		var item := ctx.state.items.get_item(item_id)
		if item == null:
			continue
		records.append({
			"entity_id": item.entity_id,
			"alive": item.alive,
			"item_type": item.item_type,
			"cell_x": item.cell_x,
			"cell_y": item.cell_y,
		})
	return records


func _pack_grid_records(ctx: SimContext) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for y in range(ctx.state.grid.height):
		for x in range(ctx.state.grid.width):
			var static_cell = ctx.state.grid.get_static_cell(x, y)
			records.append({
				"cell_x": x,
				"cell_y": y,
				"tile_type": static_cell.tile_type,
				"tile_flags": static_cell.tile_flags,
			})
	return records


func _decode_result(raw_result: Dictionary) -> Dictionary:
	return {
		"covered_cells": _coerce_dict_array(raw_result.get("covered_cells", [])),
		"hit_entries": _coerce_dict_array(raw_result.get("hit_entries", [])),
		"destroy_cells": _coerce_dict_array(raw_result.get("destroy_cells", [])),
		"chain_bubble_ids": _coerce_int_array(raw_result.get("chain_bubble_ids", [])),
		"processed_bubble_ids": _coerce_int_array(raw_result.get("processed_bubble_ids", [])),
	}


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
