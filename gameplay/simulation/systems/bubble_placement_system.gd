# 角色：
# 泡泡放置系统，处理玩家放泡命令
#
# 读写边界：
# - 读：玩家命令、bomb_available、脚下格
# - 写：BubbleState、GridState、indexes
#
# 禁止事项：
# - 不在这里处理引信和爆炸

class_name BubblePlacementSystem
extends ISimSystem

const BubblePlaceResolver = preload("res://gameplay/simulation/movement/bubble_place_resolver.gd")
const BubblePassPhaseScript = preload("res://gameplay/simulation/entities/bubble_pass_phase.gd")
const BubblePassPhaseHelper = preload("res://gameplay/simulation/movement/bubble_pass_phase_helper.gd")

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "BubblePlacementSystem"

func execute(ctx: SimContext) -> void:
	# 遍历所有活跃玩家
	for player_id in ctx.state.players.active_ids:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		var cmd = player.last_applied_command

		# 只处理边沿触发的 place_bubble
		var place_pressed := bool(cmd.place_bubble)
		if not place_pressed:
			player.last_place_bubble_pressed = false
			ctx.state.players.update_player(player)
			continue
		if player.last_place_bubble_pressed:
			continue
		player.last_place_bubble_pressed = true

		# 检查泡泡容量
		if player.bomb_available <= 0:
			ctx.state.players.update_player(player)
			continue

		# 检查脚下格
		var place_cell := BubblePlaceResolver.resolve_place_cell(player)
		var cell_x := place_cell.x
		var cell_y := place_cell.y
		var bubble_loadout := _resolve_bubble_loadout(ctx, player)
		var bubble_type := int(bubble_loadout.get("type", bubble_loadout.get("bubble_type", 0)))
		var bubble_power := maxi(1, int(bubble_loadout.get("power", player.bomb_range)))
		var footprint_cells := maxi(1, int(bubble_loadout.get("footprint_cells", 1)))
		var footprint := _build_footprint(cell_x, cell_y, footprint_cells)

		if not _can_place_footprint(ctx, footprint):
			ctx.state.players.update_player(player)
			continue

		# 放置泡泡
		var explode_tick = ctx.tick + player.bomb_fuse_ticks
		var bubble_id = ctx.state.bubbles.spawn_bubble(
			player_id,
			cell_x,
			cell_y,
			bubble_power,
			explode_tick,
			bubble_type,
			bubble_power,
			footprint_cells
		)

		# 更新玩家状态
		player.bomb_available -= 1
		ctx.state.players.update_player(player)

		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
		if bubble != null:
			# 与新泡泡发生 overlap 的所有玩家进入 (A,A)：在两轴都自由穿越，
			# 直到玩家把自己移出泡泡 ≥M/2 才会单调降级到 B 阶段（单向墙）。
			for overlap_player_id in ctx.state.players.active_ids:
				if not ctx.queries.is_player_overlapping_bubble(overlap_player_id, bubble_id):
					continue
				if BubblePassPhaseHelper.has_phase(bubble, overlap_player_id):
					continue
				var phase := BubblePassPhaseScript.new()
				phase.player_id = overlap_player_id
				phase.phase_x = BubblePassPhaseScript.Phase.A
				phase.phase_y = BubblePassPhaseScript.Phase.A
				phase.sign_x = 0
				phase.sign_y = 0
				BubblePassPhaseHelper.upsert_phase(bubble, phase)
			ctx.state.bubbles.update_bubble(bubble)

		# 增量更新泡泡索引，保证同 Tick 内可被查询到
		for footprint_cell in footprint:
			var cell_idx := ctx.state.grid.to_cell_index(footprint_cell.x, footprint_cell.y)
			if cell_idx >= 0 and cell_idx < ctx.state.indexes.bubbles_by_cell.size():
				ctx.state.indexes.bubbles_by_cell[cell_idx] = bubble_id
		if not ctx.state.indexes.active_bubble_ids.has(bubble_id):
			ctx.state.indexes.active_bubble_ids.append(bubble_id)

		# 推送 BubblePlacedEvent（第一版使用通用事件结构）
		var placed_event := SimEvent.new(ctx.tick, SimEvent.EventType.BUBBLE_PLACED)
		placed_event.payload = {
			"bubble_id": bubble_id,
			"owner_player_id": player_id,
			"cell_x": cell_x,
			"cell_y": cell_y,
			"explode_tick": explode_tick,
			"bubble_type": bubble_type,
			"power": bubble_power,
			"footprint_cells": footprint_cells
		}
		ctx.events.push(placed_event)


func _can_place_footprint(ctx: SimContext, footprint: Array[Vector2i]) -> bool:
	for cell in footprint:
		if ctx.queries.is_hard_blocked(cell.x, cell.y):
			return false
		if ctx.queries.get_bubble_at(cell.x, cell.y) != -1:
			return false
	return true


func _build_footprint(cell_x: int, cell_y: int, footprint_cells: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var size := maxi(1, int(ceil(sqrt(float(maxi(1, footprint_cells))))))
	for y in range(size):
		for x in range(size):
			if cells.size() >= maxi(1, footprint_cells):
				return cells
			cells.append(Vector2i(cell_x + x, cell_y + y))
	return cells


func _resolve_bubble_loadout(ctx: SimContext, player: PlayerState) -> Dictionary:
	var player_slots := _coerce_dict_array(ctx.config.system_flags.get("player_slots", []))
	var bubble_loadouts := _coerce_dict_array(ctx.config.system_flags.get("player_bubble_loadouts", []))
	var peer_id := -1
	for player_slot in player_slots:
		if int(player_slot.get("slot_index", -1)) == player.player_slot:
			peer_id = int(player_slot.get("peer_id", -1))
			break
	if peer_id >= 0:
		for loadout in bubble_loadouts:
			if int(loadout.get("peer_id", -2)) == peer_id:
				return loadout
	for loadout in bubble_loadouts:
		if int(loadout.get("slot_index", -2)) == player.player_slot:
			return loadout
	return {}


func _coerce_dict_array(raw_value: Variant) -> Array[Dictionary]:
	var coerced: Array[Dictionary] = []
	if raw_value is Array:
		for entry in raw_value:
			if entry is Dictionary:
				coerced.append(entry)
	return coerced
