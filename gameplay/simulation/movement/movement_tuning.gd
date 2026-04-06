class_name MovementTuning
extends RefCounted

const MOVEMENT_SUBSTEP_COUNT := 4
const TURN_SNAP_SUBSTEP_WINDOW := 2
const PASS_OFFSET_SUBSTEP_WINDOW := 2
const PASS_ABSORB_TICK_WINDOW := 1
const BUBBLE_FORWARD_PLACE_SUBSTEP_WINDOW := 2

const MOVE_STEP_UNITS := 250
const SPEED_UNITS_LV1 := 250
const SPEED_UNITS_LV2 := 334
const SPEED_UNITS_LV3 := 500


static func movement_units_per_tick(speed_level: int) -> int:
	match max(speed_level, 1):
		1:
			return SPEED_UNITS_LV1
		2:
			return SPEED_UNITS_LV2
		3:
			return SPEED_UNITS_LV3
		_:
			return SPEED_UNITS_LV3


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


static func pass_absorb_window_units(total_units: int) -> int:
	return max(total_units * max(PASS_ABSORB_TICK_WINDOW, 1), 0)
