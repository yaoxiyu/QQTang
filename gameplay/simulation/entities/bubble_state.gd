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
var power: int = 1
var footprint_cells: int = 1

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

# 双轴穿越阶段：每个玩家相对该泡泡的 (phase_x, phase_y) 状态机。
# 元素类型为 BubblePassPhase（res://gameplay/simulation/entities/bubble_pass_phase.gd）。
# 字段使用弱类型 Array 以避免全局 class_name 解析时序耦合；
# 所有写入必须经由 BubblePassPhaseHelper 以保证 player_id 升序。
var pass_phases: Array = []


func footprint_size() -> int:
	return maxi(1, int(ceil(sqrt(float(maxi(1, footprint_cells))))))


func get_footprint_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var size := footprint_size()
	for y in range(size):
		for x in range(size):
			if cells.size() >= maxi(1, footprint_cells):
				return cells
			cells.append(Vector2i(cell_x + x, cell_y + y))
	return cells
