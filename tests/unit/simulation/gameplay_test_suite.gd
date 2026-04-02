# LEGACY / PROTOTYPE FILE
# Retained for historical testing or Phase0 compatibility.
# Not part of the production battle startup path.

class_name GameplayTestSuite
extends RefCounted

var ctx: TestContext = null
var tests: Array[Callable] = []
var index: int = 0
var finished: bool = false

func start(p_ctx: TestContext) -> void:
	ctx = p_ctx
	tests = [
		Callable(self, "test_map_init"),
		Callable(self, "test_player_spawn"),
		Callable(self, "test_player_move"),
		Callable(self, "test_place_bubble"),
		Callable(self, "test_explosion"),
		Callable(self, "test_item_pickup"),
		Callable(self, "test_win_condition"),
	]
	index = 0
	finished = false
	run_next()

func on_after_step(result: Dictionary) -> void:
	if "tick" in result:
		ctx.tick = int(result["tick"])

func on_bridge_observe(_result: Dictionary) -> void:
	pass

func run_next() -> void:
	if finished:
		return
	if index >= tests.size():
		finished = true
		print("ALL TESTS FINISHED")
		return
	tests[index].call()

func _pass(msg: String) -> void:
	print("[PASS] %s" % msg)
	index += 1
	run_next()

func _fail(msg: String) -> void:
	finished = true
	push_error("[FAIL] %s" % msg)

func _assert_true(condition: bool, msg: String) -> bool:
	if not condition:
		_fail(msg)
		return false
	return true

func _reset_world() -> void:
	var config := SimConfig.new()
	ctx.world.bootstrap(config, {"grid": BuiltinMapFactory.build_basic_map()})

func _find_event(events: Array, event_type: int) -> bool:
	for event in events:
		if event is SimEvent and event.event_type == event_type:
			return true
	return false

func test_map_init() -> void:
	_reset_world()
	var grid := ctx.world.state.grid
	if not _assert_true(grid.width > 0 and grid.height > 0, "map initialized"):
		return
	_pass("map initialized")

func test_player_spawn() -> void:
	_reset_world()
	if not _assert_true(ctx.world.state.players.active_ids.size() >= 2, "players spawned count"):
		return
	for player_id in ctx.world.state.players.active_ids:
		var player := ctx.world.state.players.get_player(player_id)
		if not _assert_true(player != null and player.alive, "player alive after spawn"):
			return
		if not _assert_true(ctx.world.queries.is_spawn(player.cell_x, player.cell_y), "player on spawn cell"):
			return
	_pass("players spawned")

func test_player_move() -> void:
	_reset_world()
	var player_id := ctx.world.state.players.active_ids[0]
	var player := ctx.world.state.players.get_player(player_id)
	if not _assert_true(player != null, "player exists for movement test"):
		return
	var from_x := player.cell_x
	var from_y := player.cell_y

	var frame := InputFrame.new()
	frame.tick = ctx.world.state.match_state.tick + 1
	var command := PlayerCommand.new()
	command.move_x = 1
	frame.set_command(player.player_slot, command)
	ctx.world.enqueue_input(frame)

	var result := ctx.world.step()
	var moved := ctx.world.state.players.get_player(player_id)
	if not _assert_true(moved.cell_x == from_x + 1 and moved.cell_y == from_y, "player moved one cell right"):
		return
	if not _assert_true(_find_event(result["events"], SimEvent.EventType.PLAYER_MOVED), "PLAYER_MOVED event emitted"):
		return
	_pass("player move")

func test_place_bubble() -> void:
	_reset_world()
	var player_id := ctx.world.state.players.active_ids[0]
	var player := ctx.world.state.players.get_player(player_id)
	if not _assert_true(player != null, "player exists for bubble test"):
		return
	var before_available := player.bomb_available

	var frame := InputFrame.new()
	frame.tick = ctx.world.state.match_state.tick + 1
	var command := PlayerCommand.new()
	command.place_bubble = true
	frame.set_command(player.player_slot, command)
	ctx.world.enqueue_input(frame)

	var result := ctx.world.step()
	if not _assert_true(ctx.world.state.bubbles.active_ids.size() == 1, "bubble created"):
		return
	var after_player := ctx.world.state.players.get_player(player_id)
	if not _assert_true(after_player.bomb_available == before_available - 1, "bomb_available decremented"):
		return
	if not _assert_true(_find_event(result["events"], SimEvent.EventType.BUBBLE_PLACED), "BUBBLE_PLACED event emitted"):
		return
	_pass("bubble placed")

func test_explosion() -> void:
	_reset_world()
	var player_id := ctx.world.state.players.active_ids[0]
	var player := ctx.world.state.players.get_player(player_id)
	if not _assert_true(player != null, "player exists for explosion test"):
		return
	player.bomb_fuse_ticks = 2
	ctx.world.state.players.update_player(player)

	var frame := InputFrame.new()
	frame.tick = ctx.world.state.match_state.tick + 1
	var command := PlayerCommand.new()
	command.place_bubble = true
	frame.set_command(player.player_slot, command)
	ctx.world.enqueue_input(frame)
	ctx.world.step()

	if not _assert_true(ctx.world.state.bubbles.active_ids.size() == 1, "bubble exists before explosion"):
		return
	var bubble_id := ctx.world.state.bubbles.active_ids[0]
	var bubble := ctx.world.state.bubbles.get_bubble(bubble_id)
	if not _assert_true(bubble != null, "bubble exists by id"):
		return

	var exploded := false
	while ctx.world.state.match_state.tick <= bubble.explode_tick:
		var result = ctx.world.step()
		exploded = exploded or _find_event(result["events"], SimEvent.EventType.BUBBLE_EXPLODED)

	var bubble_after := ctx.world.state.bubbles.get_bubble(bubble_id)
	if not _assert_true(bubble_after != null and not bubble_after.alive, "bubble exploded and marked dead"):
		return
	if not _assert_true(exploded, "BUBBLE_EXPLODED event emitted"):
		return
	_pass("explosion works")

func test_item_pickup() -> void:
	_reset_world()
	var player_id := ctx.world.state.players.active_ids[0]
	var player := ctx.world.state.players.get_player(player_id)
	if not _assert_true(player != null, "player exists for item test"):
		return
	var before_range := player.bomb_range

	var item_id := ctx.world.state.items.spawn_item(1, player.cell_x, player.cell_y, 0)
	var item := ctx.world.state.items.get_item(item_id)
	item.spawn_tick = ctx.world.state.match_state.tick
	ctx.world.state.items.update_item(item)
	ctx.world.state.indexes.rebuild_from_state(ctx.world.state)

	var result := ctx.world.step()
	var item_after := ctx.world.state.items.get_item(item_id)
	if not _assert_true(item_after != null and not item_after.alive, "item consumed"):
		return
	var player_after := ctx.world.state.players.get_player(player_id)
	if not _assert_true(player_after.bomb_range == before_range + 1, "item effect applied"):
		return
	if not _assert_true(_find_event(result["events"], SimEvent.EventType.ITEM_PICKED), "ITEM_PICKED event emitted"):
		return
	_pass("item pickup")

func test_win_condition() -> void:
	_reset_world()
	var players := ctx.world.state.players.active_ids
	if not _assert_true(players.size() >= 2, "enough players for win test"):
		return

	var winner_id := players[0]
	var loser_id := players[1]
	ctx.world.state.players.mark_player_dead(loser_id)
	ctx.world.state.indexes.rebuild_from_state(ctx.world.state)

	var result := ctx.world.step()
	var match := ctx.world.state.match_state
	if not _assert_true(match.phase == MatchState.Phase.ENDED, "match ended"):
		return
	if not _assert_true(match.winner_player_id == winner_id, "winner assigned"):
		return
	if not _assert_true(_find_event(result["events"], SimEvent.EventType.MATCH_ENDED), "MATCH_ENDED event emitted"):
		return
	_pass("win condition")
