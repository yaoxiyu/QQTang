class_name GridMotionMath
extends RefCounted

const CELL_UNITS := 1000
const HALF_CELL_UNITS := 500


static func to_abs_x(cell_x: int, offset_x: int) -> int:
	return get_cell_center_abs_x(cell_x) + offset_x


static func to_abs_y(cell_y: int, offset_y: int) -> int:
	return get_cell_center_abs_y(cell_y) + offset_y


static func abs_to_cell_and_offset_x(abs_x: int) -> Dictionary:
	return _abs_to_cell_and_offset(abs_x, "cell_x", "offset_x")


static func abs_to_cell_and_offset_y(abs_y: int) -> Dictionary:
	return _abs_to_cell_and_offset(abs_y, "cell_y", "offset_y")


static func get_player_abs_pos(player: PlayerState) -> Vector2i:
	return Vector2i(
		to_abs_x(player.cell_x, player.offset_x),
		to_abs_y(player.cell_y, player.offset_y)
	)


static func write_player_abs_pos(player: PlayerState, abs_x: int, abs_y: int) -> void:
	var x_result := abs_to_cell_and_offset_x(abs_x)
	var y_result := abs_to_cell_and_offset_y(abs_y)
	player.cell_x = int(x_result["cell_x"])
	player.offset_x = int(x_result["offset_x"])
	player.cell_y = int(y_result["cell_y"])
	player.offset_y = int(y_result["offset_y"])


static func get_cell_center_abs_x(cell_x: int) -> int:
	return cell_x * CELL_UNITS + HALF_CELL_UNITS


static func get_cell_center_abs_y(cell_y: int) -> int:
	return cell_y * CELL_UNITS + HALF_CELL_UNITS


static func _abs_to_cell_and_offset(abs_value: int, cell_key: String, offset_key: String) -> Dictionary:
	var cell := _floor_div_cell_units(abs_value)
	var center := cell * CELL_UNITS + HALF_CELL_UNITS
	var offset := abs_value - center
	return {
		cell_key: cell,
		offset_key: offset,
	}


static func _floor_div_cell_units(value: int) -> int:
	if value >= 0:
		return int(value / CELL_UNITS)
	return -int(ceil(float(-value) / float(CELL_UNITS)))
