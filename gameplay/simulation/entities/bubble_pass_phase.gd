# 角色：
# 单个 (bubble, player) 对的双轴穿越阶段记录。
#
# 读写边界：
# - 在 BubblePlacementSystem 初始化、BubblePhaseAdvancer 推进、Snapshot/Bridge 序列化时读写。
# - 不得在此文件中写规则逻辑——纯数据。

class_name BubblePassPhase
extends RefCounted

enum Phase {
	A = 0,  # 自由穿越（|d| < M/2）
	B = 1,  # 对称阻挡（M/2 <= |d| < M）
	C = 2,  # 完全阻挡（|d| >= M），不可重回重叠
}

var player_id: int = -1
var phase_x: int = Phase.A
var phase_y: int = Phase.A
# sign 仅在 A→B 推进时记录方向（确定性写入），不参与阻挡逻辑。
var sign_x: int = 0
var sign_y: int = 0


func duplicate_phase() -> Variant:
	var copy = (load("res://gameplay/simulation/entities/bubble_pass_phase.gd")).new()
	copy.player_id = player_id
	copy.phase_x = phase_x
	copy.phase_y = phase_y
	copy.sign_x = sign_x
	copy.sign_y = sign_y
	return copy
