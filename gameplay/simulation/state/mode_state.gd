# 角色：
# 模式运行时状态，保存模式特有的运行时数据
#
# 读写边界：
# - 只在 ModeRuleSystem 中被写入
# - 可在其他系统中被读取（查询）
#
# 禁止事项：
# - 不得在此文件中写模式规则逻辑

class_name ModeState
extends RefCounted

# 模式运行时类型
var mode_runtime_type: StringName = "default"

# 团队存活计数
var team_alive_counts: Dictionary = {}

# 团队分数
var team_scores: Dictionary = {}

# 模式计时器（Tick 为单位）
var mode_timer_ticks: int = 0

# 载具/Payload 相关（特殊模式）
var payload_owner_id: int = -1
var payload_cell_x: int = -1
var payload_cell_y: int = -1

# 突死模式
var sudden_death_active: bool = false

# 自定义整数字段（特殊模式使用）
var custom_ints: Dictionary = {}

# 自定义布尔字段（特殊模式使用）
var custom_flags: Dictionary = {}

# 初始化
func _init(p_mode_type: StringName = "default") -> void:
	mode_runtime_type = p_mode_type

# 设置团队存活数
func set_team_alive_count(team_id: int, count: int) -> void:
	team_alive_counts[team_id] = count

# 获取团队存活数
func get_team_alive_count(team_id: int) -> int:
	return team_alive_counts.get(team_id, 0)

# 设置团队分数
func set_team_score(team_id: int, score: int) -> void:
	team_scores[team_id] = score

# 获取团队分数
func get_team_score(team_id: int) -> int:
	return team_scores.get(team_id, 0)

# 重置模式状态
func reset() -> void:
	mode_timer_ticks = 0
	payload_owner_id = -1
	payload_cell_x = -1
	payload_cell_y = -1
	sudden_death_active = false
	custom_ints.clear()
	custom_flags.clear()
	team_alive_counts.clear()
	team_scores.clear()
