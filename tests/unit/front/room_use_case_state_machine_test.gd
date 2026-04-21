extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomUseCaseScript = preload("res://app/front/room/room_use_case.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
class FakeGateway:
	extends "res://network/runtime/room_client/room_client_gateway.gd"
	var cancel_called := false
	var leave_called := false

	func request_cancel_match_queue() -> void:
		cancel_called = true

	func request_leave_room_and_disconnect() -> void:
		leave_called = true


class FakeFrontFlow:
	extends RefCounted
	var entered_lobby := false

	func enter_lobby() -> void:
		entered_lobby = true


class FakeRoomSessionController:
	extends Control
	var reset_called := false
	var room_runtime_context = null

	func reset_room_state() -> void:
		reset_called = true


class FakeSettingsState:
	extends RefCounted
	var cleared := false

	func clear_reconnect_ticket() -> void:
		cleared = true


class FakeSettingsRepository:
	extends RefCounted
	var saved := false

	func save_settings(_state: RefCounted) -> void:
		saved = true


class FakeRuntime:
	extends Control
	var current_room_snapshot: RoomSnapshot = null
	var current_room_entry_context: RoomEntryContext = null
	var room_session_controller: Node = null
	var front_settings_state: RefCounted = null
	var front_settings_repository: RefCounted = null
	var front_flow: RefCounted = null


func test_leave_room_cancels_queue_by_canonical_queue_phase() -> void:
	var use_case := RoomUseCaseScript.new()
	var runtime := FakeRuntime.new()
	var gateway := FakeGateway.new()
	var front_flow := FakeFrontFlow.new()
	var controller := FakeRoomSessionController.new()
	var settings_state := FakeSettingsState.new()
	var settings_repo := FakeSettingsRepository.new()

	var entry := RoomEntryContextScript.new()
	entry.room_kind = "ranked_match_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry

	var snapshot := RoomSnapshotScript.new()
	snapshot.room_kind = "ranked_match_room"
	snapshot.topology = "dedicated_server"
	snapshot.queue_phase = "assignment_pending"
	snapshot.room_queue_state = "idle"
	runtime.current_room_snapshot = snapshot
	runtime.room_session_controller = controller
	runtime.front_settings_state = settings_state
	runtime.front_settings_repository = settings_repo
	runtime.front_flow = front_flow

	use_case.app_runtime = runtime
	use_case.room_client_gateway = gateway

	var result: Dictionary = use_case.leave_room()
	assert_true(bool(result.get("ok", false)), "leave_room should succeed: %s" % JSON.stringify(result))
	assert_true(gateway.cancel_called, "leave_room should cancel queue based on canonical queue_phase")
	assert_true(gateway.leave_called, "leave_room should always request leave/disconnect")
	assert_true(controller.reset_called, "leave_room should reset room state")
	assert_true(front_flow.entered_lobby, "leave_room should enter lobby")
	assert_true(settings_state.cleared and settings_repo.saved, "leave_room should clear and persist reconnect ticket")


func test_leave_room_does_not_cancel_when_queue_phase_completed_even_if_legacy_queueing() -> void:
	var use_case := RoomUseCaseScript.new()
	var runtime := FakeRuntime.new()
	var gateway := FakeGateway.new()

	var entry := RoomEntryContextScript.new()
	entry.room_kind = "casual_match_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry

	var snapshot := RoomSnapshotScript.new()
	snapshot.room_kind = "casual_match_room"
	snapshot.topology = "dedicated_server"
	snapshot.queue_phase = "completed"
	snapshot.room_queue_state = "queueing"
	runtime.current_room_snapshot = snapshot
	runtime.room_session_controller = FakeRoomSessionController.new()
	runtime.front_settings_state = FakeSettingsState.new()
	runtime.front_settings_repository = FakeSettingsRepository.new()
	runtime.front_flow = FakeFrontFlow.new()

	use_case.app_runtime = runtime
	use_case.room_client_gateway = gateway

	var result: Dictionary = use_case.leave_room()
	assert_true(bool(result.get("ok", false)), "leave_room should succeed: %s" % JSON.stringify(result))
	assert_false(gateway.cancel_called, "leave_room should not cancel queue when canonical queue_phase is completed")
