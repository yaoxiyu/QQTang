extends "res://tests/gut/base/qqt_integration_test.gd"

const LoadingUseCaseScript = preload("res://app/front/loading/loading_use_case.gd")
const MatchLoadingSnapshotScript = preload("res://network/session/runtime/match_loading_snapshot.gd")


class MockGateway:
	extends RefCounted
	signal match_loading_snapshot_received(snapshot)
	var ready_calls := []

	func request_match_loading_ready(match_id: String, revision: int) -> void:
		ready_calls.append({"match_id": match_id, "revision": revision})


class MockRuntime:
	extends "res://tests/gut/base/qqt_integration_test.gd"
	var current_start_config = null
	var current_battle_content_manifest: Dictionary = {}
	var current_room_snapshot = null


func test_main() -> void:
	var ok := true
	ok = _test_loading_use_case_submits_ready_once() and ok
	ok = _test_begin_loading_preserves_preconsumed_gateway_snapshot() and ok
	ok = _test_loading_snapshot_preserves_room_context_fields() and ok
	ok = _test_consume_snapshot_committed() and ok
	ok = _test_consume_snapshot_aborted() and ok


func _test_loading_use_case_submits_ready_once() -> bool:
	var use_case := LoadingUseCaseScript.new()
	var gateway := MockGateway.new()
	var runtime := MockRuntime.new()

	use_case.configure(runtime, gateway)
	use_case.begin_loading()

	var snapshot := MatchLoadingSnapshotScript.new()
	snapshot.match_id = "match_001"
	snapshot.revision = 1
	snapshot.phase = "waiting"
	snapshot.expected_peer_ids = [1, 2]
	snapshot.ready_peer_ids = []

	use_case.consume_loading_snapshot(snapshot)
	var result1 := use_case.submit_local_ready()
	if not bool(result1.get("ok", false)):
		print("FAIL: first submit_local_ready should succeed")
		return false
	if result1.get("duplicate", false):
		print("FAIL: first submit should not be duplicate")
		return false
	if gateway.ready_calls.size() != 1:
		print("FAIL: gateway should receive 1 ready call, got ", gateway.ready_calls.size())
		runtime.free()
		return false

	var result2 := use_case.submit_local_ready()
	if not bool(result2.get("ok", false)):
		print("FAIL: second submit_local_ready should also succeed")
		return false
	if not result2.get("duplicate", false):
		print("FAIL: second submit should be duplicate")
		return false
	if gateway.ready_calls.size() != 1:
		print("FAIL: gateway should still have only 1 ready call after duplicate, got ", gateway.ready_calls.size())
		runtime.free()
		return false
	runtime.free()
	return true


func _test_begin_loading_preserves_preconsumed_gateway_snapshot() -> bool:
	var use_case := LoadingUseCaseScript.new()
	var gateway := MockGateway.new()
	var runtime := MockRuntime.new()

	use_case.configure(runtime, gateway)

	var snapshot := MatchLoadingSnapshotScript.new()
	snapshot.match_id = "match_preconsumed"
	snapshot.revision = 9
	snapshot.phase = "waiting"
	snapshot.expected_peer_ids = [11, 22]
	snapshot.ready_peer_ids = []

	use_case.consume_loading_snapshot(snapshot)
	use_case.begin_loading()

	var result := use_case.submit_local_ready()
	if not bool(result.get("ok", false)):
		print("FAIL: submit_local_ready should use preconsumed gateway snapshot")
		runtime.free()
		return false
	if gateway.ready_calls.size() != 1:
		print("FAIL: gateway should receive ready from preserved snapshot, got ", gateway.ready_calls.size())
		runtime.free()
		return false
	var call: Dictionary = gateway.ready_calls[0]
	if String(call.get("match_id", "")) != "match_preconsumed" or int(call.get("revision", 0)) != 9:
		print("FAIL: preserved snapshot match/revision mismatch")
		runtime.free()
		return false
	runtime.free()
	return true


func _test_loading_snapshot_preserves_room_context_fields() -> bool:
	var snapshot := MatchLoadingSnapshotScript.new()
	snapshot.room_id = "ROOM-LOADING"
	snapshot.room_kind = "ranked_match_room"
	snapshot.match_id = "match_ctx"
	snapshot.phase = "waiting"
	snapshot.expected_peer_ids = [1, 2]
	snapshot.ready_peer_ids = [1]
	var as_dict := snapshot.to_dict()
	var restored := MatchLoadingSnapshotScript.from_dict(as_dict)

	if restored.room_id != "ROOM-LOADING" or restored.room_kind != "ranked_match_room":
		print("FAIL: loading snapshot should preserve room canonical context fields")
		return false
	if restored.match_id != "match_ctx":
		print("FAIL: loading snapshot should preserve match_id")
		return false
	if restored.waiting_peer_ids != [2]:
		print("FAIL: waiting peers should be recalculated from expected-ready set")
		return false
	return true


func _test_consume_snapshot_committed() -> bool:
	var use_case := LoadingUseCaseScript.new()
	var runtime := MockRuntime.new()
	use_case.configure(runtime, MockGateway.new())
	use_case.begin_loading()

	var snapshot := MatchLoadingSnapshotScript.new()
	snapshot.phase = "committed"

	var result := use_case.consume_loading_snapshot(snapshot)
	if not bool(result.get("ok", false)):
		print("FAIL: consume committed should succeed")
		runtime.free()
		return false
	if not result.get("committed", false):
		print("FAIL: consume committed should return committed=true")
		runtime.free()
		return false
	runtime.free()
	return true


func _test_consume_snapshot_aborted() -> bool:
	var use_case := LoadingUseCaseScript.new()
	var runtime := MockRuntime.new()
	use_case.configure(runtime, MockGateway.new())
	use_case.begin_loading()

	var snapshot := MatchLoadingSnapshotScript.new()
	snapshot.phase = "aborted"
	snapshot.error_code = "peer_disconnected"
	snapshot.user_message = "Player left during loading"

	var result := use_case.consume_loading_snapshot(snapshot)
	if not bool(result.get("ok", false)):
		print("FAIL: consume aborted should succeed")
		runtime.free()
		return false
	if not result.get("aborted", false):
		print("FAIL: consume aborted should return aborted=true")
		runtime.free()
		return false
	if result.get("error_code") != "peer_disconnected":
		print("FAIL: consume aborted error_code mismatch")
		runtime.free()
		return false
	if result.get("user_message") != "Player left during loading":
		print("FAIL: consume aborted user_message mismatch")
		runtime.free()
		return false
	runtime.free()
	return true
