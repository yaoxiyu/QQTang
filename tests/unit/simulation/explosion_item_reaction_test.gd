extends "res://tests/gut/base/qqt_unit_test.gd"

const ExplosionReactionProfileRegistry = preload("res://gameplay/simulation/explosion/explosion_reaction_profile_registry.gd")
const BattleExplosionConfigBuilder = preload("res://gameplay/battle/config/battle_explosion_config_builder.gd")


func test_main() -> void:
	var ok := true
	ok = _test_destroy_profile_removes_item() and ok
	ok = _test_transform_profile_updates_item_type_in_place() and ok
	ok = _test_ignore_profile_keeps_item_alive() and ok


func _test_destroy_profile_removes_item() -> bool:
	var world := _make_world_with_item_profile("item_destroy_default")
	var item_id := _spawn_item_and_bubble(world)
	world.step()
	var item := world.state.items.get_item(item_id)
	var prefix := "explosion_item_reaction_test"
	var ok := true
	ok = qqt_check(item != null and not item.alive, "destroy profile should despawn hit item", prefix) and ok
	ok = qqt_check(not world.state.items.active_ids.has(item_id), "destroy profile should remove item from active list", prefix) and ok
	world.dispose()
	return ok


func _test_transform_profile_updates_item_type_in_place() -> bool:
	var world := _make_world_with_item_profile("item_transform_to_speed")
	var item_id := _spawn_item_and_bubble(world)
	world.step()
	var item := world.state.items.get_item(item_id)
	var prefix := "explosion_item_reaction_test"
	var ok := true
	ok = qqt_check(item != null and item.alive, "transform profile should keep item alive", prefix) and ok
	ok = qqt_check(item != null and item.item_type == 3, "transform profile should update item type to speed", prefix) and ok
	ok = qqt_check(world.state.items.active_ids.has(item_id), "transform profile should keep same item id active", prefix) and ok
	world.dispose()
	return ok


func _test_ignore_profile_keeps_item_alive() -> bool:
	var world := _make_world_with_item_profile("item_ignore_default")
	var item_id := _spawn_item_and_bubble(world)
	world.step()
	var item := world.state.items.get_item(item_id)
	var prefix := "explosion_item_reaction_test"
	var ok := true
	ok = qqt_check(item != null and item.alive, "ignore profile should keep item alive", prefix) and ok
	ok = qqt_check(item != null and item.item_type == 1, "ignore profile should keep original item type", prefix) and ok
	world.dispose()
	return ok


func _make_world_with_item_profile(item_profile_id: String) -> SimWorld:
	var world := SimWorld.new()
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory._build_from_rows([
		"#######",
		"#S....#",
		"#.....#",
		"#....S#",
		"#######",
	])})
	var explosion_config := BattleExplosionConfigBuilder.new().build_for_rule("ruleset_classic")
	explosion_config["item_profile_id"] = item_profile_id
	explosion_config["item_profile"] = ExplosionReactionProfileRegistry.get_item_profile(item_profile_id)
	world.config.system_flags["explosion_reaction"] = explosion_config
	return world


func _spawn_item_and_bubble(world: SimWorld) -> int:
	var item_id := world.state.items.spawn_item(1, 3, 2, 0)
	var item := world.state.items.get_item(item_id)
	item.spawn_tick = world.state.match_state.tick
	world.state.items.update_item(item)
	world.state.bubbles.spawn_bubble(1, 2, 2, 1, 1)
	world.state.indexes.rebuild_from_state(world.state)
	return item_id

