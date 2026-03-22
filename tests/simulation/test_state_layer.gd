extends Node

func _ready():

	var state = SimState.new()

	state.players.add_player(1, 0, 0, 0)

	var result = state.players.get_player(1)

	if result != null:
		print("player true")
	else:
		print("player false")
