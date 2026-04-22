# 角色：
# 运行时标志位，用于控制运行时行为
#
# 读写边界：
# - 可在 SimulationRunner 中被写入
# - 可在任何系统中被读取
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name RuntimeFlags
extends RefCounted

# 运行控制
var pause_requested: bool = false
var replay_mode: bool = false
var rollback_mode: bool = false
var client_prediction_mode: bool = false
var client_controlled_player_slot: int = -1
var suppress_authority_entity_side_effects: bool = false

# 调试控制
var debug_disable_damage: bool = false
var debug_inflict_damage: bool = false

# 一致性检查
var need_consistency_check: bool = false

# 重置所有标志
func reset() -> void:
	pause_requested = false
	replay_mode = false
	rollback_mode = false
	client_prediction_mode = false
	client_controlled_player_slot = -1
	suppress_authority_entity_side_effects = false
	debug_disable_damage = false
	debug_inflict_damage = false
	need_consistency_check = false
