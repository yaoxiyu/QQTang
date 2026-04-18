extends "res://tests/gut/base/qqt_unit_test.gd"

const BombFuseSystem = preload("res://gameplay/simulation/systems/bomb_fuse_system.gd")
const ExplosionResolveSystem = preload("res://gameplay/simulation/systems/explosion_resolve_system.gd")
const ExplosionHitSystem = preload("res://gameplay/simulation/systems/explosion_hit_system.gd")
const StatusEffectSystem = preload("res://gameplay/simulation/systems/status_effect_system.gd")
const PreTickSystem = preload("res://gameplay/simulation/systems/pre_tick_system.gd")
const BattleExplosionConfigBuilder = preload("res://gameplay/battle/config/battle_explosion_config_builder.gd")
const ExplosionHitTypes = preload("res://gameplay/simulation/explosion/explosion_hit_types.gd")
const ExplosionHitEntry = preload("res://gameplay/simulation/explosion/explosion_hit_entry.gd")


func test_main() -> void:
	var ok := true
	ok = _test_player_kill_flows_through_hit_system_before_status_commit() and ok


func _test_player_kill_flows_through_hit_system_before_status_commit() -> bool:
	var world := _make_world()
	world.config.system_flags["explosion_reaction"] = BattleExplosionConfigBuilder.new().build_for_rule("ruleset_classic")

	var players := world.state.players.active_ids
	var attacker := world.state.players.get_player(players[0])
	var victim := world.state.players.get_player(players[1])
	attacker.cell_x = 1
	attacker.cell_y = 1
	victim.cell_x = 3
	victim.cell_y = 2
	world.state.players.update_player(attacker)
	world.state.players.update_player(victim)

	var bubble_id := world.state.bubbles.spawn_bubble(attacker.entity_id, 2, 2, 1, 1)
	world.state.indexes.rebuild_from_state(world.state)

	var ctx := SimContext.new()
	ctx.config = world.config
	ctx.state = world.state
	ctx.queries = world.queries
	ctx.events = world.events
	ctx.rng = world.rng
	ctx.tick = 1

	PreTickSystem.new().execute(ctx)
	BombFuseSystem.new().execute(ctx)
	ExplosionResolveSystem.new().execute(ctx)

	var prefix := "explosion_player_kill_flow_test"
	var ok := true
	ok = qqt_check(ctx.scratch.players_to_kill.is_empty(), "resolve phase should not directly write players_to_kill", prefix) and ok
	ok = qqt_check(victim.alive, "victim should still be alive after resolve phase", prefix) and ok
	ok = qqt_check(_has_hit_for_player(ctx.scratch.explosion_hit_entries, victim.entity_id), "resolve phase should register player hit entry", prefix) and ok

	ExplosionHitSystem.new().execute(ctx)
	ok = qqt_check(ctx.scratch.players_to_kill.has(victim.entity_id), "hit phase should enqueue victim into players_to_kill", prefix) and ok
	ok = qqt_check(victim.alive, "victim should remain alive before status commit", prefix) and ok
	ok = qqt_check(victim.last_damage_from_player_id == attacker.entity_id, "hit phase should record killer player id", prefix) and ok

	StatusEffectSystem.new().execute(ctx)
	ok = qqt_check(not victim.alive, "status phase should commit player death", prefix) and ok
	ok = qqt_check(victim.life_state == PlayerState.LifeState.DEAD, "status phase should switch victim to DEAD life_state", prefix) and ok
	ok = qqt_check(world.state.bubbles.get_bubble(bubble_id) != null and not world.state.bubbles.get_bubble(bubble_id).alive, "source bubble should already be exploded", prefix) and ok

	world.dispose()
	return ok


func _has_hit_for_player(entries: Array, player_id: int) -> bool:
	for raw_entry in entries:
		var entry: ExplosionHitEntry = raw_entry as ExplosionHitEntry
		if entry == null:
			continue
		if entry.target_type == ExplosionHitTypes.TargetType.PLAYER and entry.target_entity_id == player_id:
			return true
	return false


func _make_world() -> SimWorld:
	var world := SimWorld.new()
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory._build_from_rows([
		"#######",
		"#S....#",
		"#.....#",
		"#....S#",
		"#######",
	])})
	return world

