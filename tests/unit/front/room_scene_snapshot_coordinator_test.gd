extends Node

const CoordinatorScript = preload("res://scenes/front/room_scene_snapshot_coordinator.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

class FakeController:
	extends Node
	class FakeRuntime:
		extends RefCounted
		var local_peer_id: int = 7
	var _app_runtime = FakeRuntime.new()


func _ready() -> void:
	var prefix := "room_scene_snapshot_coordinator_test"
	var coordinator = CoordinatorScript.new()
	var controller := FakeController.new()
	var snapshot = RoomSnapshotScript.new()
	var local_member = RoomMemberStateScript.new()
	local_member.peer_id = 7
	var members: Array[RoomMemberState] = [local_member]
	snapshot.members = members
	var resolved = coordinator.resolve_local_member(controller, snapshot)
	var ok := TestAssert.is_true(resolved == local_member, "resolve_local_member should find local peer by runtime id", prefix)
	if ok:
		print("%s: PASS" % prefix)
	else:
		push_error("%s: FAIL" % prefix)
