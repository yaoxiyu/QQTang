# 角色：
# 道具拾取系统，处理玩家拾取道具
#
# 读写边界：
# - 读：玩家位置、道具位置
# - 写：ItemState、PlayerState 属性
#
# 禁止事项：
# - 不在这里生成道具（由 SpawnSystem 处理）

class_name ItemPickupSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "ItemPickupSystem"

func execute(ctx: SimContext) -> void:
	# 遍历所有活跃玩家
	for player_id in ctx.state.players.active_ids:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue

		var player_cell_x = player.cell_x
		var player_cell_y = player.cell_y

		# 获取当前格子上的道具
		var item_id = ctx.queries.get_item_at(player_cell_x, player_cell_y)
		if item_id == -1:
			continue

		var item = ctx.state.items.get_item(item_id)
		if item == null or not item.alive:
			ctx.state.items.active_ids.erase(item_id)
			continue

		# 检查拾取延迟
		if ctx.tick < item.spawn_tick + item.pickup_delay_ticks:
			continue

		# 拾取道具
		item.alive = false
		ctx.state.items.active_ids.erase(item_id)

		# 应用道具效果（根据道具类型）
		match item.item_type:
			# 炸弹范围 +1
			1:
				player.bomb_range = min(player.bomb_range + 1, 5)
			# 炸弹容量 +1
			2:
				player.bomb_capacity = min(player.bomb_capacity + 1, 5)
			# 速度提升
			3:
				player.speed_level = min(player.speed_level + 1, 3)
			# 移除道具
			_:
				pass

		# 更新玩家状态
		ctx.state.players.update_player(player)

		# TODO: 推送 ItemPickedEvent
