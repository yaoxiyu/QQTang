extends Node

const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const ServerMatchServiceScript = preload("res://network/session/runtime/server_match_service.gd")
const ServerRoomRuntimeScript = preload("res://network/session/runtime/server_room_runtime.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


class MockMatchService:
	extends ServerMatchServiceScript

	var ingested_messages: Array[Dictionary] = []

	func _ready() -> void:
		pass

	func ingest_runtime_message(message: Dictionary) -> void:
		ingested_messages.append(message.duplicate(true))


func _ready() -> void:
	var ok := true
	ok = _test_rejects_unknown_transport_peer() and ok
	ok = _test_rejects_mismatched_control_peer() and ok
	ok = _test_accepts_bound_control_peer() and ok
	ok = _test_match_broadcast_targets_connected_bound_transports_only() and ok
	if ok:
		print("server_room_runtime_battle_input_guard_test: PASS")


func _test_rejects_unknown_transport_peer() -> bool:
	var fixture := _create_runtime_fixture()
	var runtime: ServerRoomRuntime = fixture["runtime"]
	var match_service: MockMatchService = fixture["match_service"]

	runtime.handle_battle_message(_input_message(99, 3))

	var ok := TestAssert.is_true(
		match_service.ingested_messages.is_empty(),
		"unknown transport peer input should be rejected",
		"server_room_runtime_battle_input_guard_test"
	)
	runtime.free()
	return ok


func _test_rejects_mismatched_control_peer() -> bool:
	var fixture := _create_runtime_fixture()
	var runtime: ServerRoomRuntime = fixture["runtime"]
	var match_service: MockMatchService = fixture["match_service"]

	runtime.handle_battle_message(_input_message(9, 2))

	var ok := TestAssert.is_true(
		match_service.ingested_messages.is_empty(),
		"bound transport should not control another match peer",
		"server_room_runtime_battle_input_guard_test"
	)
	runtime.free()
	return ok


func _test_accepts_bound_control_peer() -> bool:
	var fixture := _create_runtime_fixture()
	var runtime: ServerRoomRuntime = fixture["runtime"]
	var match_service: MockMatchService = fixture["match_service"]

	runtime.handle_battle_message(_input_message(9, 3))

	var ok := TestAssert.is_true(
		match_service.ingested_messages.size() == 1,
		"bound transport should control its original match peer",
		"server_room_runtime_battle_input_guard_test"
	)
	runtime.free()
	return ok


func _test_match_broadcast_targets_connected_bound_transports_only() -> bool:
	var runtime := ServerRoomRuntimeScript.new()
	add_child(runtime)
	runtime.configure("127.0.0.1", 9000)

	var state: RoomServerState = runtime._room_service.room_state
	state.ensure_room("broadcast_room", 2, "private_room", "")
	state.upsert_member(2, "Host", "hero_default")
	state.upsert_member(3, "Client", "hero_default")
	state.freeze_match_peer_bindings("broadcast_match")

	var client_binding := state.get_member_binding_by_transport_peer(3)
	state.mark_member_disconnected_by_transport_peer(3, Time.get_ticks_msec() + 20000, "broadcast_match")
	state.bind_transport_to_member(client_binding.member_id, 9)
	client_binding.match_peer_id = 3
	client_binding.connection_state = "connected"
	state.match_active = true

	var sent_peer_ids: Array[int] = []
	runtime.send_to_peer.connect(func(peer_id: int, _message: Dictionary) -> void:
		sent_peer_ids.append(peer_id)
	)

	runtime._emit_match_broadcast_message({
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
	})

	var ok := TestAssert.is_true(
		sent_peer_ids == [2, 9],
		"match authority broadcast should target connected room bindings, not raw transport peers",
		"server_room_runtime_battle_input_guard_test"
	)
	runtime.free()
	return ok


func _create_runtime_fixture() -> Dictionary:
	var runtime := ServerRoomRuntimeScript.new()
	add_child(runtime)
	runtime.configure("127.0.0.1", 9000)

	var match_service := MockMatchService.new()
	var old_match_service: Node = runtime._match_service
	if old_match_service != null and old_match_service.get_parent() == runtime:
		runtime.remove_child(old_match_service)
		old_match_service.free()
	runtime._match_service = match_service
	runtime.add_child(match_service)

	var state: RoomServerState = runtime._room_service.room_state
	state.ensure_room("guard_room", 2, "private_room", "")
	state.upsert_member(2, "Host", "hero_default")
	state.upsert_member(3, "Client", "hero_default")
	state.freeze_match_peer_bindings("guard_match")
	var binding := state.get_member_binding_by_transport_peer(3)
	state.mark_member_disconnected_by_transport_peer(3, Time.get_ticks_msec() + 20000, "guard_match")
	state.bind_transport_to_member(binding.member_id, 9)
	binding.match_peer_id = 3
	state.match_active = true

	return {
		"runtime": runtime,
		"match_service": match_service,
	}


func _input_message(sender_transport_peer_id: int, frame_peer_id: int) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.INPUT_FRAME,
		"sender_peer_id": sender_transport_peer_id,
		"frame": {
			"peer_id": frame_peer_id,
			"tick_id": 1,
			"move_x": 0,
			"move_y": 0,
			"action_place": false,
		},
	}
