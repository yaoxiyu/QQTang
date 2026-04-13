extends Node

const MatchmakingUseCaseScript = preload("res://app/front/matchmaking/matchmaking_use_case.gd")
const SettlementControllerScript = preload("res://presentation/battle/hud/settlement_controller.gd")
const SettlementSyncUseCaseScript = preload("res://app/front/settlement/settlement_sync_use_case.gd")
const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const RoomTicketResultScript = preload("res://app/front/auth/room_ticket_result.gd")
const BattleResultScript = preload("res://gameplay/battle/runtime/battle_result.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


class FakeMatchmakingGateway:
	extends RefCounted

	var _status_calls := 0

	func configure_base_url(_base_url: String) -> void:
		pass

	func enter_queue(_access_token: String, _queue_type: String, _mode_id: String, _rule_set_id: String) -> Dictionary:
		return {
			"ok": true,
			"queue_entry_id": "queue_smoke",
			"queue_state": "queued",
			"queue_key": "ranked:mode_ranked:rule_standard",
			"enqueue_unix_sec": 1,
			"last_heartbeat_unix_sec": 1,
			"expires_at_unix_sec": 30,
		}

	func cancel_queue(_access_token: String, queue_entry_id: String) -> Dictionary:
		return {"ok": true, "queue_entry_id": queue_entry_id, "queue_state": "cancelled"}

	func get_queue_status(_access_token: String, queue_entry_id: String) -> Dictionary:
		_status_calls += 1
		if _status_calls == 1:
			return {
				"ok": true,
				"queue_entry_id": queue_entry_id,
				"queue_state": "assigned",
				"queue_key": "ranked:mode_ranked:rule_standard",
				"queue_status_text": "Match found",
				"assignment_status_text": "Waiting for ticket request",
				"enqueue_unix_sec": 1,
				"last_heartbeat_unix_sec": 2,
				"expires_at_unix_sec": 32,
				"assignment_id": "assign_smoke",
				"assignment_revision": 1,
				"ticket_role": "create",
				"room_id": "room_smoke",
				"room_kind": "matchmade_room",
				"server_host": "127.0.0.1",
				"server_port": 9000,
				"mode_id": "mode_ranked",
				"rule_set_id": "rule_standard",
				"map_id": "map_arcade",
				"assigned_team_id": 1,
			}
		return {
			"ok": true,
			"queue_entry_id": queue_entry_id,
			"queue_state": "cancelled",
		}


class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func issue_room_ticket(_access_token: String, _request):
		return RoomTicketResultScript.success_from_dict({
			"ok": true,
			"ticket": "ticket_smoke",
			"ticket_id": "ticket_id_smoke",
			"account_id": "account_smoke",
			"profile_id": "profile_smoke",
			"room_id": "room_smoke",
			"room_kind": "matchmade_room",
			"assignment_id": "assign_smoke",
			"match_source": "matchmaking",
			"locked_map_id": "map_arcade",
			"locked_rule_set_id": "rule_standard",
			"locked_mode_id": "mode_ranked",
			"assigned_team_id": 1,
			"auto_ready_on_join": true,
		})


class FakeSettlementGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func fetch_match_summary(_access_token: String, _match_id: String) -> Dictionary:
		return {
			"ok": true,
			"match_id": "match_smoke",
			"profile_id": "profile_smoke",
			"server_sync_state": "committed",
			"rating_delta": 12,
			"rating_after": 1012,
			"season_point_delta": 12,
			"reward_summary": [{"reward_type": "season_point", "delta": 12}],
			"career_summary": {
				"career_total_matches": 1,
				"career_total_wins": 1,
				"career_total_losses": 0,
				"career_total_draws": 0,
			},
		}


func _ready() -> void:
	var auth = AuthSessionStateScript.new()
	auth.access_token = "token_smoke"
	var profile = PlayerProfileStateScript.new()
	var settings = FrontSettingsStateScript.new()
	settings.game_service_host = "127.0.0.1"
	settings.game_service_port = 18081
	settings.account_service_host = "127.0.0.1"
	settings.account_service_port = 18080

	var matchmaking = MatchmakingUseCaseScript.new()
	matchmaking.configure(auth, profile, settings, FakeMatchmakingGateway.new(), FakeRoomTicketGateway.new())
	var settlement_sync = SettlementSyncUseCaseScript.new()
	settlement_sync.configure(auth, settings, FakeSettlementGateway.new())
	var settlement_controller = _build_controller()
	add_child(settlement_controller)
	await get_tree().process_frame

	var ok := true
	ok = TestAssert.is_true(bool(matchmaking.enter_queue("ranked", "mode_ranked", "rule_standard").get("ok", false)), "smoke queue enter should succeed", "matchmaking_ranked_e2e_smoke_test") and ok
	ok = TestAssert.is_true(bool(matchmaking.poll_queue_status().get("ok", false)), "smoke queue assign should succeed", "matchmaking_ranked_e2e_smoke_test") and ok
	var consume_result: Dictionary = matchmaking.consume_assignment_and_build_room_entry_context()
	ok = TestAssert.is_true(bool(consume_result.get("ok", false)), "smoke assignment consumption should succeed", "matchmaking_ranked_e2e_smoke_test") and ok

	var battle_result = BattleResultScript.new()
	battle_result.local_outcome = "victory"
	battle_result.finish_reason = "last_survivor"
	settlement_controller.show_result(battle_result)
	settlement_controller.set_return_button_mode_lobby()
	var popup_summary : Dictionary = settlement_sync.apply_summary_to_popup(settlement_sync.fetch_match_summary("match_smoke").get("summary", null)).get("popup_summary", {})
	settlement_controller.apply_server_summary(popup_summary)

	var dump: Dictionary = settlement_controller.debug_dump_settlement_state()
	ok = TestAssert.is_true(bool(consume_result.get("entry_context", null).return_to_lobby_after_settlement), "smoke entry should return to lobby", "matchmaking_ranked_e2e_smoke_test") and ok
	ok = TestAssert.is_true(String(dump.get("server_sync_text", "")) == "Server Sync: Synced", "smoke settlement should show synced summary", "matchmaking_ranked_e2e_smoke_test") and ok
	ok = TestAssert.is_true(String(dump.get("career_summary_text", "")).find("Matches 1") >= 0, "smoke settlement should refresh career summary", "matchmaking_ranked_e2e_smoke_test") and ok
	if ok:
		print("matchmaking_ranked_e2e_smoke_test: PASS")


func _build_controller() -> Control:
	var controller = SettlementControllerScript.new()
	for name in [
		"ResultLabel",
		"DetailLabel",
		"MapSummaryLabel",
		"RuleSummaryLabel",
		"FinishReasonLabel",
		"ModeSummaryLabel",
		"CharacterSummaryLabel",
		"BubbleSummaryLabel",
		"ScoreSummaryLabel",
		"TeamOutcomeLabel",
		"ServerSyncLabel",
		"RatingDeltaLabel",
		"SeasonPointDeltaLabel",
		"RewardSummaryLabel",
		"CareerSummaryLabel",
	]:
		var label = Label.new()
		label.name = String(name)
		controller.add_child(label)
	var action_row = HBoxContainer.new()
	action_row.name = "ActionRow"
	controller.add_child(action_row)
	var return_button = Button.new()
	return_button.name = "ReturnToRoomButton"
	action_row.add_child(return_button)
	var rematch_button = Button.new()
	rematch_button.name = "RematchButton"
	action_row.add_child(rematch_button)
	return controller
