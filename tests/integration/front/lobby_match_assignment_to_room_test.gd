extends "res://tests/gut/base/qqt_integration_test.gd"

# LEGACY: covers pre-LegacyMigration client-direct matchmaking assignment only.
const MatchmakingUseCaseScript = preload("res://app/front/matchmaking/matchmaking_use_case.gd")
const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const RoomTicketResultScript = preload("res://app/front/auth/room_ticket_result.gd")


class FakeMatchmakingGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func enter_queue(_access_token: String, _queue_type: String, _match_format_id: String, _mode_id: String, _rule_set_id: String, _selected_map_ids: Array[String]) -> Dictionary:
		return {
			"ok": true,
			"queue_entry_id": "queue_alpha",
			"queue_state": "queued",
			"queue_key": "ranked:2v2:mode_ranked",
			"match_format_id": "2v2",
			"mode_id": "mode_ranked",
			"selected_map_ids": ["map_arcade"],
			"enqueue_unix_sec": 1,
			"last_heartbeat_unix_sec": 1,
			"expires_at_unix_sec": 31,
		}

	func get_queue_status(_access_token: String, queue_entry_id: String) -> Dictionary:
		return {
			"ok": true,
			"queue_entry_id": queue_entry_id,
			"queue_state": "assigned",
			"queue_key": "ranked:2v2:mode_ranked",
			"match_format_id": "2v2",
			"selected_map_ids": ["map_arcade"],
			"queue_status_text": "Match found",
			"assignment_status_text": "Waiting for ticket request",
			"enqueue_unix_sec": 1,
			"last_heartbeat_unix_sec": 2,
			"expires_at_unix_sec": 32,
			"assignment_id": "assign_alpha",
			"assignment_revision": 1,
			"ticket_role": "create",
			"room_id": "room_alpha",
			"room_kind": "casual_match_room",
			"server_host": "127.0.0.1",
			"server_port": 9100,
			"mode_id": "mode_ranked",
			"rule_set_id": "rule_standard",
			"map_id": "map_arcade",
			"assigned_team_id": 1,
		}


class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func issue_room_ticket(_access_token: String, _request):
		return RoomTicketResultScript.success_from_dict({
			"ok": true,
			"ticket": "ticket_alpha",
			"ticket_id": "ticket_id_alpha",
			"account_id": "account_alpha",
			"profile_id": "profile_alpha",
			"room_id": "room_alpha",
			"room_kind": "casual_match_room",
			"assignment_id": "assign_alpha",
			"match_source": "matchmaking",
			"locked_map_id": "map_arcade",
			"locked_rule_set_id": "rule_standard",
			"locked_mode_id": "mode_ranked",
			"assigned_team_id": 1,
			"auto_ready_on_join": true,
		})


func test_main() -> void:
	var auth = AuthSessionStateScript.new()
	auth.access_token = "token_alpha"
	var profile = PlayerProfileStateScript.new()
	profile.default_character_id = "character_default"
	profile.default_bubble_style_id = "bubble_style_default"
	var settings = FrontSettingsStateScript.new()
	settings.game_service_host = "127.0.0.1"
	settings.game_service_port = 18081
	settings.account_service_host = "127.0.0.1"
	settings.account_service_port = 18080

	var use_case = MatchmakingUseCaseScript.new()
	use_case.configure(auth, profile, settings, FakeMatchmakingGateway.new(), FakeRoomTicketGateway.new())
	use_case.enter_queue("ranked", "2v2", "mode_ranked", "rule_standard", ["map_arcade"])
	use_case.poll_queue_status()
	var consume_result: Dictionary = use_case.consume_assignment_and_build_room_entry_context()

	var prefix := "lobby_match_assignment_to_room_test"
	var ok := true
	ok = qqt_check(bool(consume_result.get("ok", false)), "assignment consumption should succeed", prefix) and ok
	var entry_context = consume_result.get("entry_context", null)
	ok = qqt_check(entry_context != null and entry_context.target_room_id == "room_alpha", "assignment should build room entry context", prefix) and ok
	ok = qqt_check(entry_context != null and entry_context.return_to_lobby_after_settlement, "match entry should return to lobby after settlement", prefix) and ok
	ok = qqt_check(entry_context != null and entry_context.auto_ready_on_join, "match entry should auto ready on join", prefix) and ok
