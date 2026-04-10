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

# 本 Tick 的爆炸命中记录
var explosion_hit_entries: Array = []

# 爆炸命中去重键
var explosion_hit_keys: Dictionary = {}

# 已入链爆队列的泡泡ID
var queued_chain_bubble_ids: Dictionary = {}

# 已处理爆炸传播的泡泡ID
var processed_explosion_bubble_ids: Dictionary = {}

# ====================
# 玩家相关
# ====================

# 待杀死的玩家列表
var players_to_kill: Array[int] = []

# 待进入果冻状态的玩家列表
var players_to_trap: Array[int] = []

# 待处决的玩家列表
var players_to_execute: Array[int] = []

# 待复活的玩家列表
var players_to_revive: Array[int] = []

# 计分事件列表
var score_events: Array[Dictionary] = []

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
	explosion_hit_entries.clear()
	explosion_hit_keys.clear()
	queued_chain_bubble_ids.clear()
	processed_explosion_bubble_ids.clear()
	players_to_kill.clear()
	players_to_trap.clear()
	players_to_execute.clear()
	players_to_revive.clear()
	score_events.clear()
	items_to_spawn.clear()
