extends "res://tests/gut/base/qqt_unit_test.gd"

const ServerMatchFinalizeReporterScript = preload("res://network/session/runtime/server_match_finalize_reporter.gd")
const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const BattleResultScript = preload("res://gameplay/battle/runtime/battle_result.gd")


class FakeMatchService:
	extends RefCounted

	var config: BattleStartConfig = null
	var match_id: String = ""
	var room_id: String = ""

	func _init(p_config: BattleStartConfig, p_match_id: String, p_room_id: String) -> void:
		config = p_config
		match_id = p_match_id
		room_id = p_room_id

	func get_last_finished_config() -> BattleStartConfig:
		return config

	func get_last_finished_match_id() -> String:
		return match_id

	func get_last_finished_room_id() -> String:
		return room_id


class FakeRoomRuntime:
	extends "res://tests/gut/base/qqt_unit_test.gd"

	var state = null
	var match_service = null

	func _init(p_state, p_match_service) -> void:
		state = p_state
		match_service = p_match_service

	func get_room_state():
		return state

	func get_match_service():
		return match_service


func test_finalize_payload_contains_member_results() -> void:
	var reporter = ServerMatchFinalizeReporterScript.new()
	var state = RoomServerStateScript.new()
	state.ensure_room("room_alpha", 1, "casual_match_room", "")
	state.assignment_id = "assign_alpha"
	state.season_id = "season_s1"
	state.upsert_member(1, "Alpha", "", "", 1, "account_a", "profile_a")
	state.upsert_member(2, "Beta", "", "", 2, "account_b", "profile_b")

	var config = BattleStartConfigScript.new()
	config.match_id = "match_alpha"
	config.room_id = "room_alpha"
	config.battle_id = "battle_alpha"
	config.mode_id = "mode_ranked"
	config.rule_set_id = "rule_standard"
	config.map_id = state.selected_map_id

	var result = BattleResultScript.new()
	result.finish_reason = "last_survivor"
	result.score_policy = "team_score"
	result.winner_team_ids.append(1)
	result.player_scores = {"1": 5, "2": 1}
	result.team_scores = {"1": 10, "2": 4}

	var runtime = FakeRoomRuntime.new(state, FakeMatchService.new(config, "match_alpha", "room_alpha"))
	var payload: Dictionary = reporter._build_finalize_payload(runtime, result)
	var members: Array = payload.get("member_results", [])
	assert_eq(String(payload.get("match_id", "")), "match_alpha", "payload should include match id")
	assert_eq(String(payload.get("assignment_id", "")), "assign_alpha", "payload should include assignment id")
	assert_eq(members.size(), 2, "payload should include 2 member results")
	assert_eq(String(members[0].get("outcome", "")), "win", "winner team member should be win")
	assert_eq(String(members[1].get("outcome", "")), "loss", "loser team member should be loss")
	var reap_context: Dictionary = reporter._build_reap_context(runtime, payload)
	assert_eq(String(reap_context.get("battle_id", "")), "battle_alpha", "reap context should include battle id")
	assert_eq(String(reap_context.get("assignment_id", "")), "assign_alpha", "reap context should include assignment id")


func test_finalize_payload_falls_back_to_current_assignment_id() -> void:
	var reporter = ServerMatchFinalizeReporterScript.new()
	var state = RoomServerStateScript.new()
	state.ensure_room("room_alpha", 1, "casual_match_room", "")
	state.assignment_id = ""
	state.current_assignment_id = "assign_current"
	state.season_id = "season_s1"
	state.upsert_member(1, "Alpha", "", "", 1, "account_a", "profile_a")
	state.upsert_member(2, "Beta", "", "", 2, "account_b", "profile_b")

	var config = BattleStartConfigScript.new()
	config.match_id = "match_alpha"
	config.room_id = "room_alpha"
	config.mode_id = "mode_ranked"
	config.rule_set_id = "rule_standard"
	config.map_id = state.selected_map_id

	var result = BattleResultScript.new()
	result.finish_reason = "last_survivor"
	result.score_policy = "team_score"
	result.winner_team_ids.append(1)

	var runtime = FakeRoomRuntime.new(state, FakeMatchService.new(config, "match_alpha", "room_alpha"))
	var payload: Dictionary = reporter._build_finalize_payload(runtime, result)
	assert_eq(String(payload.get("assignment_id", "")), "assign_current", "payload should fallback to current assignment id")


func test_result_hash_is_stable_for_same_payload() -> void:
	var reporter = ServerMatchFinalizeReporterScript.new()
	var payload := {
		"match_id": "match_hash",
		"assignment_id": "assign_hash",
		"room_id": "room_hash",
		"room_kind": "casual_match_room",
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

	var hash_a := reporter._build_result_hash(payload)
	var retried_payload: Dictionary = payload.duplicate(true)
	retried_payload["finished_at"] = "2026-04-13T10:00:05Z"
	var hash_b := reporter._build_result_hash(retried_payload)
	assert_eq(hash_a, hash_b, "retry payload should produce stable result hash")


func test_finalize_request_uses_internal_json_service_client() -> void:
	var reporter = ServerMatchFinalizeReporterScript.new()
	reporter.configure("127.0.0.1", 18081, "secret_wp6", "wp6_key")
	assert_not_null(reporter._internal_client, "reporter should configure internal json client when secret is provided")
	var missing_secret = ServerMatchFinalizeReporterScript.new()
	missing_secret.configure("127.0.0.1", 18081, "", "wp6_key")
	var response := await missing_secret._send_internal_post_once("/internal/v1/matches/finalize", {"a": 1})
	assert_eq(String(response.get("error_code", "")), "MATCH_FINALIZE_SECRET_MISSING", "missing secret should still map to finalize secret missing")


func test_finalize_reporter_parses_game_service_base_url_endpoint() -> void:
	var reporter = ServerMatchFinalizeReporterScript.new()
	var previous_allow_insecure_http := OS.get_environment("QQT_ALLOW_INSECURE_HTTP")
	OS.set_environment("QQT_ALLOW_INSECURE_HTTP", "1")
	var endpoint: Dictionary = reporter._endpoint_from_base_url("http://game_service:18081/internal")
	assert_eq(String(endpoint.get("host", "")), "game_service")
	assert_eq(int(endpoint.get("port", 0)), 18081)
	OS.set_environment("QQT_ALLOW_INSECURE_HTTP", previous_allow_insecure_http)
