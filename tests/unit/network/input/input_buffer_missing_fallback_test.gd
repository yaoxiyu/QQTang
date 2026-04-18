extends "res://tests/gut/base/qqt_unit_test.gd"


func test_main() -> void:
	var buffer := InputBuffer.new()
	var held := PlayerInputFrame.new()
	held.peer_id = 7
	held.tick_id = 3
	held.seq = 77
	held.move_x = -1
	held.action_place = true
	buffer.push_input(held)

	var fallback := buffer.get_input(7, 4)
	_assert(fallback.move_x == -1, "missing input should reuse last movement direction")
	_assert(fallback.move_y == 0, "missing input should preserve neutral vertical axis when absent")
	_assert(not fallback.action_place, "missing input should clear one-shot place action")
	_assert(fallback.seq == held.seq, "missing input should preserve last known sequence id")

	var idle := buffer.get_input(99, 1)
	_assert(idle.move_x == 0 and idle.move_y == 0, "peer with no history should fallback to idle input")
	_assert(idle.seq == 0, "idle input should use neutral sequence id")



func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)

