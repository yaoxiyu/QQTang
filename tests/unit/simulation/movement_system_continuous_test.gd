extends "res://tests/gut/base/qqt_unit_test.gd"

const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")


func test_main() -> void:
	_test_release_stops_without_auto_completion()
	_test_hold_moves_across_cell_boundary()
	_test_player_moved_only_when_foot_cell_changes()
	_test_blocked_transition_clamps_to_boundary()
	_test_turn_gate_requires_center_alignment()
	_test_center_pivot_turns_without_translation()



func _test_release_stops_without_auto_completion() -> void:
	var world := _build_world()
	var player := _local_player(world)
	var start_abs := Vector2i(player.cell_x, player.cell_y)
	_step_with_input(world, player.player_slot, 1, 0)
	player = _local_player(world)
	var held_offset := player.offset_x
	_assert(held_offset != 0, "first move creates subcell offset")

	_step_with_input(world, player.player_slot, 0, 0)
	player = _local_player(world)
	_assert(player.move_state == PlayerState.MoveState.IDLE, "release sets move state to idle")
	_assert(player.offset_x == held_offset, "release keeps current subcell position")
	_assert(Vector2i(player.cell_x, player.cell_y) == start_abs, "release does not auto complete to next cell")

	world.dispose()


func _test_hold_moves_across_cell_boundary() -> void:
	var world := _build_world()
	var player := _local_player(world)
	var start_cell_x := player.cell_x

	for _i in range(4):
		_step_with_input(world, player.player_slot, 1, 0)

	player = _local_player(world)
	_assert(player.cell_x == start_cell_x + 1, "continuous hold crosses into next cell")
	_assert(player.offset_x < 0, "crossing writes rebased offset")
	_assert(player.move_state == PlayerState.MoveState.MOVING, "continuous hold stays moving")

	world.dispose()


func _test_player_moved_only_when_foot_cell_changes() -> void:
	var world := _build_world()
	var player := _local_player(world)

	var first_result := _step_with_input(world, player.player_slot, 1, 0)
	_assert(not _has_event(first_result["events"], SimEvent.EventType.PLAYER_MOVED), "subcell move alone emits no PLAYER_MOVED")

	var second_result := {}
	for _i in range(4):
		second_result = _step_with_input(world, player.player_slot, 1, 0)
		if _has_event(second_result["events"], SimEvent.EventType.PLAYER_MOVED):
			break
	_assert(_has_event(second_result["events"], SimEvent.EventType.PLAYER_MOVED), "crossing cell emits PLAYER_MOVED")

	world.dispose()


func _test_blocked_transition_clamps_to_boundary() -> void:
	var world := _build_world()
	var player := _local_player(world)
	player.cell_x = 3
	player.cell_y = 1
	player.offset_x = 250
	player.offset_y = 0
	world.state.players.update_player(player)
	world.state.indexes.rebuild_from_state(world.state)

	var result := {}
	for _i in range(4):
		result = _step_with_input(world, player.player_slot, 1, 0)
		if _has_event(result["events"], SimEvent.EventType.PLAYER_BLOCKED):
			break
	player = _local_player(world)
	_assert(_has_event(result["events"], SimEvent.EventType.PLAYER_BLOCKED), "blocked transition emits PLAYER_BLOCKED")
	_assert(player.cell_x == 3 and player.cell_y == 1, "blocked transition stays in current cell")
	_assert(player.offset_x <= 500, "blocked transition keeps player within current cell")
	_assert(player.move_state == PlayerState.MoveState.BLOCKED, "blocked transition sets blocked state")

	world.dispose()


func _test_turn_gate_requires_center_alignment() -> void:
	var world := _build_world()
	var player := _local_player(world)
	player.cell_x = 6
	player.cell_y = 5
	player.offset_x = 0
	player.offset_y = 300
	world.state.players.update_player(player)
	world.state.grid.set_static_cell(5, 5, TileFactory.make_solid_wall())
	world.state.grid.set_static_cell(7, 5, TileFactory.make_solid_wall())
	world.state.indexes.rebuild_from_state(world.state)

	var before_abs := Vector2i(player.cell_x, player.cell_y)
	_step_with_input(world, player.player_slot, 1, 0)
	player = _local_player(world)
	_assert(player.move_state == PlayerState.MoveState.TURN_ONLY or player.move_state == PlayerState.MoveState.BLOCKED, "off-center blocked turn does not translate")
	_assert(player.cell_x == before_abs.x and player.cell_y == before_abs.y, "turn-only keeps foot cell unchanged")
	_assert(player.offset_y == 300, "turn-only keeps current offset when outside snap window")

	world.dispose()


func _test_center_pivot_turns_without_translation() -> void:
	var world := _build_world()
	var player := _local_player(world)
	player.cell_x = 6
	player.cell_y = 5
	player.offset_x = 0
	player.offset_y = 0
	world.state.players.update_player(player)
	world.state.grid.set_static_cell(5, 5, TileFactory.make_solid_wall())
	world.state.grid.set_static_cell(7, 5, TileFactory.make_solid_wall())
	world.state.grid.set_static_cell(6, 4, TileFactory.make_solid_wall())
	world.state.grid.set_static_cell(6, 6, TileFactory.make_solid_wall())
	world.state.indexes.rebuild_from_state(world.state)

	var before_fp := _player_fp(world, player.entity_id)
	_step_with_input(world, player.player_slot, 0, -1)
	player = _local_player(world)
	var after_fp := _player_fp(world, player.entity_id)
	_assert(player.move_state == PlayerState.MoveState.TURN_ONLY or player.move_state == PlayerState.MoveState.BLOCKED, "center pivot does not translate into blocked cell")
	_assert(before_fp == after_fp, "center pivot causes no translation")
	_assert(player.facing == PlayerState.FacingDir.UP, "center pivot still updates facing")

	world.dispose()


func _build_world() -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(4242)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	for player_id in world.state.players.active_ids:
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		player.speed_level = 3
		world.state.players.update_player(player)
	return world


func _step_with_input(world: SimWorld, slot: int, move_x: int, move_y: int) -> Dictionary:
	var frame := InputFrame.new()
	frame.tick = world.state.match_state.tick + 1
	frame.set_command(slot, _command(move_x, move_y))
	world.enqueue_input(frame)
	return world.step()


func _command(move_x: int, move_y: int) -> PlayerCommand:
	var command := PlayerCommand.neutral()
	command.move_x = move_x
	command.move_y = move_y
	return command


func _local_player(world: SimWorld) -> PlayerState:
	var player_id := world.state.players.active_ids[0]
	return world.state.players.get_player(player_id)


func _player_fp(world: SimWorld, player_id: int) -> Vector2i:
	var player := world.state.players.get_player(player_id)
	return Vector2i(
		GridMotionMath.to_abs_x(player.cell_x, player.offset_x),
		GridMotionMath.to_abs_y(player.cell_y, player.offset_y)
	)


func _has_event(events: Array, event_type: int) -> bool:
	for event in events:
		if event is SimEvent and event.event_type == event_type:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)
