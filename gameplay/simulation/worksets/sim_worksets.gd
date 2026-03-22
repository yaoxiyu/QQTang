# 角色：
# Tick 结构化结果集，保存当前 Tick 的结构化输出
#
# 读写边界：
# - 由系统写入结构化结果
# - 在 PostTickSystem 中被使用
#
# 禁止事项：
# - 不得保存跨 Tick 的状态

class_name SimWorksets
extends RefCounted

# ====================
# 移动结果
# ====================

var movement_results: Array[MovementResult] = []

# ====================
# 爆炸结果
# ====================

var explosion_results: Array[ExplosionResult] = []

# ====================
# 状态标志
# ====================

# 占用格子索引是否Dirty
var occupied_cells_dirty: bool = false

# ====================
# 方法
# ====================

# 清空所有结果
func clear() -> void:
	movement_results.clear()
	explosion_results.clear()
	occupied_cells_dirty = false
