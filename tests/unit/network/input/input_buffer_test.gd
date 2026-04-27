extends "res://tests/gut/base/qqt_unit_test.gd"


func test_main() -> void:
	var buffer := InputBuffer.new()

	var frame := PlayerInputFrame.new()
	frame.peer_id = 1001
	frame.tick_id = 5
	frame.seq = 42
	frame.move_x = 1
	frame.action_bits = PlayerInputFrame.BIT_PLACE
	buffer.push_input(frame)

	var duplicate := PlayerInputFrame.new()
	duplicate.peer_id = 1001
	duplicate.tick_id = 5
	duplicate.seq = 99
	duplicate.move_x = -1
	buffer.push_input(duplicate)

	var exact := buffer.get_input(1001, 5)
	_assert(exact.seq == 99, "duplicate tick should keep latest seq for merge")
	_assert(exact.move_x == -1, "duplicate tick should merge latest movement")
	_assert((exact.action_bits & PlayerInputFrame.BIT_PLACE) == 0, "higher seq replacement should replace one-shot action edge")

	var fallback := buffer.get_input(1001, 6)
	_assert(fallback.tick_id == 6, "fallback input should target requested tick")
	_assert(fallback.move_x == -1, "fallback input should reuse latest merged movement")
	_assert((fallback.action_bits & PlayerInputFrame.BIT_PLACE) == 0, "fallback input should clear one-shot actions")

	var idle := buffer.get_input(2002, 10)
	_assert(idle.move_x == 0 and idle.move_y == 0, "unknown peer should return idle movement")
	_assert((idle.action_bits & PlayerInputFrame.BIT_PLACE) == 0, "unknown peer should return idle action state")

	var collected := buffer.collect_inputs_for_tick([1001, 2002], 6)
	_assert(collected.size() == 2, "collect_inputs_for_tick should return one frame per peer")
	_assert(collected[1001].move_x == -1, "collected fallback input should match held movement")
	_assert(collected[2002].tick_id == 6, "collected idle input should target requested tick")

	buffer.ack_peer(1001, 5)
	_assert(buffer.get_last_ack_tick(1001) == 5, "ack tick should be recorded")
	_assert(not buffer.frames_by_peer[1001].has(5), "acked frames should be cleared")



func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)
