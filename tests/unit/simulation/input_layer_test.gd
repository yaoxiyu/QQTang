extends "res://tests/gut/base/qqt_unit_test.gd"

func test_main() -> void:
	var buffer := InputBuffer.new()

	var frame := InputFrame.new()
	frame.tick = 10
	var cmd := PlayerCommand.new()
	cmd.move_x = 1
	frame.set_command(0, cmd)
	buffer.push_input_frame(frame)
	var older := InputFrame.new()
	older.tick = 9
	buffer.push_input_frame(older)

	var consumed := buffer.consume_or_build_for_tick(10, [0, 1])
	_assert(consumed.get_command(0).move_x == 1, "existing command should be kept")
	_assert(consumed.has_command(1), "missing slot should be auto-filled")
	_assert(consumed.get_command(1).move_x == 0 and consumed.get_command(1).move_y == 0, "auto-filled command should be neutral")

	buffer.clear_before_tick(10)
	_assert(not (9 in buffer.frames), "old frame should be removed")


func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)

