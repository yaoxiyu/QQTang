extends Node

const MatchmakingUseCaseScript = preload("res://app/front/matchmaking/matchmaking_use_case.gd")
const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


class FakeMatchmakingGateway:
	extends RefCounted

	var last_base_url: String = ""
	var last_cancel_queue_entry_id: String = ""

	func configure_base_url(base_url: String) -> void:
		last_base_url = base_url

	func enter_queue(_access_token: String, queue_type: String, match_format_id: String, mode_id: String, rule_set_id: String, selected_map_ids: Array[String]) -> Dictionary:
		return {
			"ok": true,
			"queue_entry_id": "queue_alpha",
			"queue_state": "queued",
			"queue_key": "%s:%s:%s" % [queue_type, match_format_id, mode_id],
			"match_format_id": match_format_id,
			"mode_id": mode_id,
			"rule_set_id": rule_set_id,
			"selected_map_ids": selected_map_ids.duplicate(),
			"enqueue_unix_sec": 1,
			"last_heartbeat_unix_sec": 1,
			"expires_at_unix_sec": 31,
		}

	func cancel_queue(_access_token: String, queue_entry_id: String) -> Dictionary:
		last_cancel_queue_entry_id = queue_entry_id
		return {
			"ok": true,
			"queue_entry_id": queue_entry_id,
			"queue_state": "cancelled",
		}

	func get_queue_status(_access_token: String, queue_entry_id: String) -> Dictionary:
		return {
			"ok": true,
			"queue_entry_id": queue_entry_id,
			"queue_state": "queued",
			"queue_key": "ranked:2v2:mode_ranked",
			"match_format_id": "2v2",
			"mode_id": "mode_ranked",
			"selected_map_ids": ["map_arcade"],
			"queue_status_text": "Searching for players",
			"assignment_status_text": "",
			"enqueue_unix_sec": 1,
			"last_heartbeat_unix_sec": 2,
			"expires_at_unix_sec": 32,
		}


class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass


func _ready() -> void:
	var auth = AuthSessionStateScript.new()
	auth.access_token = "token_alpha"
	var profile = PlayerProfileStateScript.new()
	var settings = FrontSettingsStateScript.new()
	settings.game_service_host = "127.0.0.1"
	settings.game_service_port = 18081
	settings.account_service_host = "127.0.0.1"
	settings.account_service_port = 18080
	var gateway = FakeMatchmakingGateway.new()
	var use_case = MatchmakingUseCaseScript.new()
	use_case.configure(auth, profile, settings, gateway, FakeRoomTicketGateway.new())

	var ok := true
	var enter_result: Dictionary = use_case.enter_queue("ranked", "2v2", "mode_ranked", "rule_standard", ["map_arcade"])
	ok = TestAssert.is_true(bool(enter_result.get("ok", false)), "enter queue should succeed", "lobby_matchmaking_queue_flow_test") and ok
	ok = TestAssert.is_true(settings.last_queue_type == "ranked", "enter queue should persist last queue type", "lobby_matchmaking_queue_flow_test") and ok

	var status_result: Dictionary = use_case.poll_queue_status()
	ok = TestAssert.is_true(bool(status_result.get("ok", false)), "poll queue status should succeed", "lobby_matchmaking_queue_flow_test") and ok
	ok = TestAssert.is_true(use_case.get_queue_state() != null and use_case.get_queue_state().queue_state == "queued", "queue state should remain queued", "lobby_matchmaking_queue_flow_test") and ok

	var cancel_result: Dictionary = use_case.cancel_queue()
	ok = TestAssert.is_true(bool(cancel_result.get("ok", false)), "cancel queue should succeed", "lobby_matchmaking_queue_flow_test") and ok
	ok = TestAssert.is_true(gateway.last_cancel_queue_entry_id == "queue_alpha", "cancel queue should use current queue entry id", "lobby_matchmaking_queue_flow_test") and ok
	if ok:
		print("lobby_matchmaking_queue_flow_test: PASS")
