# 角色：
# 仿真事件基类，所有仿真事件都继承自本类
#
# 读写边界：
# - 只在系统层被写入（通过事件缓冲）
# - 只在 Presentation 层被读取（用于视觉表现）
#
# 禁止事项：
# - 不得在此文件中写任何规则逻辑

class_name SimEvent
extends RefCounted

# 事件发生的 Tick
var tick: int = 0

# 事件类型枚举
enum EventType {
	PLAYER_MOVED,
	PLAYER_BLOCKED,
	BUBBLE_PLACED,
	BUBBLE_EXPLODED,
	CELL_DESTROYED,
	ITEM_SPAWNED,
	ITEM_PICKED,
	PLAYER_TRAPPED,
	PLAYER_KILLED,
	PLAYER_REVIVED,
	PLAYER_TRAP_EXECUTED,
	MATCH_PHASE_CHANGED,
	MATCH_ENDED
}

# 事件类型
var event_type: int = EventType.PLAYER_MOVED

# 事件附加数据（第一版统一使用字典承载）
var payload: Dictionary = {}

# 初始化构造
func _init(p_tick: int, p_event_type: int) -> void:
	tick = p_tick
	event_type = p_event_type
	payload = {}
