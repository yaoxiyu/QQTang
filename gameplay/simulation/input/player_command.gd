# 角色：
# 玩家在单个 Tick 的输入命令
#
# 读写边界：
# - 只在 InputSystem 中被写入
# - 只在 MovementSystem/ BubblePlacementSystem 中被读取
#
# 禁止事项：
# - 不得在此文件中写任何规则逻辑

class_name PlayerCommand
extends RefCounted

# 移动方向，范围 [-1, 0, 1]
var move_x: int = 0
var move_y: int = 0

# 边沿触发命令
var place_bubble: bool = false
var remote_trigger: bool = false

# 其他命令
var emote_id: int = 0
var sequence_id: int = 0

# 初始化构造
func _init(
	p_move_x: int = 0,
	p_move_y: int = 0,
	p_place_bubble: bool = false,
	p_remote_trigger: bool = false,
	p_emote_id: int = 0,
	p_sequence_id: int = 0
) -> void:
	move_x = p_move_x
	move_y = p_move_y
	place_bubble = p_place_bubble
	remote_trigger = p_remote_trigger
	emote_id = p_emote_id
	sequence_id = p_sequence_id

# 静态构造：空命令（Neutral Command）
static func neutral() -> PlayerCommand:
	return PlayerCommand.new(0, 0, false, false, 0, 0)

# 复制内容
func copy_from(other: PlayerCommand) -> void:
	move_x = other.move_x
	move_y = other.move_y
	place_bubble = other.place_bubble
	remote_trigger = other.remote_trigger
	emote_id = other.emote_id
	sequence_id = other.sequence_id
