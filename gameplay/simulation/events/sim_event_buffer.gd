# 角色：
# 事件缓冲区，收集当前 Tick 的所有事件
#
# 读写边界：
# - 只在系统中被写入
# - 只在 PresentationBridge 中被读取
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name SimEventBuffer
extends RefCounted

# 当前 Tick
var current_tick: int = 0

# 事件列表
var events: Array[SimEvent] = []

# ====================
# 核心方法
# ====================

# 开始一个新的 Tick
func begin_tick(tick: int) -> void:
	current_tick = tick
	events.clear()

# 推送事件
func push(event: SimEvent) -> void:
	event.tick = current_tick
	events.append(event)

# 获取所有事件
func get_events() -> Array[SimEvent]:
	return events.duplicate()

# 清空
func clear() -> void:
	events.clear()
	current_tick = 0
