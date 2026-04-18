extends "res://tests/gut/base/qqt_unit_test.gd"

const MatchResumeSnapshotScript = preload("res://network/session/runtime/match_resume_snapshot.gd")


func test_main() -> void:
	var ok := true
	ok = _test_round_trip_preserves_checkpoint_payload() and ok


func _test_round_trip_preserves_checkpoint_payload() -> bool:
	var snapshot := MatchResumeSnapshotScript.new()
	snapshot.room_id = "room_a"
	snapshot.room_kind = "public_room"
	snapshot.room_display_name = "Arena"
	snapshot.match_id = "match_a"
	snapshot.server_match_revision = 3
	snapshot.member_id = "member_1"
	snapshot.controlled_peer_id = 2
	snapshot.transport_peer_id = 9
	snapshot.resume_phase = "resuming"
	snapshot.resume_tick = 77
	snapshot.checkpoint_message = {
		"message_type": "CHECKPOINT",
		"tick": 77,
		"players": [{"peer_id": 2, "cell_x": 4}],
		"mode_state": {"mode_runtime_type": "default"},
	}
	snapshot.player_summary = [{"peer_id": 2, "player_slot": 1}]
	snapshot.status_message = "Resuming active match"

	var restored := MatchResumeSnapshotScript.from_dict(snapshot.to_dict())
	if restored.match_id != snapshot.match_id:
		print("FAIL: match_id mismatch")
		return false
	if restored.controlled_peer_id != 2 or restored.transport_peer_id != 9:
		print("FAIL: peer identity mismatch")
		return false
	if int(restored.checkpoint_message.get("tick", 0)) != 77:
		print("FAIL: checkpoint tick mismatch")
		return false
	var players: Array = restored.checkpoint_message.get("players", [])
	if players.size() != 1 or int(players[0].get("cell_x", 0)) != 4:
		print("FAIL: nested checkpoint payload mismatch")
		return false
	if restored.player_summary.size() != 1:
		print("FAIL: player_summary mismatch")
		return false
	return true

