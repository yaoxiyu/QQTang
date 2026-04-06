class_name PlayerLocator
extends RefCounted

const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")


static func get_foot_cell(player: PlayerState) -> Vector2i:
	var abs_pos := GridMotionMath.get_player_abs_pos(player)
	var x_result := GridMotionMath.abs_to_cell_and_offset_x(abs_pos.x)
	var y_result := GridMotionMath.abs_to_cell_and_offset_y(abs_pos.y)
	return Vector2i(int(x_result["cell_x"]), int(y_result["cell_y"]))


static func get_abs_pos(player: PlayerState) -> Vector2i:
	return GridMotionMath.get_player_abs_pos(player)


static func get_offset(player: PlayerState) -> Vector2i:
	return Vector2i(player.offset_x, player.offset_y)
