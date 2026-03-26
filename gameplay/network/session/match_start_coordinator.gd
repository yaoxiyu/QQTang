class_name MatchStartCoordinator
extends Node

signal battle_start_config_built(config: BattleStartConfig)

const DEFAULT_START_TICK: int = 0

var match_id_prefix: String = "match"
var next_match_sequence: int = 1
var forced_seed: int = -1


func can_build_from_room(snapshot: RoomSnapshot) -> bool:
	if snapshot == null:
		return false
	if snapshot.member_count() < 2:
		return false
	if not snapshot.all_ready:
		return false
	if snapshot.selected_map_id.is_empty():
		return false
	if snapshot.rule_set_id.is_empty():
		return false
	return true


func build_start_config(snapshot: RoomSnapshot) -> BattleStartConfig:
	if not can_build_from_room(snapshot):
		return BattleStartConfig.new()

	var config := BattleStartConfig.new()
	config.room_id = snapshot.room_id
	config.match_id = _generate_match_id(snapshot)
	config.map_id = snapshot.selected_map_id
	config.rule_set_id = snapshot.rule_set_id
	config.players = assign_spawn_slots(snapshot)
	config.seed = generate_seed()
	config.start_tick = DEFAULT_START_TICK
	config.sort_players()
	battle_start_config_built.emit(config)
	return config


func assign_spawn_slots(snapshot: RoomSnapshot) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for member in snapshot.sorted_members():
		players.append({
			"peer_id": member.peer_id,
			"player_name": member.player_name,
			"slot_index": member.slot_index,
			"spawn_slot": member.slot_index,
			"character_id": member.character_id,
		})
	return players


func generate_seed() -> int:
	if forced_seed >= 0:
		return forced_seed

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi())


func debug_dump_start_config(snapshot: RoomSnapshot) -> Dictionary:
	return build_start_config(snapshot).to_dict()


func _generate_match_id(snapshot: RoomSnapshot) -> String:
	var config_id := "%s_%d" % [match_id_prefix, next_match_sequence]
	next_match_sequence += 1
	if snapshot.room_id.is_empty():
		return config_id
	return "%s_%s" % [snapshot.room_id, config_id]
