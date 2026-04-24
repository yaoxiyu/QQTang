extends QQTIntegrationTest

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")


func test_movement_native_matches_gdscript_across_tick_sequence() -> void:
	var gdscript_world := _build_world(7001)
	var native_world := _build_world(7001)
	var shadow_world := _build_world(7001)
	var scripted_events: Array[Dictionary] = []
	var native_events: Array[Dictionary] = []
	var shadow_events: Array[Dictionary] = []

	_configure_movement_scenario(gdscript_world)
	_configure_movement_scenario(native_world)
	_configure_movement_scenario(shadow_world)

	NativeFeatureFlagsScript.enable_native_movement = false
	NativeFeatureFlagsScript.enable_native_movement_shadow = false
	NativeFeatureFlagsScript.enable_native_movement_execute = false
	for command in _build_command_sequence():
		scripted_events.append(_step_world(gdscript_world, command))

	NativeFeatureFlagsScript.enable_native_movement = true
	NativeFeatureFlagsScript.enable_native_movement_shadow = false
	NativeFeatureFlagsScript.enable_native_movement_execute = true
	for command in _build_command_sequence():
		native_events.append(_step_world(native_world, command))
	NativeFeatureFlagsScript.enable_native_movement = false
	NativeFeatureFlagsScript.enable_native_movement_execute = false

	NativeFeatureFlagsScript.enable_native_movement = true
	NativeFeatureFlagsScript.enable_native_movement_shadow = true
	NativeFeatureFlagsScript.enable_native_movement_execute = false
	for command in _build_command_sequence():
		shadow_events.append(_step_world(shadow_world, command))
	NativeFeatureFlagsScript.enable_native_movement = false
	NativeFeatureFlagsScript.enable_native_movement_shadow = false

	var snapshot_service := SnapshotService.new()
	var gdscript_snapshot := snapshot_service.build_light_snapshot(gdscript_world, gdscript_world.state.match_state.tick)
	var native_snapshot := snapshot_service.build_light_snapshot(native_world, native_world.state.match_state.tick)
	var shadow_snapshot := snapshot_service.build_light_snapshot(shadow_world, shadow_world.state.match_state.tick)

	assert_eq(native_snapshot.players, gdscript_snapshot.players, "native movement should preserve player snapshot parity")
	assert_eq(native_snapshot.bubbles, gdscript_snapshot.bubbles, "native movement should preserve bubble snapshot parity")
	assert_eq(native_events, scripted_events, "native movement should preserve event parity across ticks")
	assert_eq(shadow_snapshot.players, gdscript_snapshot.players, "native movement shadow should leave GDScript player result authoritative")
	assert_eq(shadow_snapshot.bubbles, gdscript_snapshot.bubbles, "native movement shadow should leave GDScript bubble result authoritative")
	assert_eq(shadow_events, scripted_events, "native movement shadow should preserve GDScript event result")

	gdscript_world.dispose()
	native_world.dispose()
	shadow_world.dispose()


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _configure_movement_scenario(world: SimWorld) -> void:
	var player_id := int(world.state.players.active_ids[0])
	var player := world.state.players.get_player(player_id)
	player.speed_level = 3
	world.state.players.update_player(player)

	var bubble_id := world.state.bubbles.spawn_bubble(player_id, player.cell_x, player.cell_y, 1, 30)
	var bubble := world.state.bubbles.get_bubble(bubble_id)
	bubble.ignore_player_ids = [player_id]
	world.state.bubbles.update_bubble(bubble)
	world.state.indexes.rebuild_from_state(world.state)


func _build_command_sequence() -> Array[Vector2i]:
	return [
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.UP,
	]


func _step_world(world: SimWorld, command: Vector2i) -> Dictionary:
	var frame := InputFrame.new()
	frame.tick = world.state.match_state.tick + 1
	var player := world.state.players.get_player(int(world.state.players.active_ids[0]))
	var player_command := PlayerCommand.neutral()
	player_command.move_x = command.x
	player_command.move_y = command.y
	frame.set_command(player.player_slot, player_command)
	world.enqueue_input(frame)
	var result := world.step()
	return _serialize_events(result.get("events", []))


func _serialize_events(events: Array) -> Dictionary:
	var serialized: Array[Dictionary] = []
	for raw_event in events:
		if raw_event == null:
			continue
		serialized.append({
			"event_type": int(raw_event.event_type),
			"payload": (raw_event.payload as Dictionary).duplicate(true),
		})
	return {"events": serialized}
