# 角色：
# Tick 临时工作集，保存当前 Tick 的中间结果
#
# 读写边界：
# - 由系统写入中间结果
# - 在 PostTickSystem 中被清理
#
# 禁止事项：
# - 不得保存跨 Tick 的状态

class_name SimScratch
extends RefCounted

# ====================
# 爆炸相关
# ====================

# 待爆炸的泡泡列表
var bubbles_to_explode: Array[int] = []

# 已爆炸的泡泡ID（用于返还）
var exploded_bubble_ids: Array[int] = []

# 待摧毁的格子列表
var cells_to_destroy: Array[Vector2i] = []

# ====================
# 玩家相关
# ====================

# 待杀死的玩家列表
var players_to_kill: Array[int] = []

# ====================
# 道具相关
# ====================

# 待掉落的道具条目
var items_to_spawn: Array[PendingItemSpawn] = []

# ====================
# 方法
# ====================

# 清空所有临时数据
func clear() -> void:
	bubbles_to_explode.clear()
	exploded_bubble_ids.clear()
	cells_to_destroy.clear()
	players_to_kill.clear()
	items_to_spawn.clear()
