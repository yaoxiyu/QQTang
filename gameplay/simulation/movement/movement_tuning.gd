class_name MovementTuning
extends RefCounted

const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")

const MOVEMENT_SUBSTEP_COUNT := 4
const TURN_SNAP_SUBSTEP_WINDOW := 2
const PASS_OFFSET_SUBSTEP_WINDOW := 2
const PASS_ABSORB_TICK_WINDOW := 1
const BUBBLE_FORWARD_PLACE_SUBSTEP_WINDOW := 2

const MOVE_STEP_UNITS := WorldMetrics.QUARTER_CELL_UNITS
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


static func substep_window_units(total_units: int, substep_count: int) -> int:
	var safe_count : int = max(substep_count, 1)
	return int(ceili(float(total_units) / float(safe_count)))


static func distance_units_to_substeps(distance_units: int, total_units: int, substep_count: int) -> int:
	if distance_units <= 0:
		return 0
	var window_step_units := substep_window_units(total_units, substep_count)
	if window_step_units <= 0:
		return 0
	return int(ceili(float(distance_units) / float(window_step_units)))


static func turn_snap_window_units() -> int:
	return TURN_SNAP_WINDOW_UNITS


static func pass_absorb_window_units() -> int:
	return PASS_ABSORB_WINDOW_UNITS


static func bubble_forward_place_window_units() -> int:
	return BUBBLE_FORWARD_PLACE_WINDOW_UNITS
