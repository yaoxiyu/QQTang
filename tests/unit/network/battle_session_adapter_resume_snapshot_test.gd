extends Node

const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const ClientRuntimeScript = preload("res://network/session/runtime/client_runtime.gd")
const MatchResumeSnapshotScript = preload("res://network/session/runtime/match_resume_snapshot.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


class MockClientRuntime:
	extends ClientRuntimeScript

	var active: bool = false
	var injected_messages: Array[Dictionary] = []

	func is_active() -> bool:
		return active

	func inject_resume_checkpoint_message(message: Dictionary) -> void:
		injected_messages.append(message.duplicate(true))


func _ready() -> void:
	var ok := true
	ok = _test_apply_resume_snapshot_pending_before_runtime_active() and ok
	ok = _test_apply_resume_snapshot_injects_immediately_when_runtime_active() and ok
	if ok:
		print("battle_session_adapter_resume_snapshot_test: PASS")


func _test_apply_resume_snapshot_pending_before_runtime_active() -> bool:
	var adapter := BattleSessionAdapterScript.new()
	var runtime := MockClientRuntime.new()
	add_child(adapter)
	adapter.add_child(runtime)
	adapter._bootstrap_client_runtime = runtime

	var snapshot := _build_resume_snapshot(44)
	adapter.apply_resume_snapshot(snapshot)

	var prefix := "battle_session_adapter_resume_snapshot_test"
	var ok := true
	ok = TestAssert.is_true(runtime.injected_messages.is_empty(), "inactive runtime should not inject immediately", prefix) and ok
	ok = TestAssert.is_true(adapter.pending_resume_snapshot == snapshot, "inactive runtime should keep pending resume snapshot", prefix) and ok

	adapter.free()
	return ok


func _test_apply_resume_snapshot_injects_immediately_when_runtime_active() -> bool:
	var adapter := BattleSessionAdapterScript.new()
	var runtime := MockClientRuntime.new()
	runtime.active = true
	add_child(adapter)
	adapter.add_child(runtime)
	adapter._bootstrap_client_runtime = runtime

	var snapshot := _build_resume_snapshot(88)
	adapter.apply_resume_snapshot(snapshot)

	var prefix := "battle_session_adapter_resume_snapshot_test"
	var ok := true
	ok = TestAssert.is_true(runtime.injected_messages.size() == 1, "active runtime should inject resume checkpoint immediately", prefix) and ok
	if runtime.injected_messages.size() == 1:
		ok = TestAssert.is_true(int(runtime.injected_messages[0].get("tick", 0)) == 88, "injected checkpoint should match resume snapshot", prefix) and ok
	ok = TestAssert.is_true(adapter.pending_resume_snapshot == null, "injected resume snapshot should be cleared", prefix) and ok

	adapter.free()
	return ok


func _build_resume_snapshot(tick: int) -> MatchResumeSnapshot:
	var snapshot := MatchResumeSnapshotScript.new()
	snapshot.checkpoint_message = {
		"message_type": "CHECKPOINT",
		"tick": tick,
		"players": [],
		"bubbles": [],
		"items": [],
		"walls": [],
		"mode_state": {},
		"rng_state": 1,
		"checksum": 2,
	}
	return snapshot
