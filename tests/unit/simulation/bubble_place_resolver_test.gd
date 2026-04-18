extends "res://tests/gut/base/qqt_unit_test.gd"

const BubblePlaceResolver = preload("res://gameplay/simulation/movement/bubble_place_resolver.gd")
const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")
const MovementTuning = preload("res://gameplay/simulation/movement/movement_tuning.gd")


func test_main() -> void:
	var right_forward := _make_player(PlayerState.FacingDir.RIGHT)
	GridMotionMath.write_player_abs_pos(
		right_forward,
		GridMotionMath.get_cell_center_abs_x(6) - MovementTuning.bubble_forward_place_window_units(),
		GridMotionMath.get_cell_center_abs_y(5)
	)
	_assert(BubblePlaceResolver.resolve_place_cell(right_forward) == Vector2i(6, 5), "right-facing player should place into front cell inside forward window")

	var right_back := _make_player(PlayerState.FacingDir.RIGHT)
	GridMotionMath.write_player_abs_pos(
		right_back,
		GridMotionMath.get_cell_center_abs_x(6) - MovementTuning.bubble_forward_place_window_units() - 1,
		GridMotionMath.get_cell_center_abs_y(5)
	)
	_assert(BubblePlaceResolver.resolve_place_cell(right_back) == Vector2i(5, 5), "right-facing player should fall back to current cell outside forward window")

	var right_tie := _make_player(PlayerState.FacingDir.RIGHT)
	GridMotionMath.write_player_abs_pos(
		right_tie,
		GridMotionMath.get_cell_center_abs_x(5),
		GridMotionMath.get_cell_center_abs_y(5) - GridMotionMath.HALF_CELL_UNITS
	)
	_assert(BubblePlaceResolver.resolve_place_cell(right_tie) == Vector2i(5, 5), "positive lateral tie should stay on current row")

	var left_tie := _make_player(PlayerState.FacingDir.LEFT)
	GridMotionMath.write_player_abs_pos(
		left_tie,
		GridMotionMath.get_cell_center_abs_x(5),
		GridMotionMath.get_cell_center_abs_y(5) - GridMotionMath.HALF_CELL_UNITS
	)
	_assert(BubblePlaceResolver.resolve_place_cell(left_tie) == Vector2i(5, 4), "negative lateral tie should snap to previous row")



func _make_player(facing: int) -> PlayerState:
	var player := PlayerState.new()
	player.cell_x = 5
	player.cell_y = 5
	player.facing = facing
	return player


func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)

