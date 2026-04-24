extends "res://tests/gut/base/qqt_unit_test.gd"

const MatchmakingUseCaseScript = preload("res://app/front/matchmaking/matchmaking_use_case.gd")


func test_summarize_matchmaking_payload_replaces_selected_maps_with_count() -> void:
	var use_case := MatchmakingUseCaseScript.new()

	var summary: Dictionary = use_case._summarize_matchmaking_log_payload("enter_queue_requested", {
		"queue_type": "ranked",
		"match_format_id": "2v2",
		"mode_id": "mode_ranked",
		"rule_set_id": "rule_standard",
		"selected_map_ids": ["map_a", "map_b", "map_c"],
		"unexpected_payload": {"large": true},
	})

	assert_eq(String(summary.get("queue_type", "")), "ranked", "summary should keep queue type")
	assert_eq(int(summary.get("selected_map_count", 0)), 3, "summary should keep selected map count")
	assert_false(summary.has("selected_map_ids"), "summary should not include selected map id array")
	assert_false(summary.has("unexpected_payload"), "summary should drop unlisted raw payload fields")


func test_matchmaking_poll_logs_are_sampled() -> void:
	var use_case := MatchmakingUseCaseScript.new()

	assert_eq(use_case._matchmaking_log_sample_every("poll_queue_status_succeeded"), 10, "poll success should be sampled")
	assert_eq(use_case._matchmaking_log_sample_every("poll_queue_status_failed"), 3, "poll failure should be sampled less aggressively")
	assert_eq(use_case._matchmaking_log_sample_every("enter_queue_requested"), 1, "one-shot events should log every time")
