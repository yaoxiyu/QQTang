extends QQTIntegrationTest

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")


func test_explosion_native_matches_gdscript_for_chain_hits_and_events() -> void:
	var gdscript_world := _build_world(8101)
	var native_world := _build_world(8101)
	var shadow_world := _build_world(8101)

	_configure_explosion_scenario(gdscript_world)
	_configure_explosion_scenario(native_world)
	_configure_explosion_scenario(shadow_world)

	var gdscript_result := _run_explosion(gdscript_world, false)
	var native_result := _run_explosion(native_world, true)
	var shadow_result := _run_explosion_shadow(shadow_world)

	for key in gdscript_result.keys():
		assert_eq(
			native_result.get(key),
			gdscript_result.get(key),
			"native explosion parity mismatch key=%s native=%s gdscript=%s" % [
				String(key),
				str(native_result.get(key)),
				str(gdscript_result.get(key)),
			]
		)
		assert_eq(
			shadow_result.get(key),
			gdscript_result.get(key),
			"native explosion shadow should leave GDScript result authoritative key=%s" % String(key)
		)

	gdscript_world.dispose()
	native_world.dispose()
	shadow_world.dispose()


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _configure_explosion_scenario(world: SimWorld) -> void:
	var source_player_id := int(world.state.players.active_ids[0])
	var target_player_id := int(world.state.players.active_ids[1])

	var target_player := world.state.players.get_player(target_player_id)
	target_player.cell_x = 6
	target_player.cell_y = 4
	target_player.offset_x = 0
	target_player.offset_y = 0
	world.state.players.update_player(target_player)

	var source_bubble_id := world.state.bubbles.spawn_bubble(source_player_id, 6, 5, 4, 1)
	var chain_bubble_id := world.state.bubbles.spawn_bubble(source_player_id, 8, 5, 1, 1)
	var source_bubble := world.state.bubbles.get_bubble(source_bubble_id)
	var chain_bubble := world.state.bubbles.get_bubble(chain_bubble_id)
	source_bubble.owner_player_id = source_player_id
	chain_bubble.owner_player_id = source_player_id
	world.state.bubbles.update_bubble(source_bubble)
	world.state.bubbles.update_bubble(chain_bubble)

	var item_id := world.state.items.spawn_item(3, 6, 6, 0)
	var item := world.state.items.get_item(item_id)
	item.visible = true
	world.state.items.update_item(item)

	world.state.indexes.rebuild_from_state(world.state)


func _run_explosion(world: SimWorld, use_native: bool) -> Dictionary:
	NativeFeatureFlagsScript.enable_native_explosion = use_native
	NativeFeatureFlagsScript.enable_native_explosion_shadow = false
	NativeFeatureFlagsScript.enable_native_explosion_execute = use_native
	world.events.begin_tick(1)

	var ctx := SimContext.new()
	ctx.config = world.config
	ctx.state = world.state
	ctx.queries = world.queries
	ctx.events = world.events
	ctx.rng = world.rng
	ctx.tick = 1
	ctx.scratch = SimScratch.new()
	ctx.scratch.bubbles_to_explode = [1]

	var resolve_system := ExplosionResolveSystem.new()
	var hit_system := ExplosionHitSystem.new()
	resolve_system.execute(ctx)
	hit_system.execute(ctx)
	NativeFeatureFlagsScript.enable_native_explosion = false
	NativeFeatureFlagsScript.enable_native_explosion_shadow = false
	NativeFeatureFlagsScript.enable_native_explosion_execute = false

	return {
		"processed_bubble_ids": _sorted_int_keys(ctx.scratch.processed_explosion_bubble_ids),
		"queued_chain_bubble_ids": _sorted_int_keys(ctx.scratch.queued_chain_bubble_ids),
		"destroy_cells": _serialize_cells(ctx.scratch.cells_to_destroy),
		"exploded_bubble_ids": _serialize_int_array(ctx.scratch.exploded_bubble_ids),
		"players_to_kill": _serialize_int_array(ctx.scratch.players_to_kill),
		"players_to_trap": _serialize_int_array(ctx.scratch.players_to_trap),
		"players_to_execute": _serialize_int_array(ctx.scratch.players_to_execute),
		"hit_entries": _serialize_hit_entries(ctx.scratch.explosion_hit_entries),
		"bubbles": SnapshotService.new().build_light_snapshot(world, world.state.match_state.tick).bubbles,
		"items": SnapshotService.new().build_light_snapshot(world, world.state.match_state.tick).items,
		"events": _serialize_events(ctx.events.get_events()),
	}


func _run_explosion_shadow(world: SimWorld) -> Dictionary:
	NativeFeatureFlagsScript.enable_native_explosion = true
	NativeFeatureFlagsScript.enable_native_explosion_shadow = true
	NativeFeatureFlagsScript.enable_native_explosion_execute = false
	var result := _run_explosion_context(world)
	NativeFeatureFlagsScript.enable_native_explosion = false
	NativeFeatureFlagsScript.enable_native_explosion_shadow = false
	return result


func _run_explosion_context(world: SimWorld) -> Dictionary:
	world.events.begin_tick(1)

	var ctx := SimContext.new()
	ctx.config = world.config
	ctx.state = world.state
	ctx.queries = world.queries
	ctx.events = world.events
	ctx.rng = world.rng
	ctx.tick = 1
	ctx.scratch = SimScratch.new()
	ctx.scratch.bubbles_to_explode = [1]

	var resolve_system := ExplosionResolveSystem.new()
	var hit_system := ExplosionHitSystem.new()
	resolve_system.execute(ctx)
	hit_system.execute(ctx)

	return {
		"processed_bubble_ids": _sorted_int_keys(ctx.scratch.processed_explosion_bubble_ids),
		"queued_chain_bubble_ids": _sorted_int_keys(ctx.scratch.queued_chain_bubble_ids),
		"destroy_cells": _serialize_cells(ctx.scratch.cells_to_destroy),
		"exploded_bubble_ids": _serialize_int_array(ctx.scratch.exploded_bubble_ids),
		"players_to_kill": _serialize_int_array(ctx.scratch.players_to_kill),
		"players_to_trap": _serialize_int_array(ctx.scratch.players_to_trap),
		"players_to_execute": _serialize_int_array(ctx.scratch.players_to_execute),
		"hit_entries": _serialize_hit_entries(ctx.scratch.explosion_hit_entries),
		"bubbles": SnapshotService.new().build_light_snapshot(world, world.state.match_state.tick).bubbles,
		"items": SnapshotService.new().build_light_snapshot(world, world.state.match_state.tick).items,
		"events": _serialize_events(ctx.events.get_events()),
	}


func _serialize_cells(cells: Array[Vector2i]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for cell in cells:
		serialized.append({"cell_x": cell.x, "cell_y": cell.y})
	return serialized


func _serialize_hit_entries(entries: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for raw_entry in entries:
		var entry: ExplosionHitEntry = raw_entry
		if entry == null:
			continue
		serialized.append({
			"source_bubble_id": entry.source_bubble_id,
			"source_player_id": entry.source_player_id,
			"source_cell_x": entry.source_cell_x,
			"source_cell_y": entry.source_cell_y,
			"target_type": entry.target_type,
			"target_entity_id": entry.target_entity_id,
			"target_cell_x": entry.target_cell_x,
			"target_cell_y": entry.target_cell_y,
			"target_aux_data": entry.target_aux_data.duplicate(true),
		})
	return serialized


func _serialize_events(events: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for raw_event in events:
		if raw_event == null:
			continue
		serialized.append({
			"event_type": int(raw_event.event_type),
			"payload": (raw_event.payload as Dictionary).duplicate(true),
		})
	return serialized


func _sorted_int_keys(values: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for key in values.keys():
		result.append(int(key))
	result.sort()
	return result


func _serialize_int_array(values: Array[int]) -> Array[int]:
	var copied := values.duplicate()
	copied.sort()
	return copied
