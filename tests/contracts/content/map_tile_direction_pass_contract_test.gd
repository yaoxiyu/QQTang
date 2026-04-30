extends "res://tests/gut/base/qqt_contract_test.gd"


func test_main() -> void:
	_assert_true(TileConstants.PASS_HORIZONTAL == TileConstants.PASS_E | TileConstants.PASS_W, "horizontal pass mask is E/W")
	_assert_true(TileConstants.PASS_VERTICAL == TileConstants.PASS_N | TileConstants.PASS_S, "vertical pass mask is N/S")
	var floor_cell := TileFactory.make_empty()
	var solid_cell := TileFactory.make_solid_wall()
	var breakable_cell := TileFactory.make_breakable_block()
	_assert_true(floor_cell.movement_pass_mask == TileConstants.PASS_ALL, "floor movement pass is all")
	_assert_true(solid_cell.movement_pass_mask == TileConstants.PASS_NONE, "solid wall movement pass is none")
	_assert_true(breakable_cell.movement_pass_mask == TileConstants.PASS_NONE, "breakable movement pass is none")
	_assert_true((TileConstants.PASS_HORIZONTAL & TileConstants.PASS_E) != 0, "horizontal allows east")
	_assert_true((TileConstants.PASS_HORIZONTAL & TileConstants.PASS_N) == 0, "horizontal blocks north")
	_assert_true((TileConstants.PASS_VERTICAL & TileConstants.PASS_N) != 0, "vertical allows north")
	_assert_true((TileConstants.PASS_VERTICAL & TileConstants.PASS_E) == 0, "vertical blocks east")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
