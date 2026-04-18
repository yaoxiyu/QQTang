extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const ServerMatchResumeCoordinatorScript = preload("res://network/session/runtime/server_match_resume_coordinator.gd")
const ServerMatchServiceScript = preload("res://network/session/runtime/server_match_service.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


class MockMatchService:
	extends ServerMatchService

	var active: bool = true
	var config: BattleStartConfig = null
	var checkpoint: Dictionary = {}

	func test_main() -> void:
		pass

	func is_match_active() -> bool:
		return active

	func get_current_config() -> BattleStartConfig:
		return config.duplicate_deep() if config != null else null

	func build_resume_checkpoint_message() -> Dictionary:
		return checkpoint.duplicate(true)


func test_main() -> void:
	var ok := true
	ok = _test_member_disconnect_creates_resume_window() and ok
	ok = _test_member_disconnect_skips_when_match_inactive() and ok
	ok = _test_try_resume_success_sends_candidate_config() and ok
	ok = _test_try_resume_rejects_invalid_token() and ok
	ok = _test_try_resume_rejects_expired_window() and ok
	ok = _test_try_resume_rejects_member_not_found() and ok
	ok = _test_try_resume_rejects_match_not_active() and ok
	ok = _test_poll_expired_triggers_abort() and ok
	ok = _test_poll_expired_skips_active_window() and ok
	ok = _test_match_committed_freezes_and_clears_resume_state() and ok


func _test_member_disconnect_creates_resume_window() -> bool:
	var fixture := _create_fixture()
	var state: RoomServerState = fixture["state"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var binding := state.get_member_binding_by_transport_peer(2)

	coordinator.on_member_disconnected(binding.member_id)

	var prefix := "server_match_resume_coordinator_test"
	var ok := true
	ok = qqt_check(binding.disconnect_deadline_msec > Time.get_ticks_msec(), "disconnect should open a future resume window", prefix) and ok
	ok = qqt_check(binding.connection_state == "disconnected", "binding should become disconnected", prefix) and ok
	ok = qqt_check(binding.transport_peer_id == 0, "transport mapping should be cleared while disconnected", prefix) and ok
	ok = qqt_check(binding.match_peer_id == 2, "match peer id should remain stable", prefix) and ok
	return ok


func _test_member_disconnect_skips_when_match_inactive() -> bool:
	var fixture := _create_fixture()
	var service: MockMatchService = fixture["service"]
	var state: RoomServerState = fixture["state"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var binding := state.get_member_binding_by_transport_peer(2)
	service.active = false

	coordinator.on_member_disconnected(binding.member_id)

	return qqt_check(
		binding.disconnect_deadline_msec == 0 and binding.connection_state == "connected",
		"inactive match should not open a resume window",
		"server_match_resume_coordinator_test"
	)


func _test_try_resume_success_sends_candidate_config() -> bool:
	var fixture := _create_fixture()
	var state: RoomServerState = fixture["state"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var binding := state.get_member_binding_by_transport_peer(2)
	var member_id := binding.member_id
	var token := binding.reconnect_token
	var sent_messages := []
	coordinator.send_to_peer.connect(func(peer_id: int, message: Dictionary): sent_messages.append({"peer_id": peer_id, "message": message}))
	coordinator.on_member_disconnected(member_id)

	var result := coordinator.try_resume(member_id, token, 9, "match_456")

	var prefix := "server_match_resume_coordinator_test"
	var ok := true
	ok = qqt_check(bool(result.get("ok", false)), "valid resume request should succeed", prefix) and ok
	ok = qqt_check(sent_messages.size() == 1, "resume should send one accept message", prefix) and ok
	ok = qqt_check(state.get_member_binding_by_transport_peer(9) == binding, "new transport should bind to original member", prefix) and ok
	ok = qqt_check(binding.match_peer_id == 2, "controlled match peer should stay original", prefix) and ok
	ok = qqt_check(binding.transport_peer_id == 9, "transport peer should update to reconnect peer", prefix) and ok
	ok = qqt_check(binding.connection_state == "connected", "binding should be connected after resume", prefix) and ok
	if sent_messages.size() == 1:
		var message: Dictionary = sent_messages[0]["message"]
		var start_config: Dictionary = message.get("start_config", {})
		var resume_snapshot: Dictionary = message.get("resume_snapshot", {})
		ok = qqt_check(int(sent_messages[0]["peer_id"]) == 9, "accept should be sent to reconnect transport", prefix) and ok
		ok = qqt_check(message.get("message_type", "") == TransportMessageTypesScript.MATCH_RESUME_ACCEPTED, "message should be MATCH_RESUME_ACCEPTED", prefix) and ok
		ok = qqt_check(int(start_config.get("local_peer_id", 0)) == 9, "candidate config local peer should be reconnect transport", prefix) and ok
		ok = qqt_check(int(start_config.get("controlled_peer_id", 0)) == 2, "candidate config controlled peer should be original match peer", prefix) and ok
		ok = qqt_check(int(resume_snapshot.get("transport_peer_id", 0)) == 9, "resume snapshot transport peer should be reconnect transport", prefix) and ok
		ok = qqt_check(int(resume_snapshot.get("controlled_peer_id", 0)) == 2, "resume snapshot controlled peer should be original match peer", prefix) and ok
		ok = qqt_check(int(resume_snapshot.get("resume_tick", 0)) == 100, "resume snapshot should carry checkpoint tick", prefix) and ok
	return ok


func _test_try_resume_rejects_invalid_token() -> bool:
	var fixture := _create_fixture()
	var state: RoomServerState = fixture["state"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var binding := state.get_member_binding_by_transport_peer(2)
	coordinator.on_member_disconnected(binding.member_id)

	var result := coordinator.try_resume(binding.member_id, "wrong_token", 9, "match_456")

	return _expect_error(result, "TOKEN_INVALID")


func _test_try_resume_rejects_expired_window() -> bool:
	var fixture := _create_fixture()
	var state: RoomServerState = fixture["state"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var binding := state.get_member_binding_by_transport_peer(2)
	state.mark_member_disconnected_by_transport_peer(2, 1, "match_456")

	var result := coordinator.try_resume(binding.member_id, binding.reconnect_token, 9, "match_456")

	return _expect_error(result, "RESUME_WINDOW_EXPIRED")


func _test_try_resume_rejects_member_not_found() -> bool:
	var fixture := _create_fixture()
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]

	var result := coordinator.try_resume("missing_member", "token", 9, "match_456")

	return _expect_error(result, "MEMBER_NOT_FOUND")


func _test_try_resume_rejects_match_not_active() -> bool:
	var fixture := _create_fixture()
	var service: MockMatchService = fixture["service"]
	var state: RoomServerState = fixture["state"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var binding := state.get_member_binding_by_transport_peer(2)
	coordinator.on_member_disconnected(binding.member_id)
	service.active = false

	var result := coordinator.try_resume(binding.member_id, binding.reconnect_token, 9, "match_456")

	return _expect_error(result, "MATCH_NOT_ACTIVE")


func _test_poll_expired_triggers_abort() -> bool:
	var fixture := _create_fixture()
	var state: RoomServerState = fixture["state"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var binding := state.get_member_binding_by_transport_peer(2)
	var aborts := []
	state.mark_member_disconnected_by_transport_peer(2, 1, "match_456")
	coordinator.match_abort_requested.connect(func(reason: String, member_id: String): aborts.append({"reason": reason, "member_id": member_id}))

	coordinator.poll_expired()

	var prefix := "server_match_resume_coordinator_test"
	var ok := true
	ok = qqt_check(aborts.size() == 1, "expired resume window should request abort", prefix) and ok
	if aborts.size() == 1:
		ok = qqt_check(aborts[0]["reason"] == "peer_resume_timeout", "abort reason should be peer_resume_timeout", prefix) and ok
		ok = qqt_check(aborts[0]["member_id"] == binding.member_id, "abort member id should match binding", prefix) and ok
	return ok


func _test_poll_expired_skips_active_window() -> bool:
	var fixture := _create_fixture()
	var state: RoomServerState = fixture["state"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var aborts := []
	state.mark_member_disconnected_by_transport_peer(2, Time.get_ticks_msec() + 20000, "match_456")
	coordinator.match_abort_requested.connect(func(reason: String, member_id: String): aborts.append({"reason": reason, "member_id": member_id}))

	coordinator.poll_expired()

	return qqt_check(aborts.is_empty(), "active resume window should not request abort", "server_match_resume_coordinator_test")


func _test_match_committed_freezes_and_clears_resume_state() -> bool:
	var fixture := _create_fixture()
	var state: RoomServerState = fixture["state"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var binding := state.get_member_binding_by_transport_peer(2)
	state.mark_member_disconnected_by_transport_peer(2, Time.get_ticks_msec() + 20000, "old_match")

	coordinator.on_match_committed(_build_config("match_789"))

	var prefix := "server_match_resume_coordinator_test"
	var ok := true
	ok = qqt_check(binding.disconnect_deadline_msec == 0, "commit should clear stale resume deadline", prefix) and ok
	ok = qqt_check(binding.last_match_id == "", "commit should clear stale match id", prefix) and ok
	return ok


func _expect_error(result: Dictionary, expected_error: String) -> bool:
	var prefix := "server_match_resume_coordinator_test"
	var ok := true
	ok = qqt_check(not bool(result.get("ok", true)), "result should fail with %s" % expected_error, prefix) and ok
	ok = qqt_check(String(result.get("error", "")) == expected_error, "error should be %s" % expected_error, prefix) and ok
	return ok


func _create_fixture() -> Dictionary:
	var state := RoomServerStateScript.new()
	state.ensure_room("room_123", 2, "private_room", "Test Room")
	state.upsert_member(2, "Player2", "hero_default")
	state.upsert_member(3, "Player3", "hero_default")
	state.freeze_match_peer_bindings("match_456")
	state.match_active = true

	var service := MockMatchService.new()
	service.active = true
	service.config = _build_config("match_456")
	service.checkpoint = _build_checkpoint()
	add_child(service)

	var coordinator := ServerMatchResumeCoordinatorScript.new()
	coordinator.configure(state, service)
	add_child(coordinator)
	return {
		"state": state,
		"service": service,
		"coordinator": coordinator,
	}


func _build_config(match_id: String) -> BattleStartConfig:
	var config := BattleStartConfigScript.new()
	config.build_mode = BattleStartConfigScript.BUILD_MODE_CANONICAL
	config.room_id = "room_123"
	config.match_id = match_id
	config.map_id = "map_001"
	config.map_content_hash = "test_hash"
	config.mode_id = "mode_001"
	config.rule_set_id = "rule_001"
	config.player_slots = [
		{"peer_id": 2, "slot_index": 0, "player_name": "Player2", "character_id": "hero_default"},
		{"peer_id": 3, "slot_index": 1, "player_name": "Player3", "character_id": "hero_default"},
	]
	config.spawn_assignments = [
		{"peer_id": 2, "slot_index": 0, "cell": Vector2i(1, 1)},
		{"peer_id": 3, "slot_index": 1, "cell": Vector2i(3, 3)},
	]
	config.session_mode = "network_dedicated_server"
	config.topology = "dedicated_server"
	config.owner_peer_id = 2
	config.server_match_revision = 42
	return config


func _build_checkpoint() -> Dictionary:
	return {
		"message_type": "CHECKPOINT",
		"tick": 100,
		"players": [],
		"player_summary": [],
		"bubbles": [],
		"items": [],
		"walls": [],
		"mode_state": {},
		"rng_state": 12345,
		"checksum": 999,
	}

