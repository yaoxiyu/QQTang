class_name MovementTuning
extends RefCounted

const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")

const MOVE_STEP_UNITS : int = WorldMetrics.TENTH_CELL_UNITS
const TURN_SNAP_WINDOW_UNITS : int = WorldMetrics.FIFTH_CELL_UNITS
const PASS_ABSORB_WINDOW_UNITS : int = WorldMetrics.HALF_CELL_UNITS
const BUBBLE_FORWARD_PLACE_WINDOW_UNITS : int = WorldMetrics.HALF_CELL_UNITS

# 泡泡 overlap/距离判定的参考中心选择策略：
#   0 = 单格中心（仅 bubble.cell_x/cell_y），与历史行为一致；多格泡泡边角玩家可能漏判。
#   1 = footprint 内距玩家最近格的中心，几何更准确。
const BUBBLE_OVERLAP_CENTER_MODE : int = 0

# 泡泡阻挡 phase 的初始化策略：
#   0 = 仅在放泡瞬间为重叠玩家初始化 (A,A)；其他玩家在 pass_phases 中无条目即完全阻挡。
#   1 = 懒初始化：任何玩家首次与泡泡 |d| < CELL_UNITS 时按当前 d 计算初始 phase。
const BUBBLE_PHASE_INIT_MODE : int = 0

const SPEED_UNITS_PER_TICK: PackedInt32Array = [
	70,
	82,
	94,
	106,
	118,
	130,
	142,
	154,
	166,
]


static func movement_units_per_tick(speed_level: int) -> int:
	var index := clampi(speed_level, 1, max_speed_level()) - 1
	return SPEED_UNITS_PER_TICK[index]


static func max_speed_level() -> int:
	return SPEED_UNITS_PER_TICK.size()


static func movement_substep_units() -> int:
	return MOVE_STEP_UNITS


static func movement_step_units() -> int:
	return movement_substep_units()


static func turn_snap_window_units() -> int:
	return TURN_SNAP_WINDOW_UNITS


static func pass_absorb_window_units() -> int:
	return PASS_ABSORB_WINDOW_UNITS


static func bubble_forward_place_window_units() -> int:
	return BUBBLE_FORWARD_PLACE_WINDOW_UNITS


static func bubble_overlap_center_mode() -> int:
	return BUBBLE_OVERLAP_CENTER_MODE


static func bubble_phase_init_mode() -> int:
	return BUBBLE_PHASE_INIT_MODE
