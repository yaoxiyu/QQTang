class_name MovementTuning
extends RefCounted

const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")

const MOVE_STEP_UNITS : int = WorldMetrics.TENTH_CELL_UNITS
const TURN_SNAP_WINDOW_UNITS : int = WorldMetrics.QUARTER_CELL_UNITS
const PASS_ABSORB_WINDOW_UNITS : int = WorldMetrics.QUARTER_CELL_UNITS
const BUBBLE_FORWARD_PLACE_WINDOW_UNITS : int = WorldMetrics.EIGHTH_CELL_UNITS

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
