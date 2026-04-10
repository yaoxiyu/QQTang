extends Node

const LoadingUseCaseScript = preload("res://app/front/loading/loading_use_case.gd")
const MatchLoadingSnapshotScript = preload("res://network/session/runtime/match_loading_snapshot.gd")


class MockGateway:
	extends RefCounted
	signal match_loading_snapshot_received(snapshot)
	var ready_calls := []

	func request_match_loading_ready(match_id: String, revision: int) -> void:
		ready_calls.append({"match_id": match_id, "revision": revision})


class MockRuntime:
	extends Node
	var current_start_config = null
	var current_battle_content_manifest: Dictionary = {}
	var current_room_snapshot = null


func _ready() -> void:
	var ok := true
	ok = _test_loading_use_case_submits_ready_once() and ok
	ok = _test_consume_snapshot_committed() and ok
	ok = _test_consume_snapshot_aborted() and ok
	if ok:
		print("online_loading_barrier_waits_for_commit_test: PASS")


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
