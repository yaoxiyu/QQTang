class_name BubblePlaceResolver
extends RefCounted

const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")
const MovementTuning = preload("res://gameplay/simulation/movement/movement_tuning.gd")
const PlayerStateScript = preload("res://gameplay/simulation/entities/player_state.gd")


static func resolve_place_cell(player: PlayerState) -> Vector2i:
	var abs_pos := GridMotionMath.get_player_abs_pos(player)
	var forward_window_units := MovementTuning.bubble_forward_place_window_units()
	match player.facing:
		PlayerStateScript.FacingDir.RIGHT:
			return Vector2i(
				_resolve_forward_axis_cell(abs_pos.x, true, forward_window_units),
				_resolve_lateral_axis_cell(abs_pos.y, true)
			)
		PlayerStateScript.FacingDir.LEFT:
			return Vector2i(
				_resolve_forward_axis_cell(abs_pos.x, false, forward_window_units),
				_resolve_lateral_axis_cell(abs_pos.y, false)
			)
		PlayerStateScript.FacingDir.UP:
			return Vector2i(
				_resolve_lateral_axis_cell(abs_pos.x, true),
				_resolve_forward_axis_cell(abs_pos.y, false, forward_window_units)
			)
		_:
			return Vector2i(
				_resolve_lateral_axis_cell(abs_pos.x, false),
				_resolve_forward_axis_cell(abs_pos.y, true, forward_window_units)
			)


static func _resolve_forward_axis_cell(abs_value: int, positive_forward: bool, forward_window_units: int) -> int:
	var axis := GridMotionMath.abs_to_cell_and_offset_x(abs_value)
	var cell := int(axis["cell_x"])
	var offset := int(axis["offset_x"])
	var front_cell := cell
	var back_cell := cell

	if positive_forward:
		if offset <= 0:
			front_cell = cell
			back_cell = cell - 1
		else:
			front_cell = cell + 1
			back_cell = cell
	else:
		if offset >= 0:
			front_cell = cell
			back_cell = cell + 1
		else:
			front_cell = cell - 1
			back_cell = cell

	var front_center := GridMotionMath.get_cell_center_abs_x(front_cell)
	var front_distance: int = abs(abs_value - front_center)
	if front_distance <= forward_window_units:
		return front_cell
	return back_cell


static func _resolve_lateral_axis_cell(abs_value: int, prefer_positive_on_tie: bool) -> int:
	var axis := GridMotionMath.abs_to_cell_and_offset_x(abs_value)
	var cell := int(axis["cell_x"])
	var offset := int(axis["offset_x"])
	if offset == -GridMotionMath.HALF_CELL_UNITS:
		return cell if prefer_positive_on_tie else cell - 1
	return cell
