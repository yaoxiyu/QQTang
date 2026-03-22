# 角色：
# 引信系统，选出当前 Tick 应爆炸的泡泡
#
# 读写边界：
# - 读：BubbleState.explode_tick
# - 写：SimScratch.bubbles_to_explode
#
# 禁止事项：
# - 不在这里传播爆炸
# - 不在这里伤害玩家
# - 不在这里直接删除泡泡

class_name BombFuseSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "BombFuseSystem"

func execute(ctx: SimContext) -> void:
	# 遍历所有活跃泡泡
	for bubble_id in ctx.state.bubbles.active_ids:
		var bubble = ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null or not bubble.alive:
			continue

		# 检查是否应爆炸
		if bubble.explode_tick <= ctx.tick:
			ctx.scratch.bubbles_to_explode.append(bubble_id)
