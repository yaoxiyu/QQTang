extends "res://tests/gut/base/qqt_unit_test.gd"

const ClientRuntimeSnapshotApplierScript = preload("res://network/session/runtime/client_runtime_snapshot_applier.gd")
const TileConstants = preload("res://gameplay/simulation/state/tile_constants.gd")


func test_snapshot_from_message_normalizes_integer_floats() -> void:
	var snapshot := ClientRuntimeSnapshotApplierScript.snapshot_from_message({
		"tick": 12.0,
		"players": [
			{"entity_id": 1.0, "cell": {"x": 2.0, "y": 3.5}},
		],
		"match_state": {
			"remaining_ticks": 90.0,
		},
	})

	assert_eq(snapshot.tick_id, 12, "snapshot tick should be coerced")
	assert_eq(snapshot.players[0]["entity_id"], 1, "integer-like floats should normalize")
	assert_eq(snapshot.players[0]["cell"]["x"], 2, "nested integer-like floats should normalize")
	assert_eq(snapshot.players[0]["cell"]["y"], 3.5, "non-integer floats should stay float")
	assert_eq(snapshot.match_state["remaining_ticks"], 90, "match state should normalize")


func test_decode_events_denormalizes_vector_payload() -> void:
	var events := ClientRuntimeSnapshotApplierScript.decode_events([
		{
			"tick": 7,
			"event_type": SimEvent.EventType.BUBBLE_PLACED,
			"payload": {
				"cell": {
					"__type": "Vector2i",
					"x": 3,
					"y": 4,
				},
			},
		},
	])

	assert_eq(events.size(), 1, "event should decode")
	assert_eq(events[0].payload["cell"], Vector2i(3, 4), "tagged Vector2i payload should denormalize")


func test_state_summary_without_walls_does_not_clear_local_walls() -> void:
	var world := _build_world()
	var breakable_cell := _find_breakable_cell(world)
	assert_ne(breakable_cell, Vector2i(-1, -1))
	var before_tile_type := world.state.grid.get_static_cell(breakable_cell.x, breakable_cell.y).tile_type

	ClientRuntimeSnapshotApplierScript.apply_authority_sideband(world, {
		"message_type": "STATE_SUMMARY",
		"tick": 1,
		"bubbles": [],
		"items": [],
		"match_state": {"remaining_ticks": 10},
	}, false, false)

	var after_tile_type := world.state.grid.get_static_cell(breakable_cell.x, breakable_cell.y).tile_type
	assert_eq(before_tile_type, TileConstants.TileType.BREAKABLE_BLOCK)
	assert_eq(after_tile_type, before_tile_type)
	world.dispose()


func test_checkpoint_with_walls_restores_local_walls() -> void:
	var world := _build_world()
	var breakable_cell := _find_breakable_cell(world)
	assert_ne(breakable_cell, Vector2i(-1, -1))

	ClientRuntimeSnapshotApplierScript.apply_authority_sideband(world, {
		"message_type": "CHECKPOINT",
		"tick": 2,
		"walls": [{
			"cell_x": breakable_cell.x,
			"cell_y": breakable_cell.y,
			"tile_type": TileConstants.TileType.EMPTY,
			"tile_flags": 0,
			"theme_variant": 0,
		}],
	}, true, true)

	var after_tile_type := world.state.grid.get_static_cell(breakable_cell.x, breakable_cell.y).tile_type
	assert_eq(after_tile_type, TileConstants.TileType.EMPTY)
	world.dispose()


func test_state_delta_with_changed_walls_restores_local_walls() -> void:
	var world := _build_world()
	var breakable_cell := _find_breakable_cell(world)
	assert_ne(breakable_cell, Vector2i(-1, -1))
	assert_eq(world.state.grid.get_static_cell(breakable_cell.x, breakable_cell.y).tile_type, TileConstants.TileType.BREAKABLE_BLOCK)

	ClientRuntimeSnapshotApplierScript.apply_authority_delta_sideband(world, {
		"message_type": "STATE_DELTA",
		"tick": 3,
		"changed_walls": [{
			"cell_x": breakable_cell.x,
			"cell_y": breakable_cell.y,
			"tile_type": TileConstants.TileType.EMPTY,
			"tile_flags": 0,
			"theme_variant": 0,
		}],
	})

	var after_tile_type := world.state.grid.get_static_cell(breakable_cell.x, breakable_cell.y).tile_type
	assert_eq(after_tile_type, TileConstants.TileType.EMPTY)
	world.dispose()


func test_state_summary_applies_airplane_payload() -> void:
	var world := _build_world()
	if world.state.item_pool_runtime == null:
		world.state.item_pool_runtime = preload("res://gameplay/simulation/entities/item_pool_runtime.gd").new()

	ClientRuntimeSnapshotApplierScript.apply_authority_sideband(world, {
		"message_type": "STATE_SUMMARY",
		"tick": 4,
		"airplane": {
			"active": true,
			"x": 7.25,
			"y": 3,
		},
	}, false, false)

	assert_true(world.state.item_pool_runtime.airplane_active, "airplane active should follow authority sideband")
	assert_eq(world.state.item_pool_runtime.airplane_y, 3, "airplane row should follow authority sideband")
	assert_true(absf(world.state.item_pool_runtime.airplane_x - 7.25) < 0.0001, "airplane x should follow authority sideband")
	world.dispose()


func _build_world() -> SimWorld:
	var world := SimWorld.new()
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _find_breakable_cell(world: SimWorld) -> Vector2i:
	for y in range(world.state.grid.height):
		for x in range(world.state.grid.width):
			var cell = world.state.grid.get_static_cell(x, y)
			if cell.tile_type == TileConstants.TileType.BREAKABLE_BLOCK:
				return Vector2i(x, y)
	return Vector2i(-1, -1)
