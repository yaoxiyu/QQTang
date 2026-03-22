# 角色：
# 移动结果
#
# 读写边界：
# - 只在 SimWorksets 中使用
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name MovementResult
extends RefCounted

var player_id: int = 0
var moved: bool = false
var blocked: bool = false
var from_cell_x: int = 0
var from_cell_y: int = 0
var to_cell_x: int = 0
var to_cell_y: int = 0
