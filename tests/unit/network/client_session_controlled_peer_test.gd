extends "res://tests/gut/base/qqt_unit_test.gd"

const ClientSessionScript = preload("res://network/session/runtime/client_session.gd")


func test_main() -> void:
	var ok := true
	ok = _test_input_frame_uses_controlled_peer_id() and ok


func _test_input_frame_uses_controlled_peer_id() -> bool:
	var session := ClientSessionScript.new()
	add_child(session)
	session.configure(9, 2)

	var frame := session.sample_input_for_tick(10, 1, 0, true)
	if frame.peer_id != 2:
		print("FAIL: sampled frame should use controlled peer id")
		return false
	session.send_input(frame)
	var outgoing := session.flush_outgoing_inputs()
	if outgoing.size() != 1:
		print("FAIL: expected one outgoing input")
		return false
	if outgoing[0].peer_id != 2:
		print("FAIL: outgoing frame should use controlled peer id")
		return false
	session.queue_free()
	return true

