extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomQueueCommandScript = preload("res://app/front/room/commands/room_queue_command.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const RoomClientGatewayScript = preload("res://network/runtime/room_client/room_client_gateway.gd")


class FakeRuntime:
	extends Control
	var current_room_entry_context: RoomEntryContext = null
	var current_room_snapshot: RoomSnapshot = null
	var room_session_controller: Node = null


func test_can_enter_queue_rejects_missing_runtime() -> void:
	var command := RoomQueueCommandScript.new()
	var gateway := RoomClientGatewayScript.new()

	var result := command.can_enter_queue(null, gateway, "room_alpha")

	assert_false(bool(result.get("ok", true)), "missing runtime should reject queue enter")
	assert_eq(String(result.get("error_code", "")), "APP_RUNTIME_MISSING", "missing runtime should use stable error code")


func test_can_enter_queue_rejects_missing_gateway() -> void:
	var command := RoomQueueCommandScript.new()
	var runtime := Node.new()

	var result := command.can_enter_queue(runtime, null, "room_alpha")
	runtime.free()

	assert_false(bool(result.get("ok", true)), "missing gateway should reject queue enter")
	assert_eq(String(result.get("error_code", "")), "ROOM_GATEWAY_MISSING", "missing gateway should use stable error code")


func test_can_enter_queue_rejects_missing_room_id() -> void:
	var command := RoomQueueCommandScript.new()
	var runtime := Node.new()
	var gateway := RoomClientGatewayScript.new()

	var result := command.can_enter_queue(runtime, gateway, "  ")
	runtime.free()

	assert_false(bool(result.get("ok", true)), "blank room id should reject queue enter")
	assert_eq(String(result.get("error_code", "")), "ROOM_ID_MISSING", "blank room id should use stable error code")


func test_can_enter_match_queue_accepts_online_match_room() -> void:
	var command := RoomQueueCommandScript.new()
	var runtime := FakeRuntime.new()
	var entry := RoomEntryContextScript.new()
	entry.room_kind = "ranked_match_room"
	entry.topology = "dedicated_server"
	runtime.current_room_entry_context = entry
	var gateway := RoomClientGatewayScript.new()

	var result: Dictionary = command.can_enter_match_queue(runtime, gateway)

	assert_true(bool(result.get("ok", false)), "online match room with gateway should enter queue")
	runtime.free()


func test_acknowledge_enter_match_queue_pending_returns_reason_for_active_queue_snapshot() -> void:
	var command := RoomQueueCommandScript.new()
	var state := RoomUseCaseRuntimeState.new()
	var snapshot := RoomSnapshot.new()
	state.mark_enter_match_queue_pending("room_alpha")
	snapshot.room_id = "room_alpha"
	snapshot.queue_phase = "queued"

	var reason := command.acknowledge_enter_match_queue_pending(state, snapshot)

	assert_eq(reason, "queue_state_acknowledged", "active canonical queue phase should acknowledge pending queue enter")


func test_acknowledge_enter_match_queue_pending_returns_room_changed_for_different_room() -> void:
	var command := RoomQueueCommandScript.new()
	var state := RoomUseCaseRuntimeState.new()
	var snapshot := RoomSnapshot.new()
	state.mark_enter_match_queue_pending("room_alpha")
	snapshot.room_id = "room_beta"

	var reason := command.acknowledge_enter_match_queue_pending(state, snapshot)

	assert_eq(reason, "room_changed", "snapshot from a different room should clear stale queue pending state")
