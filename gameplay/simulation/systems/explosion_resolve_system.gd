# 角色：
# 爆炸解析系统，执行十字爆炸传播
#
# 读写边界：
# - 读：泡泡位置、范围、Grid 查询
# - 写：SimScratch（cells_to_destroy, explosion_hit_entries）
#
# 禁止事项：
# - 先计算全部覆盖结果，再统一提交
# - 不得边传播边直接改大量长期状态

class_name ExplosionResolveSystem
extends ISimSystem

const ExplosionHitTypes = preload("res://gameplay/simulation/explosion/explosion_hit_types.gd")
const ExplosionHitEntry = preload("res://gameplay/simulation/explosion/explosion_hit_entry.gd")
const ExplosionReactionResolver = preload("res://gameplay/simulation/explosion/explosion_reaction_resolver.gd")
const LogSimulationScript = preload("res://app/logging/log_simulation.gd")
const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")
const NativeExplosionBridgeScript = preload("res://gameplay/native_bridge/native_explosion_bridge.gd")
const TRACE_TAG := "sync.trace"

const PROPAGATION_DIRS := [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0)
]

var _native_explosion_bridge: NativeExplosionBridge = NativeExplosionBridgeScript.new()

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "ExplosionResolveSystem"

func execute(ctx: SimContext) -> void:
	if NativeFeatureFlagsScript.enable_native_explosion:
		if not NativeKernelRuntimeScript.is_available() or not NativeKernelRuntimeScript.has_explosion_kernel():
			if NativeFeatureFlagsScript.require_native_kernels:
				push_error("[explosion_resolve_system] native explosion kernel is required but unavailable")
				return
		else:
			_execute_native_path(ctx)
			return

	var pending_bubble_queue: Array[int] = []
	for bubble_id in ctx.scratch.bubbles_to_explode:
		if ctx.scratch.queued_chain_bubble_ids.has(bubble_id):
			continue
		ctx.scratch.queued_chain_bubble_ids[bubble_id] = true
		pending_bubble_queue.append(bubble_id)

	while not pending_bubble_queue.is_empty():
		var bubble_id: int = pending_bubble_queue.pop_front()
		if ctx.scratch.processed_explosion_bubble_ids.has(bubble_id):
			continue

		var bubble: BubbleState = ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null or not bubble.alive:
			continue
		ctx.scratch.processed_explosion_bubble_ids[bubble_id] = true

		var center_x: int = bubble.cell_x
		var center_y: int = bubble.cell_y

		var covered_cells: Array[Vector2i] = []
		if _is_square_explosion(bubble):
			_resolve_square_explosion(ctx, bubble, pending_bubble_queue, covered_cells)
		else:
			_resolve_cross_explosion(ctx, bubble, pending_bubble_queue, covered_cells)

		bubble.alive = false
		ctx.state.bubbles.active_ids.erase(bubble_id)
		ctx.state.indexes.active_bubble_ids.erase(bubble_id)
		_clear_bubble_indexes(ctx, bubble)

		ctx.scratch.exploded_bubble_ids.append(bubble_id)

		var exploded_event := SimEvent.new(ctx.tick, SimEvent.EventType.BUBBLE_EXPLODED)
		exploded_event.payload = {
			"bubble_id": bubble_id,
			"owner_player_id": bubble.owner_player_id,
			"cell_x": center_x,
			"cell_y": center_y,
			"covered_cells": covered_cells
		}
		_log_invalid_explosion_coverage_if_needed(ctx, bubble_id, center_x, center_y, covered_cells)
		ctx.events.push(exploded_event)


func _is_square_explosion(bubble: BubbleState) -> bool:
	return bubble.bubble_type == 2


func _resolve_cross_explosion(
	ctx: SimContext,
	bubble: BubbleState,
	pending_bubble_queue: Array[int],
	covered_cells: Array[Vector2i]
) -> void:
	var center_x: int = bubble.cell_x
	var center_y: int = bubble.cell_y
	var bubble_range: int = maxi(1, bubble.power)

	_append_covered_cell(covered_cells, Vector2i(center_x, center_y))
	_collect_hits_at_cell(ctx, bubble, center_x, center_y, pending_bubble_queue)

	for dir in PROPAGATION_DIRS:
		for i in range(1, bubble_range + 1):
			var check_x: int = center_x + dir.x * i
			var check_y: int = center_y + dir.y * i
			var should_stop := _resolve_explosion_cell(ctx, bubble, check_x, check_y, pending_bubble_queue, covered_cells)
			if should_stop:
				break


func _resolve_square_explosion(
	ctx: SimContext,
	bubble: BubbleState,
	pending_bubble_queue: Array[int],
	covered_cells: Array[Vector2i]
) -> void:
	var size := 3 if bubble.power <= 1 else 6
	var footprint_size := bubble.footprint_size()
	var margin := int((size - footprint_size) / 2)
	var start_x := bubble.cell_x - margin
	var start_y := bubble.cell_y - margin
	for y in range(size):
		for x in range(size):
			_resolve_explosion_cell(
				ctx,
				bubble,
				start_x + x,
				start_y + y,
				pending_bubble_queue,
				covered_cells
			)


func _resolve_explosion_cell(
	ctx: SimContext,
	bubble: BubbleState,
	cell_x: int,
	cell_y: int,
	pending_bubble_queue: Array[int],
	covered_cells: Array[Vector2i]
) -> bool:
	if not ctx.queries.is_in_bounds(cell_x, cell_y):
		return true

	var static_cell = ctx.state.grid.get_static_cell(cell_x, cell_y)
	if static_cell.tile_type == TileConstants.TileType.SOLID_WALL:
		return true

	_append_covered_cell(covered_cells, Vector2i(cell_x, cell_y))
	if static_cell.tile_type == TileConstants.TileType.BREAKABLE_BLOCK:
		var block_reaction: Dictionary = ExplosionReactionResolver.resolve_breakable_block_reaction(
			ctx,
			cell_x,
			cell_y
		)
		if bool(block_reaction.get("should_register_hit", false)):
			_register_block_hit(ctx, bubble, cell_x, cell_y, block_reaction)
		if int(block_reaction.get("reaction", ExplosionHitTypes.BlockReaction.DESTROY_AND_STOP)) == ExplosionHitTypes.BlockReaction.DESTROY_AND_STOP:
			var block_cell := Vector2i(cell_x, cell_y)
			if not ctx.scratch.cells_to_destroy.has(block_cell):
				ctx.scratch.cells_to_destroy.append(block_cell)
		return bool(block_reaction.get("should_stop_propagation", true))

	_collect_hits_at_cell(ctx, bubble, cell_x, cell_y, pending_bubble_queue)
	return false


func _append_covered_cell(covered_cells: Array[Vector2i], cell: Vector2i) -> void:
	if not covered_cells.has(cell):
		covered_cells.append(cell)


func _clear_bubble_indexes(ctx: SimContext, bubble: BubbleState) -> void:
	for footprint_cell in bubble.get_footprint_cells():
		if not ctx.state.grid.is_in_bounds(footprint_cell.x, footprint_cell.y):
			continue
		var exploded_idx := ctx.state.grid.to_cell_index(footprint_cell.x, footprint_cell.y)
		if exploded_idx >= 0 and exploded_idx < ctx.state.indexes.bubbles_by_cell.size():
			if ctx.state.indexes.bubbles_by_cell[exploded_idx] == bubble.entity_id:
				ctx.state.indexes.bubbles_by_cell[exploded_idx] = -1


func _log_invalid_explosion_coverage_if_needed(
	ctx: SimContext,
	bubble_id: int,
	center_x: int,
	center_y: int,
	covered_cells: Array[Vector2i]
) -> void:
	var covered_lookup: Dictionary = {}
	for cell in covered_cells:
		covered_lookup[cell] = true
		var static_cell = ctx.state.grid.get_static_cell(cell.x, cell.y)
		if static_cell.tile_type == TileConstants.TileType.SOLID_WALL:
			LogSimulationScript.warn(
				"anomaly=covered_solid_wall tick=%d bubble_id=%d center=(%d,%d) cell=(%d,%d)" % [
					ctx.tick,
					bubble_id,
					center_x,
					center_y,
					cell.x,
					cell.y,
				],
				"",
				0,
				"%s simulation.explosion_coverage" % TRACE_TAG
			)
	for dir in PROPAGATION_DIRS:
		var reached_gap := false
		for i in range(1, 32):
			var check_x : int = center_x + dir.x * i
			var check_y : int = center_y + dir.y * i
			if not ctx.queries.is_in_bounds(check_x, check_y):
				break
			var check_cell := Vector2i(check_x, check_y)
			var static_cell = ctx.state.grid.get_static_cell(check_x, check_y)
			var is_covered := covered_lookup.has(check_cell)
			if reached_gap and is_covered:
				LogSimulationScript.warn(
					"anomaly=non_contiguous_coverage tick=%d bubble_id=%d center=(%d,%d) resumed_cell=(%d,%d)" % [
						ctx.tick,
						bubble_id,
						center_x,
						center_y,
						check_x,
						check_y,
					],
					"",
					0,
					"%s simulation.explosion_coverage" % TRACE_TAG
				)
				break
			if static_cell.tile_type == TileConstants.TileType.SOLID_WALL:
				if is_covered:
					LogSimulationScript.warn(
						"anomaly=covered_through_solid tick=%d bubble_id=%d center=(%d,%d) wall_cell=(%d,%d)" % [
							ctx.tick,
							bubble_id,
							center_x,
							center_y,
							check_x,
							check_y,
						],
						"",
						0,
						"%s simulation.explosion_coverage" % TRACE_TAG
					)
					break
				break
			if not is_covered:
				reached_gap = true
			if static_cell.tile_type == TileConstants.TileType.BREAKABLE_BLOCK:
				if reached_gap:
					break
				# breakable block can be covered once and should stop afterwards.
				reached_gap = true


func _collect_hits_at_cell(
	ctx: SimContext,
	source_bubble: BubbleState,
	cell_x: int,
	cell_y: int,
	pending_bubble_queue: Array[int]
) -> void:
	_collect_bubble_hits(ctx, source_bubble, cell_x, cell_y, pending_bubble_queue)
	_collect_player_hits(ctx, source_bubble, cell_x, cell_y)
	_collect_item_hits(ctx, source_bubble, cell_x, cell_y)


func _collect_bubble_hits(
	ctx: SimContext,
	source_bubble: BubbleState,
	cell_x: int,
	cell_y: int,
	pending_bubble_queue: Array[int]
) -> void:
	var target_bubble_id: int = ctx.queries.get_bubble_at(cell_x, cell_y)
	if target_bubble_id == -1 or target_bubble_id == source_bubble.entity_id:
		return

	var target_bubble: BubbleState = ctx.queries.get_bubble(target_bubble_id)
	if target_bubble == null or not target_bubble.alive:
		return

	var bubble_reaction: Dictionary = ExplosionReactionResolver.resolve_bubble_reaction(ctx, target_bubble)
	if not bool(bubble_reaction.get("should_register_hit", false)):
		return

	_register_entity_hit(
		ctx,
		source_bubble,
		ExplosionHitTypes.TargetType.BUBBLE,
		target_bubble.entity_id,
		cell_x,
		cell_y
	)

	if not bool(bubble_reaction.get("should_enqueue_chain", false)):
		return
	if ctx.scratch.queued_chain_bubble_ids.has(target_bubble_id):
		return
	if ctx.scratch.processed_explosion_bubble_ids.has(target_bubble_id):
		return

	ctx.scratch.queued_chain_bubble_ids[target_bubble_id] = true
	pending_bubble_queue.append(target_bubble_id)


func _collect_player_hits(ctx: SimContext, source_bubble: BubbleState, cell_x: int, cell_y: int) -> void:
	var players_at: Array = ctx.queries.get_players_at(cell_x, cell_y)
	for pid in players_at:
		var player: PlayerState = ctx.queries.get_player(int(pid))
		if player == null:
			continue
		var player_reaction: Dictionary = ExplosionReactionResolver.resolve_player_reaction(ctx, player)
		if not bool(player_reaction.get("should_register_hit", false)):
			continue
		_register_entity_hit(
			ctx,
			source_bubble,
			ExplosionHitTypes.TargetType.PLAYER,
			player.entity_id,
			cell_x,
			cell_y
		)


func _collect_item_hits(ctx: SimContext, source_bubble: BubbleState, cell_x: int, cell_y: int) -> void:
	var item_id: int = ctx.queries.get_item_at(cell_x, cell_y)
	if item_id == -1:
		return

	var item: ItemState = ctx.queries.get_item(item_id)
	if item == null:
		return

	var item_reaction: Dictionary = ExplosionReactionResolver.resolve_item_reaction(ctx, item)
	if not bool(item_reaction.get("should_register_hit", false)):
		return

	var aux_data: Dictionary = {}
	var transform_item_type: int = int(item_reaction.get("transform_item_type", -1))
	if transform_item_type >= 0:
		aux_data["transform_item_type"] = transform_item_type

	_register_entity_hit(
		ctx,
		source_bubble,
		ExplosionHitTypes.TargetType.ITEM,
		item.entity_id,
		cell_x,
		cell_y,
		aux_data
	)


func _register_block_hit(
	ctx: SimContext,
	source_bubble: BubbleState,
	cell_x: int,
	cell_y: int,
	reaction_result: Dictionary
) -> void:
	_register_entity_hit(
		ctx,
		source_bubble,
		ExplosionHitTypes.TargetType.BREAKABLE_BLOCK,
		-1,
		cell_x,
		cell_y,
		{
			"profile_id": String(reaction_result.get("profile_id", "")),
			"reaction": int(reaction_result.get("reaction", ExplosionHitTypes.BlockReaction.DESTROY_AND_STOP)),
		}
	)


func _register_entity_hit(
	ctx: SimContext,
	source_bubble: BubbleState,
	target_type: int,
	target_entity_id: int,
	target_cell_x: int,
	target_cell_y: int,
	target_aux_data: Dictionary = {}
) -> void:
	var hit_entry := ExplosionHitEntry.new()
	hit_entry.tick = ctx.tick
	hit_entry.source_bubble_id = source_bubble.entity_id
	hit_entry.source_player_id = source_bubble.owner_player_id
	hit_entry.source_cell_x = source_bubble.cell_x
	hit_entry.source_cell_y = source_bubble.cell_y
	hit_entry.target_type = target_type
	hit_entry.target_entity_id = target_entity_id
	hit_entry.target_cell_x = target_cell_x
	hit_entry.target_cell_y = target_cell_y
	hit_entry.target_aux_data = target_aux_data.duplicate(true)

	var dedupe_key: String = hit_entry.build_dedupe_key()
	if ctx.scratch.explosion_hit_keys.has(dedupe_key):
		return

	ctx.scratch.explosion_hit_keys[dedupe_key] = true
	ctx.scratch.explosion_hit_entries.append(hit_entry)


func _execute_native_path(ctx: SimContext) -> bool:
	for bubble_id in ctx.scratch.bubbles_to_explode:
		ctx.scratch.queued_chain_bubble_ids[int(bubble_id)] = true
	var pending_wave: Array[int] = ctx.scratch.bubbles_to_explode.duplicate()
	var saw_processed := false

	while not pending_wave.is_empty():
		var result := _native_explosion_bridge.resolve(ctx, pending_wave)
		var processed_bubble_ids: Array[int] = result.get("processed_bubble_ids", [])
		if processed_bubble_ids.is_empty():
			push_error("[explosion_resolve_system] native explosion returned empty processed_bubble_ids")
			return false

		saw_processed = true
		_apply_native_destroy_cells(ctx, result.get("destroy_cells", []))
		_apply_native_hit_entries(ctx, result.get("hit_entries", []))
		_apply_native_chain_bubble_ids(ctx, result.get("chain_bubble_ids", []))
		_apply_native_processed_bubbles(ctx, processed_bubble_ids, result.get("covered_cells", []))
		pending_wave = _collect_unprocessed_native_chain_bubble_ids(ctx, result.get("chain_bubble_ids", []))

	if not ctx.scratch.bubbles_to_explode.is_empty() and not saw_processed:
		return false
	return true


func _collect_unprocessed_native_chain_bubble_ids(ctx: SimContext, chain_bubble_ids: Array) -> Array[int]:
	var pending: Array[int] = []
	for bubble_id_value in chain_bubble_ids:
		var bubble_id := int(bubble_id_value)
		if ctx.scratch.processed_explosion_bubble_ids.has(bubble_id):
			continue
		pending.append(bubble_id)
	return pending


func _apply_native_destroy_cells(ctx: SimContext, destroy_cells: Array) -> void:
	for raw_cell in destroy_cells:
		if not (raw_cell is Dictionary):
			continue
		var cell := Vector2i(int(raw_cell.get("cell_x", 0)), int(raw_cell.get("cell_y", 0)))
		if not ctx.scratch.cells_to_destroy.has(cell):
			ctx.scratch.cells_to_destroy.append(cell)


func _apply_native_hit_entries(ctx: SimContext, hit_entries: Array) -> void:
	for raw_entry in hit_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry_data: Dictionary = raw_entry
		var hit_entry := ExplosionHitEntry.new()
		hit_entry.tick = int(entry_data.get("tick", ctx.tick))
		hit_entry.source_bubble_id = int(entry_data.get("source_bubble_id", -1))
		hit_entry.source_player_id = int(entry_data.get("source_player_id", -1))
		hit_entry.source_cell_x = int(entry_data.get("source_cell_x", 0))
		hit_entry.source_cell_y = int(entry_data.get("source_cell_y", 0))
		hit_entry.target_type = int(entry_data.get("target_type", ExplosionHitTypes.TargetType.PLAYER))
		hit_entry.target_entity_id = int(entry_data.get("target_entity_id", -1))
		hit_entry.target_cell_x = int(entry_data.get("target_cell_x", 0))
		hit_entry.target_cell_y = int(entry_data.get("target_cell_y", 0))
		hit_entry.target_aux_data = (entry_data.get("target_aux_data", {}) as Dictionary).duplicate(true)
		var dedupe_key := hit_entry.build_dedupe_key()
		if ctx.scratch.explosion_hit_keys.has(dedupe_key):
			continue
		ctx.scratch.explosion_hit_keys[dedupe_key] = true
		ctx.scratch.explosion_hit_entries.append(hit_entry)


func _apply_native_chain_bubble_ids(ctx: SimContext, chain_bubble_ids: Array) -> void:
	for bubble_id in chain_bubble_ids:
		ctx.scratch.queued_chain_bubble_ids[int(bubble_id)] = true


func _apply_native_processed_bubbles(ctx: SimContext, processed_bubble_ids: Array, covered_cells: Array) -> void:
	var covered_lookup := _group_native_covered_cells_by_bubble(covered_cells)
	for bubble_id_value in processed_bubble_ids:
		var bubble_id := int(bubble_id_value)
		if ctx.scratch.processed_explosion_bubble_ids.has(bubble_id):
			continue
		var bubble: BubbleState = ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null or not bubble.alive:
			continue

		ctx.scratch.processed_explosion_bubble_ids[bubble_id] = true
		bubble.alive = false
		ctx.state.bubbles.active_ids.erase(bubble_id)
		ctx.state.indexes.active_bubble_ids.erase(bubble_id)
		_clear_bubble_indexes(ctx, bubble)

		ctx.scratch.exploded_bubble_ids.append(bubble_id)
		var bubble_covered_cells: Array[Vector2i] = [Vector2i(bubble.cell_x, bubble.cell_y)]
		if covered_lookup.has(bubble_id):
			bubble_covered_cells = covered_lookup[bubble_id]
		var exploded_event := SimEvent.new(ctx.tick, SimEvent.EventType.BUBBLE_EXPLODED)
		exploded_event.payload = {
			"bubble_id": bubble_id,
			"owner_player_id": bubble.owner_player_id,
			"cell_x": bubble.cell_x,
			"cell_y": bubble.cell_y,
			"covered_cells": bubble_covered_cells
		}
		_log_invalid_explosion_coverage_if_needed(ctx, bubble_id, bubble.cell_x, bubble.cell_y, bubble_covered_cells)
		ctx.events.push(exploded_event)


func _group_native_covered_cells_by_bubble(covered_cells: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for raw_cell in covered_cells:
		if not (raw_cell is Dictionary):
			continue
		var entry: Dictionary = raw_cell
		var bubble_id := int(entry.get("bubble_id", -1))
		if bubble_id < 0:
			continue
		if not grouped.has(bubble_id):
			grouped[bubble_id] = Array([], TYPE_VECTOR2I, "", null)
		var cells: Array[Vector2i] = grouped[bubble_id]
		cells.append(Vector2i(int(entry.get("cell_x", 0)), int(entry.get("cell_y", 0))))
	return grouped
