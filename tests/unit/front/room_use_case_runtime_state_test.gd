extends "res://tests/gut/base/qqt_unit_test.gd"

const RuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")


class FakeRuntime:
	extends Control
	var current_room_snapshot: RoomSnapshot = null


func test_get_current_room_and_queue_phase_use_canonical_fields() -> void:
	var runtime := FakeRuntime.new()
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_phase = "battle_allocating"
	snapshot.queue_phase = "allocating_battle"
	runtime.current_room_snapshot = snapshot

	assert_eq(RuntimeStateScript.get_current_room_phase(runtime), "battle_allocating", "room phase should use canonical field")
	assert_eq(RuntimeStateScript.get_current_queue_phase(runtime), "allocating_battle", "queue phase should use canonical field")


func test_can_cancel_current_queue_matches_active_queue_phases() -> void:
	var runtime := FakeRuntime.new()
	var snapshot := RoomSnapshotScript.new()
	runtime.current_room_snapshot = snapshot

	snapshot.queue_phase = "queued"
	assert_true(RuntimeStateScript.can_cancel_current_queue(runtime), "queued should allow cancel")
	snapshot.queue_phase = "assignment_pending"
	assert_true(RuntimeStateScript.can_cancel_current_queue(runtime), "assignment_pending should allow cancel")
	snapshot.queue_phase = "allocating_battle"
	assert_true(RuntimeStateScript.can_cancel_current_queue(runtime), "allocating_battle should allow cancel")
	snapshot.queue_phase = "entry_ready"
	assert_true(RuntimeStateScript.can_cancel_current_queue(runtime), "entry_ready should allow cancel")
	snapshot.queue_phase = "completed"
	assert_false(RuntimeStateScript.can_cancel_current_queue(runtime), "completed should not allow cancel")
