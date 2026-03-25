class_name PredictionController
extends Node

signal prediction_corrected(entity_id: int, from_pos: Vector2i, to_pos: Vector2i)
signal full_visual_resync(snapshot: WorldSnapshot)

# This world is an optional local prediction copy, never the authoritative truth.
var predicted_sim_world: SimWorld = null
var snapshot_service: SnapshotService = null
var snapshot_buffer: SnapshotBuffer = SnapshotBuffer.new()
var local_input_buffer: InputRingBuffer = InputRingBuffer.new()
var local_peer_id: int = 0
var predicted_until_tick: int = 0
var authoritative_tick: int = 0
var rollback_controller: RollbackController = null


func configure(
	p_predicted_sim_world: SimWorld,
	p_snapshot_service: SnapshotService,
	p_local_input_buffer: InputRingBuffer,
	p_local_peer_id: int
) -> void:
	predicted_sim_world = p_predicted_sim_world
	snapshot_service = p_snapshot_service
	local_input_buffer = p_local_input_buffer
	local_peer_id = p_local_peer_id
	predicted_until_tick = 0
	authoritative_tick = 0
	_ensure_rollback_controller()
	rollback_controller.configure(predicted_sim_world, snapshot_service, snapshot_buffer, local_input_buffer, local_peer_id)


func predict_to_tick(target_tick: int) -> void:
	if predicted_sim_world == null:
		# Without a dedicated predicted world copy, the client only submits input.
		predicted_until_tick = max(predicted_until_tick, target_tick)
		return

	while predicted_until_tick < target_tick:
		predicted_until_tick += 1
		_predict_one_tick(predicted_until_tick)

	if rollback_controller != null:
		rollback_controller.set_predicted_until_tick(predicted_until_tick)


func on_authoritative_snapshot(snapshot: WorldSnapshot) -> void:
	if snapshot == null:
		return

	authoritative_tick = snapshot.tick_id
	if rollback_controller == null:
		return

	rollback_controller.set_predicted_until_tick(predicted_until_tick)
	if rollback_controller.on_authoritative_snapshot(snapshot):
		predicted_until_tick = rollback_controller.predicted_until_tick


func _predict_one_tick(tick_id: int) -> void:
	if predicted_sim_world == null:
		return

	var frame := local_input_buffer.get_frame(tick_id)
	if frame == null:
		return

	var slot := _find_local_player_slot()
	if slot < 0:
		return

	var input_frame := InputFrame.new()
	input_frame.tick = tick_id
	input_frame.set_command(slot, _to_player_command(frame))

	predicted_sim_world.enqueue_input(input_frame)
	predicted_sim_world.step()

	if snapshot_service != null:
		var snapshot := snapshot_service.build_light_snapshot(predicted_sim_world, tick_id)
		snapshot_buffer.put(snapshot)


func _find_local_player_slot() -> int:
	if predicted_sim_world == null:
		return -1

	for player_id in predicted_sim_world.state.players.active_ids:
		var player := predicted_sim_world.state.players.get_player(player_id)
		if player == null:
			continue
		if player.player_slot == local_peer_id:
			return player.player_slot

	return -1


func _to_player_command(frame: PlayerInputFrame) -> PlayerCommand:
	var command := PlayerCommand.neutral()
	command.move_x = frame.move_x
	command.move_y = frame.move_y
	command.place_bubble = frame.action_place
	command.remote_trigger = frame.action_skill1 or frame.action_skill2
	command.sequence_id = frame.seq
	return command


func _ensure_rollback_controller() -> void:
	if rollback_controller != null:
		return

	rollback_controller = RollbackController.new()
	add_child(rollback_controller)
	rollback_controller.prediction_corrected.connect(_on_prediction_corrected)
	rollback_controller.full_visual_resync.connect(_on_full_visual_resync)


func _on_prediction_corrected(entity_id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	prediction_corrected.emit(entity_id, from_pos, to_pos)


func _on_full_visual_resync(snapshot: WorldSnapshot) -> void:
	full_visual_resync.emit(snapshot)
