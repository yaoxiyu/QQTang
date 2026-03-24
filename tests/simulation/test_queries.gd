extends Node

func _ready() -> void:
	var state := SimState.new()
	state.initialize_default()
	state.grid = TestMapFactory.build_basic_map()
	state.indexes.initialize(state.grid.width * state.grid.height)

	var player_id := state.players.add_player(0, 0, 1, 1)
	var bubble_id := state.bubbles.spawn_bubble(player_id, 2, 1, 1, 30)
	state.indexes.rebuild_from_state(state)

	var queries := SimQueries.new()
	queries.set_state(state)

	_assert(queries.is_spawn(1, 1), "spawn tile should be recognized")
	_assert(queries.is_hard_blocked(0, 0), "wall should block movement")
	_assert(not queries.is_hard_blocked(2, 1), "empty tile should not block movement")
	_assert(queries.get_player(player_id) != null, "player query should return player")
	_assert(queries.get_bubble_at(2, 1) == bubble_id, "bubble index query should match")

	print("test_queries: PASS")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_queries: FAIL - %s" % message)
