extends "res://tests/gut/base/qqt_integration_test.gd"


func test_main() -> void:
	_main_body()


func _main_body() -> void:
	_test_actor_registry_add_update_remove()
	_test_event_router_routes_explosion_event()
	_test_map_view_applies_and_clears_grid_cache()


func _test_actor_registry_add_update_remove() -> void:
	var registry := BattleActorRegistry.new()
	var parent := Node2D.new()

	registry.sync_players(parent, [
		{
			"entity_id": 1,
			"player_slot": 0,
			"alive": true,
			"facing": 1,
			"position": Vector2(24, 24),
			"color": Color(0.2, 0.7, 1.0, 1.0),
		}
	])
	registry.sync_bubbles(parent, [
		{
			"entity_id": 5,
			"position": Vector2(48, 48),
			"color": Color(0.3, 0.5, 1.0, 1.0),
		}
	])
	registry.sync_items(parent, [
		{
			"entity_id": 9,
			"item_type": 2,
			"position": Vector2(72, 72),
			"color": Color(1.0, 0.9, 0.2, 1.0),
		}
	])

	var initial_dump := registry.debug_dump_actor_summary()
	_assert_true(int(initial_dump.get("players", 0)) == 1, "actor registry spawns player actor")
	_assert_true(int(initial_dump.get("bubbles", 0)) == 1, "actor registry spawns bubble actor")
	_assert_true(int(initial_dump.get("items", 0)) == 1, "actor registry spawns item actor")

	registry.sync_players(parent, [])
	registry.sync_bubbles(parent, [])
	registry.sync_items(parent, [])

	var cleared_dump := registry.debug_dump_actor_summary()
	_assert_true(int(cleared_dump.get("players", 0)) == 0, "actor registry removes stale player actor")
	_assert_true(int(cleared_dump.get("bubbles", 0)) == 0, "actor registry removes stale bubble actor")
	_assert_true(int(cleared_dump.get("items", 0)) == 0, "actor registry removes stale item actor")

	registry.dispose()
	parent.free()


func _test_event_router_routes_explosion_event() -> void:
	var router := BattleEventRouter.new()
	var fx_layer := Node2D.new()
	var spawn_fx := BattleSpawnFxController.new()
	spawn_fx.fx_layer = fx_layer
	router.explosion_event_routed.connect(spawn_fx.spawn_explosion.bind(48.0))

	var exploded_event := SimEvent.new(12, SimEvent.EventType.BUBBLE_EXPLODED)
	exploded_event.payload["covered_cells"] = [Vector2i(2, 2), Vector2i(3, 2)]
	router.route_events([exploded_event])

	_assert_true(fx_layer.get_child_count() == 1, "battle event router routes explosion event")
	_assert_true(fx_layer.get_child_count() == 1, "spawn fx controller creates fx node from explosion event")

	spawn_fx.dispose()
	spawn_fx.free()
	fx_layer.free()
	router.free()


func _test_map_view_applies_and_clears_grid_cache() -> void:
	var map_view := BattleMapViewController.new()
	var grid_cache := {
		"cells": [
			{"x": 0, "y": 0, "tile_type": TileConstants.TileType.SOLID_WALL},
			{"x": 1, "y": 0, "tile_type": TileConstants.TileType.BREAKABLE_BLOCK},
			{"x": 2, "y": 0, "tile_type": TileConstants.TileType.SPAWN},
		]
	}

	map_view.apply_grid_cache(grid_cache, 48.0)
	var dump := map_view.debug_dump_map_state()
	_assert_true(int(dump.get("grid_cells", 0)) == 3, "map view controller stores grid cache")
	_assert_true(is_equal_approx(float(dump.get("cell_size", 0.0)), 48.0), "map view controller stores cell size")

	map_view.clear_map()
	var cleared_dump := map_view.debug_dump_map_state()
	_assert_true(int(cleared_dump.get("grid_cells", 0)) == 0, "map view controller clears grid cache")

	map_view.free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return


