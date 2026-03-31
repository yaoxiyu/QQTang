class_name PredictionDivergenceDebugger
extends RefCounted

var _armed: bool = false


func arm() -> Dictionary:
	_armed = true
	return {
		"type": "force_divergence_armed",
		"message": "Forced prediction divergence armed",
	}


func clear() -> void:
	_armed = false


func is_armed() -> bool:
	return _armed


func inject(snapshot: WorldSnapshot, prediction_controller: PredictionController) -> Dictionary:
	_armed = false
	if snapshot == null or prediction_controller == null or prediction_controller.rollback_controller == null:
		return {}

	var local_snapshot: WorldSnapshot = prediction_controller.rollback_controller.snapshot_buffer.get_snapshot(snapshot.tick_id)
	if local_snapshot != null and not local_snapshot.players.is_empty():
		var first_player: Dictionary = local_snapshot.players[0]
		first_player["cell_x"] = int(first_player.get("cell_x", 0)) + 1
		first_player["offset_x"] = 0
		local_snapshot.players[0] = first_player
		local_snapshot.checksum += 1

	var predicted_world: SimWorld = prediction_controller.predicted_sim_world
	if predicted_world != null and not predicted_world.state.players.active_ids.is_empty():
		var player_id: int = predicted_world.state.players.active_ids[0]
		var player: PlayerState = predicted_world.state.players.get_player(player_id)
		if player != null:
			player.cell_x = min(player.cell_x + 1, predicted_world.state.grid.width - 2)
			predicted_world.state.players.update_player(player)
			predicted_world.rebuild_runtime_indexes()

	return {
		"type": "forced_divergence",
		"tick": snapshot.tick_id,
		"message": "Injected prediction divergence at tick %d" % snapshot.tick_id,
	}
