extends Node

func _ready() -> void:
	var state := SimState.new()
	var player_id := state.players.add_player(1, 0, 0, 0)
	var player := state.players.get_player(player_id)

	_assert(player != null, "player should exist after add_player")
	_assert(state.players.has(player_id), "player store has should be true")

	state.players.mark_player_dead(player_id)
	var dead_player := state.players.get_player(player_id)
	_assert(dead_player != null and not dead_player.alive, "player should be dead after mark_player_dead")

	state.players.revive_player(player_id, 2, 2)
	var revived := state.players.get_player(player_id)
	_assert(revived != null and revived.alive, "player should be alive after revive")
	_assert(revived.cell_x == 2 and revived.cell_y == 2, "player revive position should match")

	print("test_state_layer: PASS")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_state_layer: FAIL - %s" % message)
