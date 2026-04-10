extends Node

const TestAssert = preload("res://tests/helpers/test_assert.gd")
const BattleExplosionConfigBuilder = preload("res://gameplay/battle/config/battle_explosion_config_builder.gd")
const ExplosionReactionResolver = preload("res://gameplay/simulation/explosion/explosion_reaction_resolver.gd")
const ExplosionHitTypes = preload("res://gameplay/simulation/explosion/explosion_hit_types.gd")


func _ready() -> void:
	var ok := true
	ok = _test_rule_builders_resolve_profiles() and ok
	ok = _test_unknown_rule_falls_back_to_defaults() and ok
	ok = _test_resolver_reads_runtime_config() and ok
	if ok:
		print("explosion_reaction_resolver_test: PASS")


func _test_rule_builders_resolve_profiles() -> bool:
	var builder := BattleExplosionConfigBuilder.new()
	var classic := builder.build_for_rule("ruleset_classic")
	var score_team := builder.build_for_rule("ruleset_score_team")
	var quick_match := builder.build_for_rule("ruleset_quick_match")
	var prefix := "explosion_reaction_resolver_test"
	var ok := true
	ok = TestAssert.is_true(String(classic.get("player_profile_id", "")) == "player_trap_default", "classic should resolve player trap profile", prefix) and ok
	ok = TestAssert.is_true(String(score_team.get("player_profile_id", "")) == "player_trap_default", "score_team should resolve player trap profile", prefix) and ok
	ok = TestAssert.is_true(String(classic.get("bubble_profile_id", "")) == "bubble_chain_immediate", "classic should resolve bubble chain profile", prefix) and ok
	ok = TestAssert.is_true(String(quick_match.get("item_profile_id", "")) == "item_destroy_default", "quick_match should resolve item destroy profile", prefix) and ok
	ok = TestAssert.is_true(int(classic.get("player_profile", {}).get("reaction", -1)) == ExplosionHitTypes.PlayerReaction.TRAP_JELLY, "classic player profile should decode to trap reaction", prefix) and ok
	return ok


func _test_unknown_rule_falls_back_to_defaults() -> bool:
	var builder := BattleExplosionConfigBuilder.new()
	var built := builder.build_for_rule("missing_rule")
	var prefix := "explosion_reaction_resolver_test"
	var ok := true
	ok = TestAssert.is_true(String(built.get("player_profile_id", "")) == "player_kill_default", "missing rule should fall back to default player profile", prefix) and ok
	ok = TestAssert.is_true(String(built.get("bubble_profile_id", "")) == "bubble_chain_immediate", "missing rule should fall back to default bubble profile", prefix) and ok
	ok = TestAssert.is_true(String(built.get("breakable_block_profile_id", "")) == "breakable_destroy_stop", "missing rule should fall back to default breakable profile", prefix) and ok
	return ok


func _test_resolver_reads_runtime_config() -> bool:
	var world := _make_world()
	var player := world.state.players.get_player(world.state.players.active_ids[0])
	var item_id := world.state.items.spawn_item(1, 2, 2, 0)
	var item := world.state.items.get_item(item_id)
	world.state.indexes.rebuild_from_state(world.state)

	world.config.system_flags["explosion_reaction"] = {
		"player_profile_id": "player_ignore_default",
		"bubble_profile_id": "bubble_ignore_default",
		"item_profile_id": "item_transform_to_speed",
		"breakable_block_profile_id": "breakable_ignore_default",
	}

	var player_result := ExplosionReactionResolver.resolve_player_reaction(_make_ctx(world), player)
	var item_result := ExplosionReactionResolver.resolve_item_reaction(_make_ctx(world), item)
	var block_result := ExplosionReactionResolver.resolve_breakable_block_reaction(_make_ctx(world), 1, 1)
	var prefix := "explosion_reaction_resolver_test"
	var ok := true
	ok = TestAssert.is_true(int(player_result.get("reaction", -1)) == ExplosionHitTypes.PlayerReaction.IGNORE, "resolver should read player ignore reaction from runtime config", prefix) and ok
	ok = TestAssert.is_true(int(item_result.get("reaction", -1)) == ExplosionHitTypes.ItemReaction.TRANSFORM, "resolver should read item transform reaction from runtime config", prefix) and ok
	ok = TestAssert.is_true(int(item_result.get("transform_item_type", -1)) == 3, "resolver should expose transform item type", prefix) and ok
	ok = TestAssert.is_true(int(block_result.get("reaction", -1)) == ExplosionHitTypes.BlockReaction.IGNORE, "resolver should read breakable ignore reaction from runtime config", prefix) and ok
	world.dispose()
	return ok


func _make_world() -> SimWorld:
	var world := SimWorld.new()
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory._build_from_rows([
		"#####",
		"#S..#",
		"#...#",
		"#..S#",
		"#####",
	])})
	return world


func _make_ctx(world: SimWorld) -> SimContext:
	var ctx := SimContext.new()
	ctx.config = world.config
	ctx.state = world.state
	ctx.queries = world.queries
	ctx.events = world.events
	ctx.rng = world.rng
	ctx.tick = world.state.match_state.tick
	return ctx
