class_name BattleStartConfigBuilder
extends RefCounted

const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")

const DEFAULT_START_TICK: int = 0
const DEFAULT_PROTOCOL_VERSION: int = BattleStartConfigScript.DEFAULT_PROTOCOL_VERSION
const DEFAULT_GAMEPLAY_RULE_VERSION: int = BattleStartConfigScript.DEFAULT_GAMEPLAY_RULE_VERSION

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
	if not MapCatalogScript.has_map(snapshot.selected_map_id):
		return false
	if not RuleCatalogScript.has_rule(snapshot.rule_set_id):
		return false
	return true


func build_start_config(snapshot: RoomSnapshot, room_runtime_context: RoomRuntimeContext = null) -> BattleStartConfig:
	if not can_build_from_room(snapshot):
		return BattleStartConfig.new()

	return _build_start_config_internal(snapshot, true, room_runtime_context)


func assign_spawn_slots(snapshot: RoomSnapshot) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for member in snapshot.sorted_members():
		players.append({
			"peer_id": member.peer_id,
			"player_name": member.player_name,
			"display_name": member.player_name,
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


func debug_dump_start_config(snapshot: RoomSnapshot, room_runtime_context: RoomRuntimeContext = null) -> Dictionary:
	return _build_start_config_internal(snapshot, false, room_runtime_context).to_dict()


func _generate_match_id(snapshot: RoomSnapshot) -> String:
	var config_id := "%s_%d" % [match_id_prefix, next_match_sequence]
	next_match_sequence += 1
	if snapshot.room_id.is_empty():
		return config_id
	return "%s_%s" % [snapshot.room_id, config_id]


func _peek_match_id(snapshot: RoomSnapshot) -> String:
	var config_id := "%s_%d" % [match_id_prefix, next_match_sequence]
	if snapshot.room_id.is_empty():
		return config_id
	return "%s_%s" % [snapshot.room_id, config_id]


func _build_start_config_internal(snapshot: RoomSnapshot, consume_match_id: bool, room_runtime_context: RoomRuntimeContext = null) -> BattleStartConfig:
	var resolved_map_id := snapshot.selected_map_id
	var resolved_rule_set_id := snapshot.rule_set_id
	if room_runtime_context != null:
		if resolved_map_id.is_empty():
			resolved_map_id = room_runtime_context.selected_map_id
		if resolved_rule_set_id.is_empty():
			resolved_rule_set_id = room_runtime_context.selected_rule_set_id

	var map_metadata := _load_map_metadata(resolved_map_id)
	var player_slots := assign_spawn_slots(snapshot)
	var config := BattleStartConfig.new()
	config.protocol_version = DEFAULT_PROTOCOL_VERSION
	config.gameplay_rule_version = DEFAULT_GAMEPLAY_RULE_VERSION
	config.room_id = snapshot.room_id
	config.match_id = _generate_match_id(snapshot) if consume_match_id else _peek_match_id(snapshot)
	config.map_id = resolved_map_id
	config.map_version = int(map_metadata.get("version", BattleStartConfigScript.DEFAULT_MAP_VERSION))
	config.map_content_hash = String(map_metadata.get("content_hash", ""))
	config.rule_set_id = resolved_rule_set_id
	config.players = player_slots.duplicate(true)
	config.player_slots = player_slots.duplicate(true)
	config.spawn_assignments = _build_spawn_assignments(player_slots, map_metadata)
	config.battle_seed = generate_seed()
	config.start_tick = DEFAULT_START_TICK
	config.match_duration_ticks = _resolve_match_duration_ticks(resolved_rule_set_id)
	config.item_spawn_profile_id = String(map_metadata.get("item_spawn_profile_id", BattleStartConfigScript.DEFAULT_ITEM_SPAWN_PROFILE_ID))
	config.sort_players()
	return config


func _build_spawn_assignments(player_slots: Array[Dictionary], map_metadata: Dictionary) -> Array[Dictionary]:
	var assignments: Array[Dictionary] = []
	var spawn_points: Array = map_metadata.get("spawn_points", [])
	for index in range(player_slots.size()):
		var player_entry: Dictionary = player_slots[index]
		var spawn_point: Vector2i = _resolve_spawn_point(spawn_points, index)
		assignments.append({
			"peer_id": int(player_entry.get("peer_id", -1)),
			"slot_index": int(player_entry.get("slot_index", -1)),
			"spawn_index": index,
			"spawn_cell_x": spawn_point.x,
			"spawn_cell_y": spawn_point.y,
		})
	return assignments


func _resolve_spawn_point(spawn_points: Array, index: int) -> Vector2i:
	if index >= 0 and index < spawn_points.size() and spawn_points[index] is Vector2i:
		return spawn_points[index]
	return Vector2i(index + 1, index + 1)


func _load_map_metadata(map_id: String) -> Dictionary:
	return MapLoaderScript.load_map_metadata(map_id)


func _resolve_match_duration_ticks(rule_set_id: String) -> int:
	match rule_set_id:
		"team":
			return 480
		_:
			return BattleStartConfigScript.DEFAULT_MATCH_DURATION_TICKS
