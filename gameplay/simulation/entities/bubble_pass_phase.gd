# 角色：
# 单个 (bubble, player) 对的双轴穿越阶段记录。
#
# 读写边界：
# - 在 BubblePlacementSystem 初始化、BubblePhaseAdvancer 推进、Snapshot/Bridge 序列化时读写。
# - 不得在此文件中写规则逻辑——纯数据。

class_name BubblePassPhase
extends RefCounted

enum Phase {
	A = 0,  # 自由穿越：玩家在该轴上完全无视泡泡
	B = 1,  # 单向墙：泡泡中心在该轴成为方向化阻挡
	C = 2,  # 完全阻挡：泡泡在该轴上恢复为常规障碍
}

var player_id: int = -1
var phase_x: int = Phase.A
var phase_y: int = Phase.A
# 仅在 phase_x in {B, C} 时有意义；A 时强制为 0。
var sign_x: int = 0
# 仅在 phase_y in {B, C} 时有意义；A 时强制为 0。
var sign_y: int = 0


func duplicate_phase() -> Variant:
	var copy = (load("res://gameplay/simulation/entities/bubble_pass_phase.gd")).new()
	copy.player_id = player_id
	copy.phase_x = phase_x
	copy.phase_y = phase_y
	copy.sign_x = sign_x
	copy.sign_y = sign_y
	return copy
