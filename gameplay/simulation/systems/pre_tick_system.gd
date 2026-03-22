# 角色：
# 预 Tick 系统，清空上一 Tick 的临时数据
#
# 读写边界：
# - 写：SimScratch, SimWorksets, SimEventBuffer
#
# 禁止事项：
# - 不能在这里做规则推进
# - 不能修改玩家位置

class_name PreTickSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "PreTickSystem"

func execute(ctx: SimContext) -> void:
	# 清空 scratch
	ctx.scratch.clear()

	# 清空 worksets
	ctx.worksets.clear()

	# 开始新 Tick 的事件
	ctx.events.begin_tick(ctx.tick)
