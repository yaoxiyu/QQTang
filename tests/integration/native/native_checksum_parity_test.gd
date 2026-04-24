extends QQTIntegrationTest

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")


func test_checksum_native_matches_gdscript_across_tick_sequence() -> void:
	var world := _build_world(6001)
	var checksum_builder := ChecksumBuilder.new()
	var native_bridge := NativeChecksumBridge.new()
	var previous_flag := NativeFeatureFlagsScript.enable_native_checksum

	_configure_checksum_scenario(world)
	assert_true(NativeKernelRuntimeScript.get_kernel_version() != "", "native runtime should expose kernel version")

	for command in _build_command_sequence():
		_step_world(world, command)
		var tick_id := world.state.match_state.tick
		var expected := checksum_builder.build(world, tick_id)
		var actual := native_bridge.build(world, tick_id)
		assert_eq(
			actual,
			expected,
			"native checksum should match gdscript checksum at tick=%d" % tick_id
		)

	NativeFeatureFlagsScript.enable_native_checksum = previous_flag
	world.dispose()


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _configure_checksum_scenario(world: SimWorld) -> void:
	var player_ids: Array[int] = world.state.players.active_ids
	var player_a := world.state.players.get_player(int(player_ids[0]))
	player_a.speed_level = 3
	player_a.bomb_available = 1
	player_a.bomb_range = 3
	player_a.offset_x = 8
	player_a.last_non_zero_move_x = 1
	world.state.players.update_player(player_a)

	var player_b := world.state.players.get_player(int(player_ids[1]))
	player_b.alive = false
	player_b.life_state = PlayerState.LifeState.DEAD
	player_b.death_display_ticks = 12
	world.state.players.update_player(player_b)

	var bubble_id := world.state.bubbles.spawn_bubble(player_a.entity_id, player_a.cell_x, player_a.cell_y, 2, 12)
	var bubble := world.state.bubbles.get_bubble(bubble_id)
	bubble.owner_player_id = player_a.entity_id
	bubble.ignore_player_ids = [player_a.entity_id, player_b.entity_id]
	world.state.bubbles.update_bubble(bubble)

	var item_id := world.state.items.spawn_item(2, player_a.cell_x + 1, player_a.cell_y, world.state.match_state.tick)
	var item := world.state.items.get_item(item_id)
	item.visible = true
	world.state.items.update_item(item)

	world.state.mode.mode_timer_ticks = 180
	world.state.mode.payload_owner_id = player_a.entity_id
	world.state.mode.payload_cell_x = player_a.cell_x
	world.state.mode.payload_cell_y = player_a.cell_y
	world.state.mode.sudden_death_active = true
	world.state.indexes.rebuild_from_state(world.state)


func _build_command_sequence() -> Array[Vector2i]:
	return [
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
	]


func _step_world(world: SimWorld, command: Vector2i) -> void:
	var frame := InputFrame.new()
	frame.tick = world.state.match_state.tick + 1
	var player := world.state.players.get_player(int(world.state.players.active_ids[0]))
	var player_command := PlayerCommand.neutral()
	player_command.move_x = command.x
	player_command.move_y = command.y
	frame.set_command(player.player_slot, player_command)
	world.enqueue_input(frame)
	world.step()
