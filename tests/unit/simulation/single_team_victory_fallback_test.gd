extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleStateToViewMapperScript = preload("res://presentation/battle/bridge/state_to_view_mapper.gd")


func test_main() -> void:
	var ok := _test_single_team_match_ends_as_victory()


func _test_single_team_match_ends_as_victory() -> bool:
	var config := SimConfig.new()
	config.system_flags["rule_set"] = {
		"score_policy": "team_score",
	}
	var world := SimWorld.new()
	world.bootstrap(config, {
		"grid": BuiltinMapFactory._build_from_rows([
			"#####",
			"#S.S#",
			"#...#",
			"#####",
		]),
		"player_slots": [
			{"peer_id": 1, "slot_index": 0, "team_id": 1},
			{"peer_id": 2, "slot_index": 1, "team_id": 1},
		],
		"spawn_assignments": [
			{"peer_id": 1, "slot_index": 0, "spawn_cell_x": 1, "spawn_cell_y": 1},
			{"peer_id": 2, "slot_index": 1, "spawn_cell_x": 3, "spawn_cell_y": 1},
		],
	})

	world.step()
	var mapper := BattleStateToViewMapperScript.new()
	var views := mapper.build_player_views(world)
	var prefix := "single_team_victory_fallback_test"
	var ok := true
	ok = qqt_check(world.state.match_state.phase == MatchState.Phase.ENDED, "single-team match should end immediately", prefix) and ok
	ok = qqt_check(world.state.match_state.winner_team_id == 1, "single participating team should be winner", prefix) and ok
	ok = qqt_check(_all_views_have_pose(views, "victory"), "single-team settlement should display victory pose", prefix) and ok
	world.dispose()
	return ok


func _all_views_have_pose(views: Array[Dictionary], pose_state: String) -> bool:
	if views.is_empty():
		return false
	for view in views:
		if String(view.get("pose_state", "")) != pose_state:
			return false
	return true

