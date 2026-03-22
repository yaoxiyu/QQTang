# 角色：
# 动态格子，描述运行时对象（玩家、泡泡、道具、爆炸）
#
# 读写边界：
# - 每个 Tick 清空并重新设置
# - 玩家占格走 SimIndexes.players_by_cell
#
# 禁止事项：
# - 不得在此写规则逻辑

class_name CellDynamic
extends RefCounted

# 占用此格子的泡泡 ID
var bubble_id: int = -1

# 占用此格子的道具 ID
var item_id: int = -1

# 爆炸覆盖标志
var explosion_flags: int = 0

# 预留标志位
var reserved_flags: int = 0
