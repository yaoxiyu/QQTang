extends "res://tests/gut/base/qqt_unit_test.gd"

const ServerMatchLoadingCoordinatorScript = preload("res://network/session/runtime/server_match_loading_coordinator.gd")
const MatchLoadingSnapshotScript = preload("res://network/session/runtime/match_loading_snapshot.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


class MockRoomSnapshot:
	extends RefCounted
	var room_id: String = "test_room"
	var room_kind: String = "private_room"
	var room_display_name: String = "Test Room"
	var owner_peer_id: int = 1
	var members: Array = []
	var selected_map_id: String = "map_001"
	var selected_rule_id: String = "rule_001"
	var selected_mode_id: String = "mode_001"
	var min_start_players: int = 2
	var match_active: bool = false


class MockConfig:
	extends RefCounted
	var match_id: String = "match_001"
	var server_match_revision: int = 1
	var battle_seed: int = 42
	var player_slots: Array = []

	func duplicate_deep():
		var copy := MockConfig.new()
		copy.match_id = match_id
		copy.server_match_revision = server_match_revision
		copy.battle_seed = battle_seed
		copy.player_slots = player_slots.duplicate()
		return copy


func test_main() -> void:
	var ok := true
	ok = _test_begin_loading_success() and ok
	ok = _test_ready_not_committed_before_all_ready() and ok
	ok = _test_ready_committed_when_all_ready() and ok
	ok = _test_peer_disconnect_aborts_loading() and ok
	ok = _test_revision_mismatch_rejected() and ok


func _test_begin_loading_success() -> bool:
	var coord := ServerMatchLoadingCoordinatorScript.new()
	var sent_to_peers := []
	var broadcasted := []

	var mock_snapshot := MockRoomSnapshot.new()
	var mock_config := MockConfig.new()
	mock_config.player_slots = [{"peer_id": 1}, {"peer_id": 2}]

	coord.configure(
		Callable(self, "_mock_prepare_match").bind(mock_config),
		Callable(self, "_mock_commit_match"),
		func(peer_id, msg): sent_to_peers.append({"peer_id": peer_id, "msg": msg}),
		func(msg): broadcasted.append(msg)
	)

	var result := coord.begin_loading(mock_snapshot)
	if not bool(result.get("ok", false)):
		print("FAIL: begin_loading should succeed")
		return false
	if sent_to_peers.size() != 2:
		print("FAIL: begin_loading should send to 2 peers, got ", sent_to_peers.size())
		return false
	if broadcasted.size() != 1:
		print("FAIL: begin_loading should broadcast 1 snapshot, got ", broadcasted.size())
		return false
	if broadcasted[0]["message_type"] != TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT:
		print("FAIL: begin_loading broadcast should be MATCH_LOADING_SNAPSHOT")
		return false
	if not coord.is_loading_active():
		print("FAIL: begin_loading should set loading_active to true")
		return false
	return true


func _test_ready_not_committed_before_all_ready() -> bool:
	var coord := ServerMatchLoadingCoordinatorScript.new()
	var broadcasted := []
	var mock_snapshot := MockRoomSnapshot.new()
	var mock_config := MockConfig.new()
	mock_config.player_slots = [{"peer_id": 1}, {"peer_id": 2}]

	coord.configure(
		Callable(self, "_mock_prepare_match").bind(mock_config),
		Callable(self, "_mock_commit_match"),
		func(_peer_id, _msg): pass,
		func(msg): broadcasted.append(msg)
	)

	coord.begin_loading(mock_snapshot)
	var result := coord.mark_peer_ready(1, "match_001", 1)
	if not bool(result.get("ok", false)):
		print("FAIL: mark_peer_ready should succeed")
		return false
	if result.get("committed", false):
		print("FAIL: should not be committed before all peers ready")
		return false
	if broadcasted.size() != 2:
		print("FAIL: should have 2 broadcasts (initial + ready update)")
		return false
	return true


func _test_ready_committed_when_all_ready() -> bool:
	var coord := ServerMatchLoadingCoordinatorScript.new()
	var committed := [false]
	var broadcasted := []
	var mock_snapshot := MockRoomSnapshot.new()
	var mock_config := MockConfig.new()
	mock_config.player_slots = [{"peer_id": 1}, {"peer_id": 2}]

	coord.configure(
		Callable(self, "_mock_prepare_match").bind(mock_config),
		func(_cfg): committed[0] = true; return {"ok": true},
		func(_peer_id, _msg): pass,
		func(msg): broadcasted.append(msg)
	)

	coord.begin_loading(mock_snapshot)
	coord.mark_peer_ready(1, "match_001", 1)
	var result := coord.mark_peer_ready(2, "match_001", 1)

	if not bool(result.get("ok", false)):
		print("FAIL: mark_peer_ready for last peer should succeed")
		return false
	if not result.get("committed", false):
		print("FAIL: should be committed when all peers ready")
		return false
	if not committed[0]:
		print("FAIL: commit callable should have been called")
		return false
	if broadcasted.size() != 3:
		print("FAIL: should have 3 broadcasts (initial + 2 ready updates, last is committed)")
		return false
	return true


func _test_peer_disconnect_aborts_loading() -> bool:
	var coord := ServerMatchLoadingCoordinatorScript.new()
	var broadcasted := []
	var mock_snapshot := MockRoomSnapshot.new()
	var mock_config := MockConfig.new()
	mock_config.player_slots = [{"peer_id": 1}, {"peer_id": 2}]

	coord.configure(
		Callable(self, "_mock_prepare_match").bind(mock_config),
		func(_cfg): return {"ok": true},
		func(_peer_id, _msg): pass,
		func(msg): broadcasted.append(msg)
	)

	coord.begin_loading(mock_snapshot)
	coord.handle_peer_disconnected(1)

	if coord.is_loading_active():
		print("FAIL: loading should be aborted after peer disconnect")
		return false
	if broadcasted.size() != 2:
		print("FAIL: should have 2 broadcasts (initial + abort)")
		return false
	var abort_msg = broadcasted[1]
	if abort_msg["snapshot"]["phase"] != "aborted":
		print("FAIL: abort broadcast phase should be aborted")
		return false
	return true


func _test_revision_mismatch_rejected() -> bool:
	var coord := ServerMatchLoadingCoordinatorScript.new()
	var mock_snapshot := MockRoomSnapshot.new()
	var mock_config := MockConfig.new()
	mock_config.player_slots = [{"peer_id": 1}, {"peer_id": 2}]
	mock_config.server_match_revision = 1

	coord.configure(
		Callable(self, "_mock_prepare_match").bind(mock_config),
		func(_cfg): return {"ok": true},
		func(_peer_id, _msg): pass,
		func(_msg): pass
	)

	coord.begin_loading(mock_snapshot)
	var result := coord.mark_peer_ready(1, "match_001", 999)

	if bool(result.get("ok", false)):
		print("FAIL: revision mismatch should be rejected")
		return false
	if result.get("error") != "revision_mismatch":
		print("FAIL: error should be revision_mismatch")
		return false
	return true


func _mock_prepare_match(_snapshot, config) -> Dictionary:
	return {
		"ok": true,
		"config": config,
		"validation": {"ok": true},
	}


func _mock_commit_match(_config) -> Dictionary:
	return {"ok": true}

