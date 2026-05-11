# 角色：
# 玩家状态，包含玩家的所有游戏内属性
#
# 读写边界：
# - 只在 MovementSystem/ BubblePlacementSystem/ StatusEffectSystem 中被写入
# - 可在任何查询系统中被读取
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name PlayerState
extends RefCounted

# ====================
# 身份字段
# ====================
var entity_id: int = 0
var generation: int = 0

var player_slot: int = 0
var team_id: int = 0

# 控制器类型
enum ControllerType {
	LOCAL,
	NETWORK,
	AI,
	REPLAY
}

var controller_type: int = ControllerType.LOCAL

# ====================
# 生命状态
# ====================
var alive: bool = true

enum LifeState {
	NORMAL,      # 正常
	TRAPPED,     # 被困在泡泡中
	DEAD,        # 已死亡
	REVIVING    # 复活中
}

var life_state: int = LifeState.NORMAL

# ====================
# 位置字段
# ====================
var cell_x: int = 0
var cell_y: int = 0

# 偏移量（用于平滑移动，定点整数）
var offset_x: int = 0
var offset_y: int = 0

# ====================
# 面向方向
# ====================
enum FacingDir {
	UP,
	DOWN,
	LEFT,
	RIGHT
}

var facing: int = FacingDir.DOWN

# ====================
# 移动状态
# ====================
enum MoveState {
	IDLE,
	MOVING,
	BLOCKED,
	SLIDING,
	TURN_ONLY
}

var move_state: int = MoveState.IDLE

# 记录最后一次非零移动方向（用于转向吸附）
var last_non_zero_move_x: int = 0
var last_non_zero_move_y: int = 0

# ====================
# 战斗属性
# ====================
var speed_level: int = 1
var max_speed_level: int = 9
var bomb_capacity: int = 1
var max_bomb_capacity: int = 5
var bomb_available: int = 1
var bomb_range: int = 1
var max_bomb_range: int = 5
var bomb_fuse_ticks: int = 180  # 默认引信时间（tick）

# ====================
# 技能修饰符
# ====================
var has_kick: bool = false
var has_push: bool = false
var has_remote: bool = false
var has_pierce: bool = false
var can_cross_own_bubble: bool = false

# ====================
# 状态计时器
# ====================
var shield_ticks: int = 0
var invincible_ticks: int = 0
var stun_ticks: int = 0
var respawn_ticks: int = 0
var death_display_ticks: int = 0
var trapped_timeout_ticks: int = 0

# ====================
# 战斗相关
# ====================
var trap_bubble_id: int = -1
var last_damage_from_player_id: int = -1

# ====================
# 统计数据
# ====================
var kills: int = 0
var deaths: int = 0
var score: int = 0

# ====================
# 输入缓存
# ====================
var pending_command: PlayerCommand = PlayerCommand.new()
var last_applied_command: PlayerCommand = PlayerCommand.new()
var last_place_bubble_pressed: bool = false
var move_remainder_units: int = 0
