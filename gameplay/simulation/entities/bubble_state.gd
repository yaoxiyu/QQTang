# 角色：
# 泡泡状态，包含泡泡的所有属性
#
# 读写边界：
# - 只在 BubblePlacementSystem/ ExplosionResolveSystem 中被写入
# - 可在任何查询系统中被读取
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name BubbleState
extends RefCounted

# ====================
# 实体标识
# ====================
var entity_id: int = 0
var generation: int = 0

# ====================
# 基本属性
# ====================
var alive: bool = true

var owner_player_id: int = -1
var bubble_type: int = 0  # 默认类型

# ====================
# 位置
# ====================
var cell_x: int = 0
var cell_y: int = 0

# ====================
# 生命周期
# ====================
var spawn_tick: int = 0
var explode_tick: int = 0
var bubble_range: int = 1

# ====================
# 移动状态
# ====================
enum MovingState {
	STATIC,    # 静止
	KICKED,    # 被踢
	SLIDING   # 滑动（冰面）
}

var moving_state: int = MovingState.STATIC

var move_dir_x: int = 0
var move_dir_y: int = 0

# ====================
# 特殊属性
# ====================
var pierce: bool = false
var chain_triggered: bool = false

# 遥控爆炸组ID（用于远程引爆）
var remote_group_id: int = 0

# 当前允许与该泡泡重叠并穿出的玩家ID列表
var ignore_player_ids: Array[int] = []
