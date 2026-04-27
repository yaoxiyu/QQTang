extends "res://tests/gut/base/qqt_integration_test.gd"

const SettlementControllerScript = preload("res://presentation/battle/hud/settlement_controller.gd")
const SettlementSyncUseCaseScript = preload("res://app/front/settlement/settlement_sync_use_case.gd")
const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const BattleResultScript = preload("res://gameplay/battle/runtime/battle_result.gd")


class FakeSettlementGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func fetch_match_summary(_access_token: String, _match_id: String) -> Dictionary:
		return {
			"ok": true,
			"match_id": "match_alpha",
			"profile_id": "profile_alpha",
			"server_sync_state": "committed",
			"outcome": "win",
			"rating_before": 1000,
			"rating_delta": 12,
			"rating_after": 1012,
			"rank_tier_after": "silver",
			"season_point_delta": 12,
			"career_xp_delta": 30,
			"gold_delta": 80,
			"reward_summary": [
				{"reward_type": "season_point", "delta": 12},
				{"reward_type": "career_xp", "delta": 30},
			],
			"career_summary": {
				"career_total_matches": 9,
				"career_total_wins": 6,
				"career_total_losses": 2,
				"career_total_draws": 1,
			},
		}


func test_main() -> void:
	var controller = _build_controller()
	add_child(controller)
	await get_tree().process_frame

	var result = BattleResultScript.new()
	result.local_outcome = "victory"
	result.finish_reason = "last_survivor"
	result.score_policy = "team_score"
	controller.show_result(result)

	var auth = AuthSessionStateScript.new()
	auth.access_token = "token_alpha"
	var settings = FrontSettingsStateScript.new()
	settings.game_service_host = "127.0.0.1"
	settings.game_service_port = 18081
	var use_case = SettlementSyncUseCaseScript.new()
	use_case.configure(auth, settings, FakeSettlementGateway.new())
	var fetch_result: Dictionary = use_case.fetch_match_summary("match_alpha")
	var popup_result: Dictionary = use_case.apply_summary_to_popup(fetch_result.get("summary", null))
	controller.apply_server_summary(popup_result.get("popup_summary", {}))
	controller.set_return_button_mode_lobby()

	var dump: Dictionary = controller.debug_dump_settlement_state()
	var prefix := "settlement_server_summary_sync_test"
	var ok := true
	ok = qqt_check(String(dump.get("server_sync_text", "")) == "Server Sync: Synced", "server sync label should update", prefix) and ok
	ok = qqt_check(String(dump.get("rating_delta_text", "")) == "Rating: +12 -> 1012", "rating label should refresh after server summary", prefix) and ok
	ok = qqt_check(String(dump.get("reward_summary_text", "")).find("season_point 12") >= 0, "reward summary should include reward delta", prefix) and ok
	ok = qqt_check(bool(dump.get("return_to_lobby_mode", false)), "match settlement should switch to lobby return mode", prefix) and ok


func _build_controller() -> Control:
	var controller = SettlementControllerScript.new()
	var result_label = Label.new()
	result_label.name = "ResultLabel"
	controller.add_child(result_label)
	var detail_label = Label.new()
	detail_label.name = "DetailLabel"
	controller.add_child(detail_label)
	var map_label = Label.new()
	map_label.name = "MapSummaryLabel"
	controller.add_child(map_label)
	var rule_label = Label.new()
	rule_label.name = "RuleSummaryLabel"
	controller.add_child(rule_label)
	var finish_label = Label.new()
	finish_label.name = "FinishReasonLabel"
	controller.add_child(finish_label)
	var mode_label = Label.new()
	mode_label.name = "ModeSummaryLabel"
	controller.add_child(mode_label)
	var character_label = Label.new()
	character_label.name = "CharacterSummaryLabel"
	controller.add_child(character_label)
	var bubble_label = Label.new()
	bubble_label.name = "BubbleSummaryLabel"
	controller.add_child(bubble_label)
	var score_label = Label.new()
	score_label.name = "ScoreSummaryLabel"
	controller.add_child(score_label)
	var team_label = Label.new()
	team_label.name = "TeamOutcomeLabel"
	controller.add_child(team_label)
	var sync_label = Label.new()
	sync_label.name = "ServerSyncLabel"
	controller.add_child(sync_label)
	var rating_label = Label.new()
	rating_label.name = "RatingDeltaLabel"
	controller.add_child(rating_label)
	var season_point_label = Label.new()
	season_point_label.name = "SeasonPointDeltaLabel"
	controller.add_child(season_point_label)
	var reward_label = Label.new()
	reward_label.name = "RewardSummaryLabel"
	controller.add_child(reward_label)
	var career_label = Label.new()
	career_label.name = "CareerSummaryLabel"
	controller.add_child(career_label)
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
