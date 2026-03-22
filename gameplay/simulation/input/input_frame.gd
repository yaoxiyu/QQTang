# 角色：
# 输入帧，包含一个 Tick 的所有玩家输入命令
#
# 读写边界：
# - 只在 InputBuffer 中被写入
# - 只在 InputSystem 中被读取
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name InputFrame
extends RefCounted

# 当前 Frame 对应的 Tick
var tick: int = 0

# 玩家命令字典：player_slot -> PlayerCommand
var commands_by_player_slot: Dictionary = {}

# ====================
# 基础方法
# ====================

# 设置玩家命令
func set_command(player_slot: int, command: PlayerCommand) -> void:
	commands_by_player_slot[player_slot] = command

# 获取玩家命令
func get_command(player_slot: int) -> PlayerCommand:
	return commands_by_player_slot.get(player_slot, PlayerCommand.neutral())

# 获取所有玩家插槽数
func get_slot_count() -> int:
	return commands_by_player_slot.size()

# 检查是否有某个玩家的输入
func has_command(player_slot: int) -> bool:
	return player_slot in commands_by_player_slot
