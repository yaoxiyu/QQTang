class_name BattleMatch
extends RefCounted

var match_id: String = ""
var match_seed: int = 0
var start_tick: int = 0
var peer_ids: Array[int] = []
var selected_map_id: String = ""
var selected_mode_id: String = ""

var sim_world: SimWorld = null
var input_buffer: InputBuffer = null
var snapshot_service: SnapshotService = SnapshotService.new()
var snapshot_buffer: SnapshotBuffer = SnapshotBuffer.new()
var checksum_service: ChecksumBuilder = ChecksumBuilder.new()
var divergence_logger: DivergenceLogger = DivergenceLogger.new()

var peer_slot_by_peer_id: Dictionary = {}


func configure_from_room(room_session: RoomSession, p_match_id: String, p_seed: int, p_start_tick: int) -> void:
	match_id = p_match_id
	match_seed = p_seed
	start_tick = p_start_tick
	peer_ids = room_session.peers.duplicate()
	selected_map_id = room_session.selected_map_id
	selected_mode_id = room_session.selected_mode_id
	peer_slot_by_peer_id = room_session.build_peer_slots()


func attach_world(world: SimWorld) -> void:
	sim_world = world
	input_buffer = world.input_buffer


func bootstrap_world(config: SimConfig, bootstrap_data: Dictionary = {}) -> void:
	if sim_world == null:
		sim_world = SimWorld.new()
	if input_buffer == null:
		input_buffer = sim_world.input_buffer

	sim_world.rng = SimRng.new(match_seed)
	sim_world.bootstrap(config, bootstrap_data)
	for peer_id in peer_ids:
		_apply_controller_type(peer_id)


func push_player_input(frame: PlayerInputFrame) -> void:
	if input_buffer == null:
		return
	input_buffer.push_input(frame)


func build_input_frame_for_tick(tick_id: int) -> InputFrame:
	var frame := InputFrame.new()
	frame.tick = tick_id

	for peer_id in peer_ids:
		var slot := int(peer_slot_by_peer_id.get(peer_id, -1))
		if slot < 0:
			continue
		frame.set_command(slot, _to_player_command(input_buffer.get_input(peer_id, tick_id)))

	return frame


func run_authoritative_tick() -> Dictionary:
	if sim_world == null or input_buffer == null:
		return {}

	var next_tick := sim_world.state.match_state.tick + 1
	var input_frame := build_input_frame_for_tick(next_tick)
	sim_world.enqueue_input(input_frame)
	var result := sim_world.step()
	var tick_id := int(result.get("tick", 0))
	var snapshot := snapshot_service.build_standard_snapshot(sim_world, tick_id)
	snapshot.checksum = checksum_service.build(sim_world, tick_id)
	snapshot_buffer.put(snapshot)
	return result


func build_player_position_summary() -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	if sim_world == null:
		return summary

	for player_id in sim_world.state.players.active_ids:
		var player := sim_world.state.players.get_player(player_id)
		if player == null:
			continue
		summary.append({
			"entity_id": player.entity_id,
			"player_slot": player.player_slot,
			"alive": player.alive,
			"life_state": player.life_state,
			"grid_pos": Vector2i(player.cell_x, player.cell_y),
			"move_dir": Vector2i(player.last_non_zero_move_x, player.last_non_zero_move_y),
			"move_progress": Vector2i(player.offset_x, player.offset_y),
			"facing": player.facing,
			"move_state": player.move_state
		})

	return summary


func get_snapshot(tick_id: int) -> WorldSnapshot:
	return snapshot_buffer.get_snapshot(tick_id)


func compute_checksum(tick_id: int) -> int:
	if sim_world == null:
		return 0
	return checksum_service.build(sim_world, tick_id)


func _to_player_command(frame: PlayerInputFrame) -> PlayerCommand:
	var command := PlayerCommand.neutral()
	command.move_x = frame.move_x
	command.move_y = frame.move_y
	command.place_bubble = frame.action_place
	command.remote_trigger = frame.action_skill1 or frame.action_skill2
	command.sequence_id = frame.seq
	return command


func _apply_controller_type(peer_id: int) -> void:
	var slot := int(peer_slot_by_peer_id.get(peer_id, -1))
	if slot < 0:
		return

	for player_id in sim_world.state.players.active_ids:
		var player := sim_world.state.players.get_player(player_id)
		if player == null or player.player_slot != slot:
			continue
		player.controller_type = PlayerState.ControllerType.NETWORK
		sim_world.state.players.update_player(player)
		return
func dispose() -> void:
	snapshot_buffer.clear()
	if sim_world != null:
		sim_world.dispose()
	sim_world = null
	input_buffer = null
