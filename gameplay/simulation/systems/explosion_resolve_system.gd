# 角色：
# 爆炸解析系统，执行十字爆炸传播
#
# 读写边界：
# - 读：泡泡位置、范围、Grid 查询
# - 写：SimScratch（cells_to_destroy, players_to_kill）
#
# 禁止事项：
# - 先计算全部覆盖结果，再统一提交
# - 不得边传播边直接改大量长期状态

class_name ExplosionResolveSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "ExplosionResolveSystem"

func execute(ctx: SimContext) -> void:
	# 遍历待爆炸泡泡
	for bubble_id in ctx.scratch.bubbles_to_explode:
		var bubble = ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null or not bubble.alive:
			continue

		var center_x = bubble.cell_x
		var center_y = bubble.cell_y
		var bubble_range = bubble.bubble_range

		# 记录覆盖格子
		var covered_cells: Array[Vector2i] = []

		# 中心格始终覆盖
		covered_cells.append(Vector2i(center_x, center_y))
		_collect_players_to_kill(ctx, center_x, center_y)

		# 十字方向
		var dirs = [
			Vector2i(0, -1),  # 上
			Vector2i(0, 1),   # 下
			Vector2i(-1, 0),  # 左
			Vector2i(1, 0)    # 右
		]

		# 向各个方向传播
		for dir in dirs:
			for i in range(1, bubble_range + 1):
				var check_x = center_x + dir.x * i
				var check_y = center_y + dir.y * i

				# 检查边界
				if not ctx.queries.is_in_bounds(check_x, check_y):
					break

				# 获取格子类型
				var static_cell = ctx.state.grid.get_static_cell(check_x, check_y)
				# 如果是硬墙，停止传播
				if static_cell.tile_type == TileConstants.TileType.SOLID_WALL:
					break

				# 记录覆盖格子
				covered_cells.append(Vector2i(check_x, check_y))

				# 如果是可破坏砖，记录摧毁（但不停止传播）
				if static_cell.tile_type == TileConstants.TileType.BREAKABLE_BLOCK:
					ctx.scratch.cells_to_destroy.append(Vector2i(check_x, check_y))
					break

				# 检查是否命中玩家
				_collect_players_to_kill(ctx, check_x, check_y)

				# 检查是否命中其他泡泡
				var bubble_at = ctx.queries.get_bubble_at(check_x, check_y)
				if bubble_at != -1 and bubble_at != bubble_id:
					var other_bubble = ctx.queries.get_bubble(bubble_at)
					if other_bubble != null and other_bubble.alive:
						# 第一版不做链爆，后续可改为提前引爆 other_bubble。
						pass

		# 标记泡泡已爆炸
		bubble.alive = false
		ctx.state.bubbles.active_ids.erase(bubble_id)
		ctx.state.indexes.active_bubble_ids.erase(bubble_id)
		if ctx.state.grid.is_in_bounds(center_x, center_y):
			var exploded_idx := ctx.state.grid.to_cell_index(center_x, center_y)
			if exploded_idx >= 0 and exploded_idx < ctx.state.indexes.bubbles_by_cell.size():
				if ctx.state.indexes.bubbles_by_cell[exploded_idx] == bubble_id:
					ctx.state.indexes.bubbles_by_cell[exploded_idx] = -1

		# 记录已爆炸的泡泡（用于后续返还）
		ctx.scratch.exploded_bubble_ids.append(bubble_id)

		# 推送 BubbleExplodedEvent（第一版使用通用事件结构）
		var exploded_event := SimEvent.new(ctx.tick, SimEvent.EventType.BUBBLE_EXPLODED)
		exploded_event.payload = {
			"bubble_id": bubble_id,
			"owner_player_id": bubble.owner_player_id,
			"cell_x": center_x,
			"cell_y": center_y,
			"covered_cells": covered_cells
		}
		ctx.events.push(exploded_event)

func _collect_players_to_kill(ctx: SimContext, cell_x: int, cell_y: int) -> void:
	var players_at = ctx.queries.get_players_at(cell_x, cell_y)
	for pid in players_at:
		var player = ctx.queries.get_player(pid)
		if player != null and player.alive and not ctx.scratch.players_to_kill.has(pid):
			ctx.scratch.players_to_kill.append(pid)
