# 角色：
# 双轴穿越阶段推进的纯函数集合。
# native kernel 在 player loop 末尾通过相同算法推进，并通过 bubble_phase_updates 回写到 GD。
# 本文件不再被 MovementSystem 调用——只用于：
#   1. SimQueries 的懒初始化辅助（compute_lazy_phase 通过 _resolve_target_phase）
#   2. 单元测试验证规则（_advance_axes / _resolve_target_phase / _sign_of）
#   3. 文档化 phase 推进规则，让 GDScript 端有可读参考实现
#
# 不变量：phase 只能 A→B→C 单调推进，不会回退。锁定 sign 在 A→B 时确定，B→C 时保持。

class_name BubblePhaseAdvancer
extends RefCounted

const BubblePassPhaseScript = preload("res://gameplay/simulation/entities/bubble_pass_phase.gd")
const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")


# 按当前 d 推进单个 phase 的两轴；返回是否有改变。
# 阈值：|d_axis| >= M/2 → 至少 B；|d_axis| >= M → C。锁定 sign 在 A→B 时确定。
static func _advance_axes(phase, d_x: int, d_y: int) -> bool:
	var changed := false
	var target_x := _resolve_target_phase(absi(d_x))
	if target_x > int(phase.phase_x):
		if int(phase.phase_x) == BubblePassPhaseScript.Phase.A:
			phase.sign_x = _sign_of(d_x)
		phase.phase_x = target_x
		changed = true

	var target_y := _resolve_target_phase(absi(d_y))
	if target_y > int(phase.phase_y):
		if int(phase.phase_y) == BubblePassPhaseScript.Phase.A:
			phase.sign_y = _sign_of(d_y)
		phase.phase_y = target_y
		changed = true

	return changed


static func _resolve_target_phase(abs_d: int) -> int:
	if abs_d >= GridMotionMath.CELL_UNITS:
		return BubblePassPhaseScript.Phase.C
	if abs_d >= GridMotionMath.HALF_CELL_UNITS:
		return BubblePassPhaseScript.Phase.B
	return BubblePassPhaseScript.Phase.A


static func _sign_of(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 1
