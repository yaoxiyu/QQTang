# 角色：
# POST Tick 系统，完成 Tick 收尾工作
#
# 读写边界：
# - 读：SimState, SimIndexes
#
# 禁止事项：
# - 不能在这里修改规则状态

class_name PostTickSystem
extends ISimSystem

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "PostTickSystem"

func execute(ctx: SimContext) -> void:
	# 更新索引（Phase 1 要求系统层负责）
	ctx.state.indexes.rebuild_from_state(ctx.state)
