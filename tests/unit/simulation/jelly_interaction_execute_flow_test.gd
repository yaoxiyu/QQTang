extends Node

const TestAssert = preload("res://tests/helpers/test_assert.gd")
const BattleStateToViewMapperScript = preload("res://presentation/battle/bridge/state_to_view_mapper.gd")
const BattleExplosionConfigBuilder = preload("res://gameplay/battle/config/battle_explosion_config_builder.gd")


func _ready() -> void:
	var ok := true
	ok = _test_enemy_touch_executes_trapped_player_in_same_tick() and ok
	ok = _test_enemy_touch_executes_adjacent_blocked_jelly_in_same_tick() and ok
	ok = _test_score_mode_enemy_touch_scores_and_starts_respawn() and ok
	ok = _test_trapped_player_explosion_starts_defeat_respawn() and ok
	ok = _test_trapped_player_auto_executes_after_timeout() and ok
	ok = _test_trap_and_death_preserve_subcell_offset() and ok
	ok = _test_respawn_invincibility_expires_before_next_explosion() and ok
	ok = _test_dead_player_stays_visible_for_death_display_window() and ok
	ok = _test_settlement_overrides_dead_display_pose() and ok
	if ok:
		print("jelly_interaction_execute_flow_test: PASS")


func _test_enemy_touch_executes_trapped_player_in_same_tick() -> bool:
	var world := _make_world(false)
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])
	_place_touching_enemy_jelly(world, attacker, victim)

	var result := world.step()
	var victim_after := world.state.players.get_player(victim.entity_id)
	var prefix := "jelly_interaction_execute_flow_test.classic"
	var ok := true
	ok = TestAssert.is_true(victim_after != null and not victim_after.alive, "enemy touch should finalize trapped victim death", prefix) and ok
	ok = TestAssert.is_true(victim_after != null and victim_after.life_state == PlayerState.LifeState.DEAD, "classic victim should enter DEAD", prefix) and ok
	ok = TestAssert.is_true(not world.state.players.active_ids.has(victim.entity_id), "dead victim should leave active ids", prefix) and ok
	ok = TestAssert.is_true(_has_event(result["events"], SimEvent.EventType.PLAYER_KILLED), "PLAYER_KILLED should be emitted in same tick", prefix) and ok
	world.dispose()
	return ok


func _test_enemy_touch_executes_adjacent_blocked_jelly_in_same_tick() -> bool:
	var world := _make_world(false)
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])
	_place_adjacent_enemy_jelly(world, attacker, victim)

	var result := world.step()
	var victim_after := world.state.players.get_player(victim.entity_id)
	var prefix := "jelly_interaction_execute_flow_test.adjacent"
	var ok := true
	ok = TestAssert.is_true(victim_after != null and not victim_after.alive, "adjacent blocked enemy touch should finalize trapped victim death", prefix) and ok
	ok = TestAssert.is_true(victim_after != null and victim_after.life_state == PlayerState.LifeState.DEAD, "adjacent victim should enter DEAD", prefix) and ok
	ok = TestAssert.is_true(_has_event(result["events"], SimEvent.EventType.PLAYER_KILLED), "adjacent touch should emit PLAYER_KILLED in same tick", prefix) and ok
	world.dispose()
	return ok


func _test_score_mode_enemy_touch_scores_and_starts_respawn() -> bool:
	var world := _make_world(true)
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])
	_place_touching_enemy_jelly(world, attacker, victim)

	var result := world.step()
	var attacker_after := world.state.players.get_player(attacker.entity_id)
	var victim_after := world.state.players.get_player(victim.entity_id)
	var prefix := "jelly_interaction_execute_flow_test.score"
	var ok := true
	ok = TestAssert.is_true(victim_after != null and not victim_after.alive, "score victim should be inactive while respawning", prefix) and ok
	ok = TestAssert.is_true(victim_after != null and victim_after.life_state == PlayerState.LifeState.REVIVING, "score victim should enter REVIVING", prefix) and ok
	ok = TestAssert.is_true(attacker_after != null and attacker_after.score == 1, "finisher personal score should increment", prefix) and ok
	ok = TestAssert.is_true(int(world.state.mode.team_scores.get(attacker.team_id, 0)) == 1, "finisher team score should increment", prefix) and ok
	ok = TestAssert.is_true(_has_event(result["events"], SimEvent.EventType.PLAYER_KILLED), "PLAYER_KILLED should be emitted before respawn countdown", prefix) and ok
	ok = TestAssert.is_true(_has_player_pose(world, victim.entity_id, "defeat"), "score victim should stay visible in defeat pose while reviving", prefix) and ok
	world.dispose()
	return ok


func _test_trapped_player_explosion_starts_defeat_respawn() -> bool:
	var world := _make_world(true)
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])
	attacker.cell_x = 1
	attacker.cell_y = 1
	attacker.offset_x = 0
	attacker.offset_y = 0
	victim.cell_x = 3
	victim.cell_y = 1
	victim.offset_x = 250
	victim.offset_y = -125
	victim.life_state = PlayerState.LifeState.TRAPPED
	victim.alive = true
	victim.last_damage_from_player_id = attacker.entity_id
	world.state.players.update_player(attacker)
	world.state.players.update_player(victim)
	world.state.bubbles.spawn_bubble(attacker.entity_id, 3, 1, 1, 1)
	world.state.indexes.rebuild_from_state(world.state)

	var result := world.step()
	var victim_after := world.state.players.get_player(victim.entity_id)
	var prefix := "jelly_interaction_execute_flow.explosion_trapped"
	var ok := true
	ok = TestAssert.is_true(victim_after != null and not victim_after.alive, "exploded trapped victim should be inactive", prefix) and ok
	ok = TestAssert.is_true(victim_after != null and victim_after.life_state == PlayerState.LifeState.REVIVING, "exploded trapped victim should enter REVIVING", prefix) and ok
	ok = TestAssert.is_true(victim_after != null and victim_after.offset_x == 250 and victim_after.offset_y == -125, "exploded trapped victim should keep subcell offset", prefix) and ok
	ok = TestAssert.is_true(_has_event(result["events"], SimEvent.EventType.PLAYER_KILLED), "exploded trapped victim should emit PLAYER_KILLED", prefix) and ok
	ok = TestAssert.is_true(_has_player_pose(world, victim.entity_id, "defeat"), "exploded trapped victim should show defeat pose before respawn", prefix) and ok
	world.dispose()
	return ok


func _test_trapped_player_auto_executes_after_timeout() -> bool:
	var world := _make_world(true)
	world.config.system_flags["rule_set"]["trapped_timeout_sec"] = 1
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])
	attacker.cell_x = 3
	attacker.cell_y = 1
	attacker.offset_x = 0
	attacker.offset_y = 0
	attacker.life_state = PlayerState.LifeState.NORMAL
	attacker.alive = true
	victim.cell_x = 1
	victim.cell_y = 1
	victim.offset_x = 0
	victim.offset_y = 0
	victim.life_state = PlayerState.LifeState.TRAPPED
	victim.alive = true
	victim.trapped_timeout_ticks = world.config.tick_rate
	world.state.players.update_player(attacker)
	world.state.players.update_player(victim)
	world.state.indexes.rebuild_from_state(world.state)

	var result: Dictionary = {}
	for _i in range(world.config.tick_rate):
		result = world.step()

	var victim_after := world.state.players.get_player(victim.entity_id)
	var prefix := "jelly_interaction_execute_flow_test.trapped_timeout"
	var ok := true
	ok = TestAssert.is_true(victim_after != null and victim_after.life_state == PlayerState.LifeState.REVIVING, "timed-out jelly should enter REVIVING in score mode", prefix) and ok
	ok = TestAssert.is_true(victim_after != null and victim_after.trapped_timeout_ticks == 0, "timed-out jelly should consume trapped timeout", prefix) and ok
	ok = TestAssert.is_true(_has_event(result["events"], SimEvent.EventType.PLAYER_KILLED), "timed-out jelly should emit PLAYER_KILLED", prefix) and ok
	world.dispose()
	return ok


func _test_trap_and_death_preserve_subcell_offset() -> bool:
	var world := _make_world(false)
	world.config.system_flags["explosion_reaction"] = BattleExplosionConfigBuilder.new().build_for_rule("ruleset_classic")
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])
	attacker.cell_x = 1
	attacker.cell_y = 1
	victim.cell_x = 3
	victim.cell_y = 1
	victim.offset_x = 300
	victim.offset_y = -200
	world.state.players.update_player(attacker)
	world.state.players.update_player(victim)
	world.state.bubbles.spawn_bubble(attacker.entity_id, 3, 1, 1, 1)
	world.state.indexes.rebuild_from_state(world.state)

	world.step()
	var trapped := world.state.players.get_player(victim.entity_id)
	var ok := true
	var prefix := "jelly_interaction_execute_flow.offset"
	ok = TestAssert.is_true(trapped != null and trapped.life_state == PlayerState.LifeState.TRAPPED, "victim should enter TRAPPED", prefix) and ok
	ok = TestAssert.is_true(trapped != null and trapped.offset_x == 300 and trapped.offset_y == -200, "TRAPPED should preserve subcell offset", prefix) and ok

	_place_touching_enemy_jelly(world, attacker, trapped)
	trapped = world.state.players.get_player(victim.entity_id)
	trapped.offset_x = 300
	trapped.offset_y = -200
	world.state.players.update_player(trapped)
	world.step()
	var dead := world.state.players.get_player(victim.entity_id)
	ok = TestAssert.is_true(dead != null and dead.life_state == PlayerState.LifeState.DEAD, "victim should enter DEAD", prefix) and ok
	ok = TestAssert.is_true(dead != null and dead.offset_x == 300 and dead.offset_y == -200, "DEAD should preserve subcell offset", prefix) and ok
	world.dispose()
	return ok


func _test_respawn_invincibility_expires_before_next_explosion() -> bool:
	var world := _make_world(true)
	world.config.system_flags["rule_set"]["respawn_invincible_sec"] = 1
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])
	_place_touching_enemy_jelly(world, attacker, victim)

	world.step()
	var victim_after := world.state.players.get_player(victim.entity_id)
	var max_steps := 80
	while max_steps > 0 and victim_after != null and victim_after.life_state != PlayerState.LifeState.NORMAL:
		world.step()
		victim_after = world.state.players.get_player(victim.entity_id)
		max_steps -= 1

	while max_steps > 0 and victim_after != null and victim_after.invincible_ticks > 0:
		world.step()
		victim_after = world.state.players.get_player(victim.entity_id)
		max_steps -= 1

	attacker = world.state.players.get_player(attacker.entity_id)
	victim_after = world.state.players.get_player(victim.entity_id)
	attacker.cell_x = 1
	attacker.cell_y = 1
	victim_after.cell_x = 3
	victim_after.cell_y = 1
	victim_after.offset_x = 0
	victim_after.offset_y = 0
	world.state.players.update_player(attacker)
	world.state.players.update_player(victim_after)
	world.state.bubbles.spawn_bubble(attacker.entity_id, 3, 1, 1, world.state.match_state.tick + 1)
	world.state.indexes.rebuild_from_state(world.state)

	world.step()
	var hit_again := world.state.players.get_player(victim.entity_id)
	var prefix := "jelly_interaction_execute_flow.respawn_vulnerable"
	var ok := true
	ok = TestAssert.is_true(hit_again != null and hit_again.life_state == PlayerState.LifeState.TRAPPED, "revived player should be hittable after invincibility expires", prefix) and ok
	world.dispose()
	return ok


func _test_dead_player_stays_visible_for_death_display_window() -> bool:
	var world := _make_world(false, "team_score", 1)
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])
	_place_touching_enemy_jelly(world, attacker, victim)

	world.step()
	var victim_after := world.state.players.get_player(victim.entity_id)
	var prefix := "jelly_interaction_execute_flow_test.death_display"
	var ok := true
	ok = TestAssert.is_true(victim_after != null and victim_after.death_display_ticks > 0, "classic victim should keep death display ticks", prefix) and ok
	ok = TestAssert.is_true(_has_player_pose(world, victim.entity_id, "defeat"), "classic victim should stay visible in defeat pose", prefix) and ok

	for _i in range(30):
		world.step()

	var victim_late := world.state.players.get_player(victim.entity_id)
	ok = TestAssert.is_true(victim_late != null and victim_late.death_display_ticks == 0, "death display ticks should expire", prefix) and ok
	ok = TestAssert.is_true(not _has_player_view(world, victim.entity_id), "classic victim should disappear after display window outside settlement", prefix) and ok
	world.dispose()
	return ok


func _test_settlement_overrides_dead_display_pose() -> bool:
	var world := _make_world(false, "last_survivor", 2)
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])
	_place_touching_enemy_jelly(world, attacker, victim)

	world.step()
	var prefix := "jelly_interaction_execute_flow_test.settlement_pose"
	var ok := true
	ok = TestAssert.is_true(world.state.match_state.phase == MatchState.Phase.ENDED, "classic kill should end two-team match", prefix) and ok
	ok = TestAssert.is_true(_has_player_pose(world, attacker.entity_id, "victory"), "winner should switch to victory pose in settlement", prefix) and ok
	ok = TestAssert.is_true(_has_player_pose(world, victim.entity_id, "defeat"), "loser should keep defeat pose in settlement", prefix) and ok
	world.dispose()
	return ok


func _make_world(respawn_enabled: bool, score_policy: String = "", death_display_sec: int = 2) -> SimWorld:
	var resolved_score_policy := score_policy
	if resolved_score_policy.is_empty():
		resolved_score_policy = "team_score" if respawn_enabled else "last_survivor"
	var config := SimConfig.new()
	config.system_flags["rule_set"] = {
		"respawn_enabled": respawn_enabled,
		"trapped_timeout_sec": 8,
		"respawn_delay_sec": 3 if respawn_enabled else 0,
		"respawn_invincible_sec": 0,
		"death_display_sec": death_display_sec,
		"rescue_touch_enabled": true,
		"enemy_touch_execute_enabled": true,
		"score_per_enemy_finish": 1,
		"score_policy": resolved_score_policy,
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
			{"peer_id": 2, "slot_index": 1, "team_id": 2},
		],
		"spawn_assignments": [
			{"peer_id": 1, "slot_index": 0, "spawn_cell_x": 1, "spawn_cell_y": 1},
			{"peer_id": 2, "slot_index": 1, "spawn_cell_x": 3, "spawn_cell_y": 1},
		],
	})
	return world


func _place_touching_enemy_jelly(world: SimWorld, attacker: PlayerState, victim: PlayerState) -> void:
	attacker.cell_x = 1
	attacker.cell_y = 1
	attacker.offset_x = 0
	attacker.offset_y = 0
	attacker.life_state = PlayerState.LifeState.NORMAL
	attacker.alive = true
	victim.cell_x = 1
	victim.cell_y = 1
	victim.offset_x = 0
	victim.offset_y = 0
	victim.life_state = PlayerState.LifeState.TRAPPED
	victim.alive = true
	victim.last_damage_from_player_id = -1
	world.state.players.update_player(attacker)
	world.state.players.update_player(victim)
	world.state.indexes.rebuild_from_state(world.state)


func _place_adjacent_enemy_jelly(world: SimWorld, attacker: PlayerState, victim: PlayerState) -> void:
	attacker.cell_x = 1
	attacker.cell_y = 1
	attacker.offset_x = 0
	attacker.offset_y = 0
	attacker.life_state = PlayerState.LifeState.NORMAL
	attacker.alive = true
	victim.cell_x = 2
	victim.cell_y = 1
	victim.offset_x = 0
	victim.offset_y = 0
	victim.life_state = PlayerState.LifeState.TRAPPED
	victim.alive = true
	victim.last_damage_from_player_id = -1
	var bubble_id := world.state.bubbles.spawn_bubble(victim.entity_id, victim.cell_x, victim.cell_y, 1, 9999)
	victim.trap_bubble_id = bubble_id
	world.state.players.update_player(attacker)
	world.state.players.update_player(victim)
	world.state.indexes.rebuild_from_state(world.state)


func _has_player_view(world: SimWorld, player_id: int) -> bool:
	return not _get_player_view(world, player_id).is_empty()


func _has_player_pose(world: SimWorld, player_id: int, pose_state: String) -> bool:
	var view := _get_player_view(world, player_id)
	return not view.is_empty() and String(view.get("pose_state", "")) == pose_state


func _get_player_view(world: SimWorld, player_id: int) -> Dictionary:
	var mapper := BattleStateToViewMapperScript.new()
	var player_views := mapper.build_player_views(world)
	for view in player_views:
		if int(view.get("entity_id", -1)) == player_id:
			return view
	return {}


func _has_event(events: Array, event_type: int) -> bool:
	for event in events:
		if event is SimEvent and event.event_type == event_type:
			return true
	return false
