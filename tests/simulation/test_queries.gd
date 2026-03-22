extends Node

func _ready():

	var state = SimState.new()

	state.players.add_player(1, 0, 0, 0)

	var queries = SimQueries.new()
	queries.set_state(state)

	var r = queries.get_player(1)

	if r != null:
		print("Queries true")
	else:
		print("Queries false")
