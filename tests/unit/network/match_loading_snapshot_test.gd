extends "res://tests/gut/base/qqt_unit_test.gd"

const MatchLoadingSnapshotScript = preload("res://network/session/runtime/match_loading_snapshot.gd")


func test_main() -> void:
	var ok := true
	ok = _test_to_dict_from_dict_round_trip() and ok
	ok = _test_from_dict_tolerates_missing_fields() and ok
	ok = _test_duplicate_deep_is_independent() and ok
	ok = _test_is_committed() and ok
	ok = _test_is_aborted() and ok


func _test_to_dict_from_dict_round_trip() -> bool:
	var snapshot := MatchLoadingSnapshotScript.new()
	snapshot.room_id = "room_001"
	snapshot.room_kind = "public_room"
	snapshot.room_display_name = "Test Room"
	snapshot.match_id = "match_abc"
	snapshot.revision = 5
	snapshot.phase = "waiting"
	snapshot.owner_peer_id = 100
	snapshot.expected_peer_ids = [100, 101, 102]
	snapshot.ready_peer_ids = [100]
	snapshot.battle_seed = 42

	var dict := snapshot.to_dict()
	if dict["room_id"] != "room_001":
		print("FAIL: to_dict room_id mismatch")
		return false
	if dict["room_kind"] != "public_room":
		print("FAIL: to_dict room_kind mismatch")
		return false
	if dict["match_id"] != "match_abc":
		print("FAIL: to_dict match_id mismatch")
		return false
	if dict["revision"] != 5:
		print("FAIL: to_dict revision mismatch")
		return false
	if dict["phase"] != "waiting":
		print("FAIL: to_dict phase mismatch")
		return false
	if dict["owner_peer_id"] != 100:
		print("FAIL: to_dict owner_peer_id mismatch")
		return false

	var restored := MatchLoadingSnapshotScript.from_dict(dict)
	if restored.room_id != snapshot.room_id:
		print("FAIL: from_dict room_id mismatch")
		return false
	if restored.room_kind != snapshot.room_kind:
		print("FAIL: from_dict room_kind mismatch")
		return false
	if restored.match_id != snapshot.match_id:
		print("FAIL: from_dict match_id mismatch")
		return false
	if restored.revision != snapshot.revision:
		print("FAIL: from_dict revision mismatch")
		return false
	if restored.phase != snapshot.phase:
		print("FAIL: from_dict phase mismatch")
		return false
	if restored.expected_peer_ids != snapshot.expected_peer_ids:
		print("FAIL: from_dict expected_peer_ids mismatch")
		return false
	if restored.ready_peer_ids != snapshot.ready_peer_ids:
		print("FAIL: from_dict ready_peer_ids mismatch")
		return false
	return true


func _test_from_dict_tolerates_missing_fields() -> bool:
	var partial_dict := {
		"room_id": "room_002",
		"phase": "committed",
	}
	var snapshot := MatchLoadingSnapshotScript.from_dict(partial_dict)
	if snapshot.room_id != "room_002":
		print("FAIL: from_dict partial room_id mismatch")
		return false
	if snapshot.phase != "committed":
		print("FAIL: from_dict partial phase mismatch")
		return false
	if snapshot.room_kind != "":
		print("FAIL: from_dict partial room_kind should be empty")
		return false
	if snapshot.revision != 0:
		print("FAIL: from_dict partial revision should be 0")
		return false
	return true


func _test_duplicate_deep_is_independent() -> bool:
	var snapshot := MatchLoadingSnapshotScript.new()
	snapshot.room_id = "room_003"
	snapshot.expected_peer_ids = [1, 2, 3]
	snapshot.ready_peer_ids = [1]

	var copy := snapshot.duplicate_deep()
	copy.room_id = "room_004"
	copy.expected_peer_ids.append(4)

	if snapshot.room_id != "room_003":
		print("FAIL: duplicate_deep mutated original room_id")
		return false
	if snapshot.expected_peer_ids.size() != 3:
		print("FAIL: duplicate_deep mutated original expected_peer_ids")
		return false
	if copy.room_id != "room_004":
		print("FAIL: duplicate_deep copy room_id mismatch")
		return false
	if copy.expected_peer_ids.size() != 4:
		print("FAIL: duplicate_deep copy expected_peer_ids size mismatch")
		return false
	return true


func _test_is_committed() -> bool:
	var waiting := MatchLoadingSnapshotScript.new()
	waiting.phase = "waiting"
	if waiting.is_committed():
		print("FAIL: waiting should not be committed")
		return false

	var committed := MatchLoadingSnapshotScript.new()
	committed.phase = "committed"
	if not committed.is_committed():
		print("FAIL: committed should be committed")
		return false
	return true


func _test_is_aborted() -> bool:
	var waiting := MatchLoadingSnapshotScript.new()
	waiting.phase = "waiting"
	if waiting.is_aborted():
		print("FAIL: waiting should not be aborted")
		return false

	var aborted := MatchLoadingSnapshotScript.new()
	aborted.phase = "aborted"
	aborted.error_code = "peer_disconnected"
	aborted.user_message = "Player left"
	if not aborted.is_aborted():
		print("FAIL: aborted should be aborted")
		return false
	if aborted.error_code != "peer_disconnected":
		print("FAIL: aborted error_code mismatch")
		return false
	return true

