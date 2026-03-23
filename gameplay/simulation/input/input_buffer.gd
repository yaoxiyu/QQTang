# 角色：
# 输入缓冲区，管理历史输入帧
#
# 读写边界：
# - 只在 SimulationRunner 中被写入
# - 只在 InputSystem 中被读取
#
# 禁止事项：
# - 不得在此文件中写规则逻辑
# - 不得直接读取键盘事件

class_name InputBuffer
extends RefCounted

# 输入帧字典：tick -> InputFrame
var frames: Dictionary = {}

# ====================
# 核心方法
# ====================

# 推送输入帧
func push_input_frame(frame: InputFrame) -> void:
	frames[frame.tick] = frame

# 生成或获取指定 Tick 的输入帧
# 如果缺失玩家命令，自动补 Neutral Command
func consume_or_build_for_tick(
	tick: int,
	player_slots: Array[int]
) -> InputFrame:
	var frame : InputFrame
	# 如果已有该 Tick 的帧，直接返回
	if tick in frames:
		frame = frames[tick]
		# 确保所有玩家都有命令
		for slot in player_slots:
			if not frame.has_command(slot):
				frame.set_command(slot, PlayerCommand.neutral())
		return frame

	# 否则创建新帧
	frame = InputFrame.new()
	frame.tick = tick

	for slot in player_slots:
		frame.set_command(slot, PlayerCommand.neutral())

	frames[tick] = frame
	return frame

# 清除指定 Tick 之前的数据
func clear_before_tick(tick: int) -> void:
	var to_remove: Array[int] = []
	for frame_tick in frames:
		if frame_tick < tick:
			to_remove.append(frame_tick)

	for frame_tick in to_remove:
		frames.erase(frame_tick)

# ====================
# 辅助方法
# ====================

# 获取所有已记录的 Tick
func get_recorded_ticks() -> Array[int]:
	var ticks: Array[int] = []
	for tick in frames:
		ticks.append(tick)
	ticks.sort()
	return ticks

# 清空所有输入
func clear() -> void:
	frames.clear()
