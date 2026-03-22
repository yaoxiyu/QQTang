# 角色：
# 待掉落的道具条目
#
# 读写边界：
# - 只在 SimScratch 中使用
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name PendingItemSpawn
extends RefCounted

var cell_x: int = 0
var cell_y: int = 0
var source_reason: int = 0
var source_entity_id: int = 0
