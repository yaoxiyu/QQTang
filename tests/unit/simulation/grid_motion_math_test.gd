extends Node

const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")


func _ready() -> void:
	_assert(GridMotionMath.to_abs_x(0, 0) == 500, "cell center converts to abs x")
	_assert(GridMotionMath.to_abs_y(2, -500) == 2000, "cell plus offset converts to abs y")

	var right_edge := GridMotionMath.abs_to_cell_and_offset_x(999)
	_assert(int(right_edge["cell_x"]) == 0, "999 stays in cell 0")
	_assert(int(right_edge["offset_x"]) == 499, "999 maps to offset 499")

	var boundary := GridMotionMath.abs_to_cell_and_offset_x(1000)
	_assert(int(boundary["cell_x"]) == 1, "1000 belongs to next cell by half-open interval")
	_assert(int(boundary["offset_x"]) == -500, "1000 maps to -500 in next cell")

	var player := PlayerState.new()
	GridMotionMath.write_player_abs_pos(player, 1000, 2500)
	_assert(player.cell_x == 1 and player.offset_x == -500, "write abs x rebases to legal range")
	_assert(player.cell_y == 2 and player.offset_y == 0, "write abs y rebases to legal range")

	var round_trip := GridMotionMath.get_player_abs_pos(player)
	_assert(round_trip == Vector2i(1000, 2500), "write and read back remain stable")

	GridMotionMath.write_player_abs_pos(player, round_trip.x, round_trip.y)
	_assert(player.cell_x == 1 and player.offset_x == -500, "repeated write remains deterministic")
	_assert(player.cell_y == 2 and player.offset_y == 0, "repeated write keeps y deterministic")

	print("test_grid_motion_math: PASS")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_grid_motion_math: FAIL - %s" % message)
