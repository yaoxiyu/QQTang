extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomSnapshotFlowScript = preload("res://app/front/room/projection/room_snapshot_flow.gd")


class FakeController:
	extends Control
	var applied_snapshot: RoomSnapshot = null

	func apply_authoritative_snapshot(snapshot: RoomSnapshot) -> void:
		applied_snapshot = snapshot

	func build_room_snapshot() -> RoomSnapshot:
		return applied_snapshot


class FakeRuntime:
	extends Control
	var room_session_controller: Node = null
	var current_room_snapshot: RoomSnapshot = null
	var front_flow: Node = null
	var front_settings_state: RefCounted = null
	var front_settings_repository: RefCounted = null


func test_consume_authoritative_snapshot_updates_runtime_and_projection() -> void:
	var flow := RoomSnapshotFlowScript.new()
	var runtime := FakeRuntime.new()
	var controller := FakeController.new()
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "room_alpha"
	snapshot.room_phase = "idle"
	snapshot.snapshot_revision = 3
	snapshot.can_enter_queue = true
	runtime.room_session_controller = controller

	var result: Dictionary = flow.consume_authoritative_snapshot(runtime, snapshot, {})
	var view_state: Dictionary = result.get("view_state", {})
	var resume_context: Dictionary = result.get("resume_context", {})

	assert_eq(controller.applied_snapshot, snapshot, "snapshot flow should apply authoritative snapshot")
	assert_eq(runtime.current_room_snapshot, snapshot, "snapshot flow should refresh runtime current snapshot")
	assert_eq(String(view_state.get("room_id", "")), "room_alpha", "projection should include room id")
	assert_eq(int(view_state.get("revision", 0)), 3, "projection should include revision")
	assert_true(bool((view_state.get("capabilities", {}) as Dictionary).get("can_enter_queue", false)), "projection should include capabilities")
	assert_eq(String(resume_context.get("room_id", "")), "room_alpha", "resume context should be built from projection")
	controller.free()
	runtime.free()


func test_consume_authoritative_snapshot_skips_duplicate_revision_projection() -> void:
	var flow := RoomSnapshotFlowScript.new()
	var runtime := FakeRuntime.new()
	var controller := FakeController.new()
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "room_alpha"
	snapshot.room_phase = "idle"
	snapshot.snapshot_revision = 3
	runtime.room_session_controller = controller

	var first_result: Dictionary = flow.consume_authoritative_snapshot(runtime, snapshot, {})
	var first_view_state: Dictionary = first_result.get("view_state", {})
	var duplicate_snapshot := RoomSnapshot.new()
	duplicate_snapshot.room_id = "room_alpha"
	duplicate_snapshot.room_phase = "battle_entry_ready"
	duplicate_snapshot.snapshot_revision = 3

	var second_result: Dictionary = flow.consume_authoritative_snapshot(runtime, duplicate_snapshot, first_view_state)
	var second_view_state: Dictionary = second_result.get("view_state", {})

	assert_false(bool(first_result.get("projection_skipped", true)), "first snapshot should build projection")
	assert_true(bool(second_result.get("projection_skipped", false)), "same room revision should skip projection")
	assert_eq(String(second_view_state.get("phase", "")), "idle", "skipped projection should preserve cached phase")
	assert_eq(controller.applied_snapshot, duplicate_snapshot, "authoritative apply still receives duplicate snapshot")
	controller.free()
	runtime.free()


func test_consume_authoritative_snapshot_projects_new_revision_after_duplicate() -> void:
	var flow := RoomSnapshotFlowScript.new()
	var runtime := FakeRuntime.new()
	var controller := FakeController.new()
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "room_alpha"
	snapshot.room_phase = "idle"
	snapshot.snapshot_revision = 3
	runtime.room_session_controller = controller

	var first_result: Dictionary = flow.consume_authoritative_snapshot(runtime, snapshot, {})
	var next_snapshot := RoomSnapshot.new()
	next_snapshot.room_id = "room_alpha"
	next_snapshot.room_phase = "battle_entry_ready"
	next_snapshot.snapshot_revision = 4

	var second_result: Dictionary = flow.consume_authoritative_snapshot(runtime, next_snapshot, first_result.get("view_state", {}))
	var second_view_state: Dictionary = second_result.get("view_state", {})

	assert_false(bool(second_result.get("projection_skipped", true)), "new revision should rebuild projection")
	assert_eq(String(second_view_state.get("phase", "")), "battle_entry_ready", "new revision should update projected phase")
	controller.free()
	runtime.free()
