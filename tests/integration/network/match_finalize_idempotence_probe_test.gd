extends Node

const ServerMatchFinalizeReporterScript = preload("res://network/session/runtime/server_match_finalize_reporter.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


func _ready() -> void:
	var reporter = ServerMatchFinalizeReporterScript.new()
	var payload := {
		"match_id": "match_probe",
		"assignment_id": "assign_probe",
		"room_id": "room_probe",
		"room_kind": "matchmade_room",
		"season_id": "season_s1",
		"mode_id": "mode_ranked",
		"rule_set_id": "rule_standard",
		"map_id": "map_arcade",
		"started_at": null,
		"finished_at": "2026-04-13T10:00:00Z",
		"finish_reason": "last_survivor",
		"score_policy": "team_score",
		"winner_team_ids": [1],
		"winner_peer_ids": [],
		"member_results": [
			{"account_id": "account_a", "profile_id": "profile_a", "team_id": 1, "peer_id": 1, "outcome": "win", "player_score": 5, "team_score": 10, "placement": 1},
			{"account_id": "account_b", "profile_id": "profile_b", "team_id": 2, "peer_id": 2, "outcome": "loss", "player_score": 1, "team_score": 4, "placement": 2},
		],
	}

	var hash_first := reporter._build_result_hash(payload)
	var hash_second := reporter._build_result_hash(payload)
	var ok := TestAssert.is_true(hash_first == hash_second and hash_first.begins_with("sha256:"), "duplicate finalize payload should keep same result hash", "match_finalize_idempotence_probe_test")
	if ok:
		print("match_finalize_idempotence_probe_test: PASS")
