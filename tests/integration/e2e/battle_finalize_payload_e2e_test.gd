extends "res://tests/gut/base/qqt_integration_test.gd"

const ServerMatchFinalizeReporterScript = preload("res://network/session/runtime/server_match_finalize_reporter.gd")
const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const BattleResultScript = preload("res://gameplay/battle/runtime/battle_result.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const BattleBootstrapProbeScript = preload("res://tests/helpers/e2e/battle_bootstrap_probe.gd")
const FakeRoomRuntimeScript = preload("res://tests/helpers/e2e/fake_room_runtime.gd")


class FakeInternalClient:
	extends RefCounted

	var response: Dictionary = {}
	var requests: Array[Dictionary] = []

	func _init(p_response: Dictionary) -> void:
		response = p_response.duplicate(true)

	func post_json(path: String, payload: Dictionary) -> Dictionary:
		requests.append({
			"path": path,
			"payload": payload.duplicate(true),
		})
		return response.duplicate(true)


class FakeMatchService:
	extends RefCounted

	var config = null
	var match_id: String = ""
	var room_id: String = ""

	func _init(p_config, p_match_id: String, p_room_id: String) -> void:
		config = p_config
		match_id = p_match_id
		room_id = p_room_id

	func get_last_finished_config():
		return config

	func get_last_finished_match_id() -> String:
		return match_id

	func get_last_finished_room_id() -> String:
		return room_id


func test_main() -> void:
	var prefix := "battle_finalize_payload_e2e_test"
	var ok := true

	var fixture := _build_finalize_fixture()
	var reporter = fixture["reporter"]
	var fake_client = fixture["fake_client"]
	var runtime = fixture["runtime"]
	var result = fixture["result"]

	await reporter._report_match_result(runtime, result)

	ok = qqt_check(fake_client.requests.size() == 1, "finalize should send one internal request", prefix) and ok
	var request: Dictionary = fake_client.requests[0] if fake_client.requests.size() > 0 else {}
	var payload: Dictionary = request.get("payload", {})
	ok = qqt_check(String(request.get("path", "")) == "/internal/v1/matches/finalize", "finalize request path should be canonical", prefix) and ok
	ok = qqt_check(_has_finalize_required_fields(payload), "finalize payload should include required fields", prefix) and ok
	ok = qqt_check(_member_rows_are_complete(payload), "finalize member rows should include required fields", prefix) and ok

	ok = qqt_check(not bool(reporter.last_finalize_status.get("ok", true)), "finalize failure must not be marked as success", prefix) and ok
	ok = qqt_check(String(reporter.last_finalize_status.get("error_code", "")) == "MATCH_FINALIZE_HASH_MISMATCH", "hash mismatch should be observable", prefix) and ok
	ok = qqt_check(String(reporter.last_finalize_status.get("result_hash", "")).begins_with("sha256:"), "result hash should still be attached for diagnostics", prefix) and ok

	var bootstrap = BattleBootstrapProbeScript.new()
	bootstrap._battle_runtime = Node.new()
	bootstrap._route_message({
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": 9,
	})
	var legacy_reject := bootstrap.latest_for_peer(9, TransportMessageTypesScript.ROOM_CREATE_REJECTED)
	ok = qqt_check(not legacy_reject.is_empty(), "legacy room message should be rejected by battle DS", prefix) and ok
	ok = qqt_check(String(legacy_reject.get("error", "")) == "BATTLE_DS_ROOM_FORBIDDEN", "legacy room reject should use BATTLE_DS_ROOM_FORBIDDEN", prefix) and ok


func _build_finalize_fixture() -> Dictionary:
	var state = RoomServerStateScript.new()
	state.ensure_room("room_alpha", 2, "matchmade_room", "E2E Room")
	state.assignment_id = "assign_alpha"
	state.season_id = "season_s1"
	state.upsert_member(11, "Alpha", "", "", "", "", 1, "account_a", "profile_a")
	state.upsert_member(12, "Beta", "", "", "", "", 2, "account_b", "profile_b")

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
	result.player_scores = {"11": 8, "12": 3}
	result.team_scores = {"1": 12, "2": 6}

	var runtime := FakeRoomRuntimeScript.new(state, FakeMatchService.new(config, "match_alpha", "room_alpha"))
	var reporter := ServerMatchFinalizeReporterScript.new()
	var fake_client := FakeInternalClient.new({
		"ok": false,
		"error_code": "MATCH_FINALIZE_HASH_MISMATCH",
		"user_message": "hash mismatch",
	})
	reporter.internal_auth_shared_secret = "test_secret"
	reporter._internal_client = fake_client
	reporter.retry_delays_msec = []

	return {
		"reporter": reporter,
		"fake_client": fake_client,
		"runtime": runtime,
		"result": result,
	}


func _has_finalize_required_fields(payload: Dictionary) -> bool:
	var required := [
		"match_id",
		"assignment_id",
		"room_id",
		"room_kind",
		"season_id",
		"mode_id",
		"rule_set_id",
		"map_id",
		"finish_reason",
		"score_policy",
		"winner_team_ids",
		"winner_peer_ids",
		"member_results",
		"result_hash",
	]
	for key in required:
		if not payload.has(key):
			return false
	return true


func _member_rows_are_complete(payload: Dictionary) -> bool:
	var members: Array = payload.get("member_results", [])
	if members.is_empty():
		return false
	for entry in members:
		var row: Dictionary = entry if entry is Dictionary else {}
		var required := [
			"account_id",
			"profile_id",
			"team_id",
			"peer_id",
			"outcome",
			"player_score",
			"team_score",
			"placement",
		]
		for key in required:
			if not row.has(key):
				return false
	return true
