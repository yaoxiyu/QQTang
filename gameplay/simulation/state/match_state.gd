# 角色：
# 对局状态，包含全局对局信息
#
# 读写边界：
# - 只在 WinConditionSystem 中被写入
# - 可在任何地方被读取（查询阶段）
#
# 禁止事项：
# - 不得在此文件中写胜负判定逻辑
# - 不得在此文件中写规则逻辑

class_name MatchState
extends RefCounted

# 对局基本信息
var match_id: int = 0
var tick: int = 0

# 对局阶段枚举
enum Phase {
	BOOTSTRAP,      # 初始化阶段
	COUNTDOWN,      # 倒计时阶段
	PLAYING,        # 游戏进行中
	ENDING,         # 结束流程中
	ENDED           # 对局结束
}

var phase: int = Phase.BOOTSTRAP

# 模式与地图标识
var mode_id: StringName = "default"
var map_id: StringName = "default"

# 随机种子
var rng_seed: int = 0

# 剩余 Tick 数（用于计时模式）
var remaining_ticks: int = 0

# 胜利信息
var winner_team_id: int = -1
var winner_player_id: int = -1

# 结束原因枚举
enum EndReason {
	NONE,
	LAST_SURVIVOR,
	TEAM_ELIMINATED,
	TIME_UP,
	MODE_OBJECTIVE,
	FORCE_END
}

var ended_reason: int = EndReason.NONE

# 初始化构造
func _init(
	p_match_id: int = 0,
	p_mode_id: StringName = "default",
	p_map_id: StringName = "default",
	p_seed: int = 0
) -> void:
	match_id = p_match_id
	mode_id = p_mode_id
	map_id = p_map_id
	rng_seed = p_seed

# 重置对局状态（保留基本信息）
func reset() -> void:
	tick = 0
	phase = Phase.BOOTSTRAP
	remaining_ticks = 0
	winner_team_id = -1
	winner_player_id = -1
	ended_reason = EndReason.NONE
