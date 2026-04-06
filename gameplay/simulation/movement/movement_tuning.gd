class_name MovementTuning
extends RefCounted

const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")

const MOVE_STEP_UNITS := WorldMetrics.TENTH_CELL_UNITS
const TURN_SNAP_WINDOW_UNITS := WorldMetrics.QUARTER_CELL_UNITS
const PASS_ABSORB_WINDOW_UNITS := WorldMetrics.QUARTER_CELL_UNITS
const BUBBLE_FORWARD_PLACE_WINDOW_UNITS := WorldMetrics.QUARTER_CELL_UNITS

const TICKS_PER_STEP_LV1 := 3
const TICKS_PER_STEP_LV2 := 2
const TICKS_PER_STEP_LV3 := 1


static func ticks_per_step(speed_level: int) -> int:
	match max(speed_level, 1):
		1:
			return TICKS_PER_STEP_LV1
		2:
			return TICKS_PER_STEP_LV2
		3:
			return TICKS_PER_STEP_LV3
		_:
			return TICKS_PER_STEP_LV3


static func movement_step_units() -> int:
	return MOVE_STEP_UNITS


static func turn_snap_window_units() -> int:
	return TURN_SNAP_WINDOW_UNITS


static func pass_absorb_window_units() -> int:
	return PASS_ABSORB_WINDOW_UNITS


static func bubble_forward_place_window_units() -> int:
	return BUBBLE_FORWARD_PLACE_WINDOW_UNITS
