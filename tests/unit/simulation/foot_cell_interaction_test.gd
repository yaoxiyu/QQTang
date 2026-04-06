extends Node

const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")


func _ready() -> void:
	_test_bubble_placement_uses_foot_cell()
	_test_item_pickup_uses_foot_cell_before_boundary_cross()
	_test_players_by_cell_and_death_removal_follow_foot_cell()

	print("test_foot_cell_interaction: PASS")


func _test_bubble_placement_uses_foot_cell() -> void:
	var world := _build_world()
	var player := _local_player(world)
	player.offset_x = 499
	player.offset_y = 0
	world.state.players.update_player(player)
	world.state.indexes.rebuild_from_state(world.state)

	var foot_cell := PlayerLocator.get_foot_cell(player)
	var result := _step_with_command(world, player.player_slot, func(command: PlayerCommand) -> void:
		command.place_bubble = true
	)

	_assert(_has_event(result["events"], SimEvent.EventType.BUBBLE_PLACED), "bubble placement emits event")
	_assert(world.state.bubbles.active_ids.size() == 1, "bubble gets created")
	var bubble := world.state.bubbles.get_bubble(world.state.bubbles.active_ids[0])
	_assert(bubble.cell_x == foot_cell.x and bubble.cell_y == foot_cell.y, "bubble uses foot cell instead of raw offset")

	world.dispose()


func _test_item_pickup_uses_foot_cell_before_boundary_cross() -> void:
	var world := _build_world()
	var player := _local_player(world)
	player.offset_x = 499
	player.offset_y = 0
	world.state.players.update_player(player)

	var foot_cell := PlayerLocator.get_foot_cell(player)
	var item_id := world.state.items.spawn_item(1, foot_cell.x, foot_cell.y, 0)
	var item := world.state.items.get_item(item_id)
	item.spawn_tick = 0
	world.state.items.update_item(item)
	world.state.indexes.rebuild_from_state(world.state)

	var result := _step_with_command(world, player.player_slot, func(_command: PlayerCommand) -> void:
		pass
	)

	_assert(_has_event(result["events"], SimEvent.EventType.ITEM_PICKED), "item pickup emits event")
	_assert(not world.state.items.get_item(item_id).alive, "item is consumed")

	world.dispose()


func _test_players_by_cell_and_death_removal_follow_foot_cell() -> void:
	var world := _build_world()
	var attacker := world.state.players.get_player(world.state.players.active_ids[0])
	var victim := world.state.players.get_player(world.state.players.active_ids[1])

	attacker.cell_x = 1
	attacker.cell_y = 1
	attacker.offset_x = 0
	attacker.offset_y = 0
	world.state.players.update_player(attacker)

	victim.cell_x = 1
	victim.cell_y = 1
	victim.offset_x = 499
	victim.offset_y = 0
	world.state.players.update_player(victim)
	world.state.indexes.rebuild_from_state(world.state)

	var foot_cell := PlayerLocator.get_foot_cell(victim)
	_assert(world.queries.get_players_at(foot_cell.x, foot_cell.y).has(victim.entity_id), "players_by_cell indexes victim by foot cell")

	_step_with_command(world, attacker.player_slot, func(command: PlayerCommand) -> void:
		command.place_bubble = true
	)

	var bubble_id := world.state.bubbles.active_ids[0]
	var bubble := world.state.bubbles.get_bubble(bubble_id)
	while world.state.match_state.tick <= bubble.explode_tick and victim.alive:
		world.step()
		victim = world.state.players.get_player(victim.entity_id)

	_assert(victim != null and not victim.alive, "explosion resolves victim through foot-cell index")
	_assert(not world.queries.get_players_at(foot_cell.x, foot_cell.y).has(victim.entity_id), "death removal clears foot-cell index")

	world.dispose()


func _build_world() -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(5151)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _step_with_command(world: SimWorld, slot: int, mutator: Callable) -> Dictionary:
	var command := PlayerCommand.neutral()
	mutator.call(command)
	var frame := InputFrame.new()
	frame.tick = world.state.match_state.tick + 1
	frame.set_command(slot, command)
	world.enqueue_input(frame)
	return world.step()


func _local_player(world: SimWorld) -> PlayerState:
	return world.state.players.get_player(world.state.players.active_ids[0])


func _has_event(events: Array, event_type: int) -> bool:
	for event in events:
		if event is SimEvent and event.event_type == event_type:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_foot_cell_interaction: FAIL - %s" % message)
