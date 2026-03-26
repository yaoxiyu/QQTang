# 角色：
# 状态效果系统，处理死亡/复活等状态变化
#
# 读写边界：
# - 读：players_to_kill, exploded_bubbles, immunity
# - 写：PlayerState.alive,生命状态,统计数据,bomb_available
#
# 禁止事项：
# - 不在这里做规则判断

class_name StatusEffectSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "StatusEffectSystem"

func execute(ctx: SimContext) -> void:
	_process_destroyed_cells(ctx)

	# 处理死亡
	for player_id in ctx.scratch.players_to_kill:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		# 检查无敌
		if player.invincible_ticks > 0:
			continue

		# 标记死亡
		player.alive = false
		player.life_state = PlayerState.LifeState.DEAD
		player.deaths += 1

		# 更新活跃列表
		ctx.state.players.mark_player_dead(player_id)
		ctx.state.indexes.living_player_ids.erase(player_id)
		if ctx.state.grid.is_in_bounds(player.cell_x, player.cell_y):
			var cell_idx := ctx.state.grid.to_cell_index(player.cell_x, player.cell_y)
			if cell_idx >= 0 and cell_idx < ctx.state.indexes.players_by_cell.size():
				var players_in_cell: Array = ctx.state.indexes.players_by_cell[cell_idx]
				var pos := players_in_cell.find(player_id)
				if pos != -1:
					players_in_cell.remove_at(pos)

		ctx.state.players.update_player(player)

		# 推送 PlayerKilledEvent（第一版使用通用事件结构）
		var killed_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_KILLED)
		killed_event.payload = {
			"victim_player_id": player_id,
			"killer_player_id": player.last_damage_from_player_id,
			"cell_x": player.cell_x,
			"cell_y": player.cell_y
		}
		ctx.events.push(killed_event)

	# 处理爆炸泡泡返还（在死亡处理之后）
	for bubble_id in ctx.scratch.exploded_bubble_ids:
		var bubble = ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			continue

		var owner_id = bubble.owner_player_id
		var player = ctx.state.players.get_player(owner_id)
		if player == null or not player.alive:
			continue

		# 返还泡泡容量（直到达到最大容量）
		if player.bomb_available < player.bomb_capacity:
			player.bomb_available += 1
			ctx.state.players.update_player(player)


func _process_destroyed_cells(ctx: SimContext) -> void:
	for cell in ctx.scratch.cells_to_destroy:
		if not ctx.state.grid.is_in_bounds(cell.x, cell.y):
			continue

		var static_cell := ctx.state.grid.get_static_cell(cell.x, cell.y)
		if static_cell.tile_type != TileConstants.TileType.BREAKABLE_BLOCK:
			continue

		ctx.state.grid.set_static_cell(cell.x, cell.y, TileFactory.make_empty())

		var destroyed_event := SimEvent.new(ctx.tick, SimEvent.EventType.CELL_DESTROYED)
		destroyed_event.payload = {
			"cell_x": cell.x,
			"cell_y": cell.y
		}
		ctx.events.push(destroyed_event)
