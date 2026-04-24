extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")


class FakeOrchestrator:
	extends RefCounted

	var pending_online_entry_context: RoomEntryContext = null
	var pending_connection_config: ClientConnectionConfig = null
	var await_room_before_enter: bool = false


func test_sync_pending_connection_copies_orchestrator_state() -> void:
	var state := RoomUseCaseRuntimeStateScript.new()
	var orchestrator := FakeOrchestrator.new()
	orchestrator.pending_online_entry_context = RoomEntryContext.new()
	orchestrator.pending_connection_config = ClientConnectionConfig.new()
	orchestrator.await_room_before_enter = true

	state.sync_pending_connection(orchestrator)

	assert_true(state.pending_online_entry_context == orchestrator.pending_online_entry_context, "pending entry context should sync from orchestrator")
	assert_true(state.pending_connection_config == orchestrator.pending_connection_config, "pending config should sync from orchestrator")
	assert_true(state.await_room_before_enter, "await-room flag should sync from orchestrator")


func test_clear_transient_state_clears_pending_and_queue_state() -> void:
	var state := RoomUseCaseRuntimeStateScript.new()
	state.pending_online_entry_context = RoomEntryContext.new()
	state.pending_connection_config = ClientConnectionConfig.new()
	state.await_room_before_enter = true
	state.mark_enter_match_queue_pending("room_1")

	state.clear_transient_state()

	assert_null(state.pending_online_entry_context, "pending entry should clear")
	assert_null(state.pending_connection_config, "pending config should clear")
	assert_false(state.await_room_before_enter, "await-room flag should clear")
	assert_false(state.enter_match_queue_pending, "queue pending should clear")
	assert_eq(state.enter_match_queue_pending_room_id, "", "queue pending room id should clear")
