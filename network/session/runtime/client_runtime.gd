class_name ClientRuntime
extends Node

const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const BattleSimConfigBuilderScript = preload("res://gameplay/battle/config/battle_sim_config_builder.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")

signal config_accepted(config: BattleStartConfig)
signal prediction_event(event: Dictionary)
signal battle_finished(result: BattleResult)
signal log_event(message: String)

var start_config: BattleStartConfig = null
var local_peer_id: int = 0
var controlled_peer_id: int = 0
var client_session: ClientSession = null
var prediction_controller: PredictionController = null
var snapshot_service: SnapshotService = null
var _correction_count: int = 0
var _last_resync_tick: int = -1
var _active: bool = false
var _finished: bool = false


func configure(peer_id: int) -> void:
	local_peer_id = peer_id


func configure_controlled_peer(peer_id: int) -> void:
	controlled_peer_id = peer_id


func start_match(config: BattleStartConfig) -> bool:
	shutdown_runtime()
	if config == null:
		return false

	start_config = config.duplicate_deep()
	controlled_peer_id = int(start_config.controlled_peer_id) if start_config != null and int(start_config.controlled_peer_id) > 0 else local_peer_id
	client_session = ClientSession.new()
	client_session.configure(local_peer_id)
	add_child(client_session)
	snapshot_service = SnapshotService.new()
	prediction_controller = PredictionController.new()
	add_child(prediction_controller)

	var predicted_world := SimWorld.new()
	var sim_config := BattleSimConfigBuilderScript.new().build_for_start_config(start_config)
	predicted_world.bootstrap(sim_config, {
		"grid": MapLoaderScript.build_grid_state(start_config.map_id),
		"player_slots": start_config.player_slots.duplicate(true),
		"spawn_assignments": start_config.spawn_assignments.duplicate(true),
	})
	predicted_world.state.match_state.remaining_ticks = int(start_config.match_duration_ticks)
	predicted_world.state.match_state.phase = MatchState.Phase.PLAYING
	_mark_predicted_players_as_network(predicted_world)
	var controlled_slot := _resolve_controlled_slot(start_config)
	predicted_world.state.runtime_flags.client_prediction_mode = true
	predicted_world.state.runtime_flags.client_controlled_player_slot = controlled_slot
	prediction_controller.configure(
		predicted_world,
		snapshot_service,
		client_session.local_input_buffer,
		controlled_slot
	)
	if not prediction_controller.prediction_corrected.is_connected(_on_prediction_corrected):
		prediction_controller.prediction_corrected.connect(_on_prediction_corrected)
	if not prediction_controller.full_visual_resync.is_connected(_on_full_visual_resync):
		prediction_controller.full_visual_resync.connect(_on_full_visual_resync)

	_active = true
	_finished = false
	config_accepted.emit(start_config)
	log_event.emit("ClientRuntime accepted %s" % start_config.to_log_string())
	return true


func build_local_input_message(local_input: Dictionary = {}) -> Dictionary:
	if not _active or _finished or client_session == null:
		return {}
	var next_tick := prediction_controller.predicted_until_tick + 1 if prediction_controller != null else client_session.last_confirmed_tick + 1
	var frame := client_session.sample_input_for_tick(
		next_tick,
		clamp(int(local_input.get("move_x", 0)), -1, 1),
		clamp(int(local_input.get("move_y", 0)), -1, 1),
		bool(local_input.get("action_place", false))
	)
	client_session.send_input(frame)
	if prediction_controller != null:
		prediction_controller.predict_to_tick(next_tick)
	return {
		"message_type": TransportMessageTypesScript.INPUT_FRAME,
		"msg_type": TransportMessageTypesScript.INPUT_FRAME,
		"protocol_version": int(start_config.protocol_version) if start_config != null else 1,
		"match_id": String(start_config.match_id) if start_config != null else "",
		"sender_peer_id": local_peer_id,
		"tick": frame.tick_id,
		"frame": frame.to_dict(),
	}


func ingest_network_message(message: Dictionary) -> void:
	if client_session == null:
		return
	var message_type := str(message.get("message_type", message.get("msg_type", "")))
	match message_type:
		TransportMessageTypesScript.INPUT_ACK:
			if int(message.get("peer_id", -1)) == local_peer_id:
				client_session.on_input_ack(int(message.get("ack_tick", 0)))
		TransportMessageTypesScript.STATE_SUMMARY:
			client_session.on_state_summary(message)
			_apply_remote_player_summary_to_predicted_world(client_session.latest_player_summary)
		TransportMessageTypesScript.CHECKPOINT, TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT:
			client_session.on_snapshot(message)
			_apply_remote_player_summary_to_predicted_world(client_session.latest_player_summary)
			if prediction_controller != null:
				var authoritative_snapshot := _snapshot_from_message(message)
				_log_snapshot_mismatch(authoritative_snapshot)
				prediction_controller.on_authoritative_snapshot(authoritative_snapshot)
		TransportMessageTypesScript.MATCH_FINISHED:
			_finished = true
			battle_finished.emit(BattleResult.from_dict(message.get("result", {})))
		_:
			pass


func build_metrics() -> Dictionary:
	return {
		"ack_tick": client_session.last_confirmed_tick if client_session != null else 0,
		"snapshot_tick": client_session.latest_snapshot_tick if client_session != null else 0,
		"predicted_tick": prediction_controller.predicted_until_tick if prediction_controller != null else 0,
		"authoritative_tick": prediction_controller.authoritative_tick if prediction_controller != null else 0,
		"rollback_count": prediction_controller.rollback_controller.rollback_count if prediction_controller != null and prediction_controller.rollback_controller != null else 0,
		"resync_count": prediction_controller.rollback_controller.force_resync_count if prediction_controller != null and prediction_controller.rollback_controller != null else 0,
		"correction_count": _correction_count,
		"last_resync_tick": _last_resync_tick,
	}


func is_active() -> bool:
	return _active and not _finished


func shutdown_runtime() -> void:
	_active = false
	_finished = false
	start_config = null
	if prediction_controller != null:
		prediction_controller.dispose()
		if is_instance_valid(prediction_controller):
			prediction_controller.free()
	prediction_controller = null
	if client_session != null and is_instance_valid(client_session):
		client_session.free()
	client_session = null
	snapshot_service = null
	controlled_peer_id = 0
	_correction_count = 0
	_last_resync_tick = -1


func _resolve_controlled_slot(config: BattleStartConfig) -> int:
	if config == null:
		return 0
	var resolved_peer_id := controlled_peer_id if controlled_peer_id > 0 else local_peer_id
	for player_entry in config.player_slots:
		if int(player_entry.get("peer_id", -1)) == resolved_peer_id:
			return int(player_entry.get("slot_index", 0))
	return 0


func _snapshot_from_message(message: Dictionary) -> WorldSnapshot:
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = int(message.get("tick", 0))
	snapshot.players = _coerce_dictionary_array(message.get("players", []))
	snapshot.bubbles = _coerce_dictionary_array(message.get("bubbles", []))
	snapshot.items = _coerce_dictionary_array(message.get("items", []))
	snapshot.walls = _coerce_dictionary_array(message.get("walls", []))
	snapshot.mode_state = _coerce_dictionary(message.get("mode_state", {}))
	snapshot.rng_state = int(message.get("rng_state", 0))
	snapshot.checksum = int(message.get("checksum", 0))
	return snapshot


func _coerce_dictionary_array(raw_value: Variant) -> Array[Dictionary]:
	var coerced: Array[Dictionary] = []
	if raw_value is Array:
		for entry in raw_value:
			if entry is Dictionary:
				coerced.append(_normalize_snapshot_dictionary(entry))
	return coerced


func _coerce_dictionary(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return _normalize_snapshot_dictionary(raw_value)
	return {}


func _normalize_snapshot_dictionary(raw_value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key in raw_value.keys():
		normalized[key] = _normalize_snapshot_value(raw_value[key])
	return normalized


func _normalize_snapshot_value(raw_value: Variant) -> Variant:
	if raw_value is Dictionary:
		return _normalize_snapshot_dictionary(raw_value)
	if raw_value is Array:
		var normalized_array: Array = []
		for entry in raw_value:
			normalized_array.append(_normalize_snapshot_value(entry))
		return normalized_array
	if raw_value is float and is_equal_approx(raw_value, round(raw_value)):
		return int(round(raw_value))
	return raw_value


func _mark_predicted_players_as_network(predicted_world: SimWorld) -> void:
	if predicted_world == null:
		return
	for player_id in predicted_world.state.players.active_ids:
		var player := predicted_world.state.players.get_player(player_id)
		if player == null:
			continue
		player.controller_type = PlayerState.ControllerType.NETWORK
		predicted_world.state.players.update_player(player)


func _apply_remote_player_summary_to_predicted_world(player_summary: Array[Dictionary]) -> void:
	if prediction_controller == null or prediction_controller.predicted_sim_world == null:
		return
	if player_summary.is_empty():
		return

	var predicted_world := prediction_controller.predicted_sim_world
	var controlled_slot := int(predicted_world.state.runtime_flags.client_controlled_player_slot)
	var any_updated := false
	for entry in player_summary:
		var player := _find_predicted_player_for_summary(predicted_world, entry)
		if player == null:
			continue
		if player.player_slot == controlled_slot:
			continue

		var grid_pos: Variant = entry.get("grid_pos", Vector2i(player.cell_x, player.cell_y))
		var move_progress: Variant = entry.get("move_progress", Vector2i(player.offset_x, player.offset_y))
		var move_dir: Variant = entry.get("move_dir", Vector2i(player.last_non_zero_move_x, player.last_non_zero_move_y))

		if grid_pos is Vector2i:
			player.cell_x = grid_pos.x
			player.cell_y = grid_pos.y
		elif grid_pos is Vector2:
			player.cell_x = int(grid_pos.x)
			player.cell_y = int(grid_pos.y)

		if move_progress is Vector2i:
			player.offset_x = move_progress.x
			player.offset_y = move_progress.y
		elif move_progress is Vector2:
			player.offset_x = int(move_progress.x)
			player.offset_y = int(move_progress.y)

		if move_dir is Vector2i:
			player.last_non_zero_move_x = move_dir.x
			player.last_non_zero_move_y = move_dir.y
		elif move_dir is Vector2:
			player.last_non_zero_move_x = int(move_dir.x)
			player.last_non_zero_move_y = int(move_dir.y)

		player.alive = bool(entry.get("alive", player.alive))
		player.life_state = int(entry.get("life_state", player.life_state))
		player.facing = int(entry.get("facing", player.facing))
		player.move_state = int(entry.get("move_state", player.move_state))
		predicted_world.state.players.update_player(player)
		any_updated = true

	if any_updated:
		predicted_world.rebuild_runtime_indexes()


func _find_predicted_player_for_summary(predicted_world: SimWorld, entry: Dictionary) -> PlayerState:
	if predicted_world == null:
		return null

	var entity_id := int(entry.get("entity_id", -1))
	if entity_id >= 0:
		var by_entity := predicted_world.state.players.get_player(entity_id)
		if by_entity != null:
			return by_entity

	var player_slot := int(entry.get("player_slot", -1))
	if player_slot < 0:
		return null

	for player_id in predicted_world.state.players.active_ids:
		var player := predicted_world.state.players.get_player(player_id)
		if player != null and player.player_slot == player_slot:
			return player
	return null


func _log_snapshot_mismatch(authoritative_snapshot: WorldSnapshot) -> void:
	if authoritative_snapshot == null or prediction_controller == null or prediction_controller.rollback_controller == null:
		return
	var local_snapshot := prediction_controller.rollback_controller.snapshot_buffer.get_snapshot(authoritative_snapshot.tick_id)
	if local_snapshot == null:
		log_event.emit("Checkpoint mismatch tick %d: local_snapshot missing" % authoritative_snapshot.tick_id)
		return
	var rollback := prediction_controller.rollback_controller
	var reasons: Array[String] = []
	if not rollback._local_player_entries_equal(local_snapshot.players, authoritative_snapshot.players):
		reasons.append("local_player")
		var player_reason := _describe_local_player_mismatch(local_snapshot.players, authoritative_snapshot.players)
		if not player_reason.is_empty():
			reasons.append(player_reason)
	if not rollback._dictionary_array_equal(local_snapshot.bubbles, authoritative_snapshot.bubbles):
		reasons.append("bubbles")
		var bubble_reason := _describe_dictionary_array_mismatch(local_snapshot.bubbles, authoritative_snapshot.bubbles)
		if not bubble_reason.is_empty():
			reasons.append(bubble_reason)
	if not rollback._dictionary_array_equal(local_snapshot.items, authoritative_snapshot.items):
		reasons.append("items")
		var item_reason := _describe_dictionary_array_mismatch(local_snapshot.items, authoritative_snapshot.items)
		if not item_reason.is_empty():
			reasons.append(item_reason)
	if reasons.is_empty():
		return
	log_event.emit("Checkpoint mismatch tick %d: %s" % [authoritative_snapshot.tick_id, ", ".join(reasons)])


func _describe_dictionary_array_mismatch(local_values: Array[Dictionary], authoritative_values: Array[Dictionary]) -> String:
	if local_values.size() != authoritative_values.size():
		return "size %d!=%d" % [local_values.size(), authoritative_values.size()]
	var rollback := prediction_controller.rollback_controller if prediction_controller != null else null
	for index in range(local_values.size()):
		var local_entry := local_values[index]
		var authoritative_entry := authoritative_values[index]
		if rollback != null and rollback._dictionary_equal(local_entry, authoritative_entry):
			continue
		for key in authoritative_entry.keys():
			if rollback != null and rollback._variant_equal(local_entry.get(key), authoritative_entry.get(key)):
				continue
			return "idx %d key %s local=%s auth=%s" % [index, str(key), str(local_entry.get(key)), str(authoritative_entry.get(key))]
		var local_only_keys: Array[String] = []
		for key in local_entry.keys():
			if authoritative_entry.has(key):
				continue
			local_only_keys.append(str(key))
		if not local_only_keys.is_empty():
			return "idx %d local_only_keys=%s local=%s auth=%s" % [index, str(local_only_keys), str(local_entry), str(authoritative_entry)]
		return "idx %d entry differs local=%s auth=%s" % [index, str(local_entry), str(authoritative_entry)]
	return "content differs"


func _describe_local_player_mismatch(local_values: Array[Dictionary], authoritative_values: Array[Dictionary]) -> String:
	var rollback := prediction_controller.rollback_controller if prediction_controller != null else null
	if rollback == null:
		return ""
	var local_entry := rollback._find_local_player_entry(local_values)
	var authoritative_entry := rollback._find_local_player_entry(authoritative_values)
	if local_entry.is_empty() or authoritative_entry.is_empty():
		return "missing local controlled player entry"
	if rollback._dictionary_equal(local_entry, authoritative_entry):
		return ""
	for key in authoritative_entry.keys():
		if rollback._variant_equal(local_entry.get(key), authoritative_entry.get(key)):
			continue
		return "key %s local=%s auth=%s" % [str(key), str(local_entry.get(key)), str(authoritative_entry.get(key))]
	return "entry differs"
func _on_prediction_corrected(entity_id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	_correction_count += 1
	prediction_event.emit({
		"type": "prediction_corrected",
		"entity_id": entity_id,
		"from_pos": from_pos,
		"to_pos": to_pos,
		"message": "Client correction(fp) E%d %s -> %s" % [entity_id, str(from_pos), str(to_pos)],
	})


func _on_full_visual_resync(snapshot: WorldSnapshot) -> void:
	_last_resync_tick = snapshot.tick_id if snapshot != null else -1
	prediction_event.emit({
		"type": "full_resync",
		"tick": _last_resync_tick,
		"message": "Client full resync at tick %d" % _last_resync_tick,
	})
