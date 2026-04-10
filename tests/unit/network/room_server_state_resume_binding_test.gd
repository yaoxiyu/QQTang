extends Node

const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")


func _ready() -> void:
	var ok := true
	ok = _test_disconnected_member_remains_in_snapshot() and ok
	if ok:
		print("room_server_state_resume_binding_test: PASS")


func _test_disconnected_member_remains_in_snapshot() -> bool:
	var state := RoomServerStateScript.new()
	state.ensure_room("room_a", 2, "private_room", "")
	state.upsert_member(2, "Player2", "hero_default")
	state.set_ready(2, true)
	state.freeze_match_peer_bindings("match_a")
	state.match_active = true
	state.mark_member_disconnected_by_transport_peer(2, Time.get_ticks_msec() + 20000, "match_a")

	var snapshot := state.build_snapshot()
	if snapshot.members.size() != 1:
		print("FAIL: disconnected member should remain in room snapshot")
		return false
	var member := snapshot.members[0]
	if member.peer_id != 2:
		print("FAIL: disconnected member should keep match peer id")
		return false
	if member.connection_state != "disconnected":
		print("FAIL: disconnected member state should be visible in snapshot")
		return false
	return true
