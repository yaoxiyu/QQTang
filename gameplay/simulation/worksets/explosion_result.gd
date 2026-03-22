# 角色：
# 爆炸结果
#
# 读写边界：
# - 只在 SimWorksets 中使用
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name ExplosionResult
extends RefCounted

var source_bubble_id: int = 0
var owner_player_id: int = 0
var covered_cells: Array[Vector2i] = []
var hit_player_ids: Array[int] = []
var hit_bubble_ids: Array[int] = []
var destroyed_cells: Array[Vector2i] = []
