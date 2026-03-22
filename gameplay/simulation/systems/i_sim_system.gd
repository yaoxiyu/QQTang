# 角色：
# 仿真系统基类，所有系统类继承自此
#
# 读写边界：
# - 基类，不直接使用
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name ISimSystem
extends RefCounted

# ====================
# 接口方法
# ====================

# 获取系统名称
func get_name() -> StringName:
	return "ISimSystem"

# 执行系统逻辑
func execute(ctx: SimContext) -> void:
	pass
