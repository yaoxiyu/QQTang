class_name BattleStartConfig
extends RefCounted

const DEFAULT_PROTOCOL_VERSION: int = 1
const DEFAULT_GAMEPLAY_RULE_VERSION: int = 1
const DEFAULT_MAP_VERSION: int = 1
const DEFAULT_MATCH_DURATION_TICKS: int = 360
const DEFAULT_ITEM_SPAWN_PROFILE_ID: String = "default_items"
const BUILD_MODE_CANDIDATE: String = "candidate"
const BUILD_MODE_CANONICAL: String = "canonical"

var protocol_version: int = DEFAULT_PROTOCOL_VERSION
var gameplay_rule_version: int = DEFAULT_GAMEPLAY_RULE_VERSION
var build_mode: String = BUILD_MODE_CANDIDATE
var room_id: String = ""
var match_id: String = ""
var map_id: String = ""
var map_version: int = DEFAULT_MAP_VERSION
var map_content_hash: String = ""
var rule_set_id: String = ""
var players: Array[Dictionary] = []
var player_slots: Array[Dictionary] = []
var spawn_assignments: Array[Dictionary] = []
var battle_seed: int = 0
var start_tick: int = 0
var match_duration_ticks: int = DEFAULT_MATCH_DURATION_TICKS
var item_spawn_profile_id: String = DEFAULT_ITEM_SPAWN_PROFILE_ID
var snapshot_interval: int = 0
var checksum_interval: int = 0
var rollback_window: int = 0
var session_mode: String = "singleplayer_local"
var topology: String = "listen"
var authority_host: String = "127.0.0.1"
var authority_port: int = 9000
var local_peer_id: int = 0
var controlled_peer_id: int = 0
var owner_peer_id: int = 0
var server_match_revision: int = 0
var character_loadouts: Array[Dictionary] = []


func to_dict() -> Dictionary:
	_sync_player_aliases()
	return {
		"protocol_version": protocol_version,
		"gameplay_rule_version": gameplay_rule_version,
		"build_mode": build_mode,
		"room_id": room_id,
		"match_id": match_id,
		"map_id": map_id,
		"map_version": map_version,
		"map_content_hash": map_content_hash,
		"rule_set_id": rule_set_id,
		"players": players.duplicate(true),
		"player_slots": player_slots.duplicate(true),
		"spawn_assignments": spawn_assignments.duplicate(true),
		"seed": battle_seed,
		"start_tick": start_tick,
		"match_duration_ticks": match_duration_ticks,
		"item_spawn_profile_id": item_spawn_profile_id,
		"snapshot_interval": snapshot_interval,
		"checksum_interval": checksum_interval,
		"rollback_window": rollback_window,
		"session_mode": session_mode,
		"topology": topology,
		"authority_host": authority_host,
		"authority_port": authority_port,
		"local_peer_id": local_peer_id,
		"controlled_peer_id": controlled_peer_id,
		"owner_peer_id": owner_peer_id,
		"server_match_revision": server_match_revision,
		"character_loadouts": character_loadouts.duplicate(true),
	}


static func from_dict(data: Dictionary) -> BattleStartConfig:
	var config := BattleStartConfig.new()
	config.protocol_version = int(data.get("protocol_version", DEFAULT_PROTOCOL_VERSION))
	config.gameplay_rule_version = int(data.get("gameplay_rule_version", DEFAULT_GAMEPLAY_RULE_VERSION))
	config.build_mode = String(data.get("build_mode", BUILD_MODE_CANDIDATE))
	config.room_id = String(data.get("room_id", ""))
	config.match_id = String(data.get("match_id", ""))
	config.map_id = String(data.get("map_id", ""))
	config.map_version = int(data.get("map_version", DEFAULT_MAP_VERSION))
	config.map_content_hash = String(data.get("map_content_hash", ""))
	config.rule_set_id = String(data.get("rule_set_id", ""))
	config.players = _duplicate_dict_array(data.get("players", []))
	config.player_slots = _duplicate_dict_array(data.get("player_slots", config.players))
	config.spawn_assignments = _duplicate_dict_array(data.get("spawn_assignments", []))
	config.battle_seed = int(data.get("seed", 0))
	config.start_tick = int(data.get("start_tick", 0))
	config.match_duration_ticks = int(data.get("match_duration_ticks", DEFAULT_MATCH_DURATION_TICKS))
	config.item_spawn_profile_id = String(data.get("item_spawn_profile_id", DEFAULT_ITEM_SPAWN_PROFILE_ID))
	config.snapshot_interval = int(data.get("snapshot_interval", 0))
	config.checksum_interval = int(data.get("checksum_interval", 0))
	config.rollback_window = int(data.get("rollback_window", 0))
	config.session_mode = String(data.get("session_mode", "singleplayer_local"))
	config.topology = String(data.get("topology", "listen"))
	config.authority_host = String(data.get("authority_host", "127.0.0.1"))
	config.authority_port = int(data.get("authority_port", 9000))
	config.local_peer_id = int(data.get("local_peer_id", 0))
	config.controlled_peer_id = int(data.get("controlled_peer_id", 0))
	config.owner_peer_id = int(data.get("owner_peer_id", 0))
	config.server_match_revision = int(data.get("server_match_revision", 0))
	config.character_loadouts = _duplicate_dict_array(data.get("character_loadouts", []))
	config._sync_player_aliases()
	config.sort_players()
	return config


func duplicate_deep() -> BattleStartConfig:
	return BattleStartConfig.from_dict(to_dict())


func sort_players() -> void:
	_sync_player_aliases()
	player_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var slot_a := int(a.get("slot_index", -1))
		var slot_b := int(b.get("slot_index", -1))
		if slot_a == slot_b:
			return int(a.get("peer_id", -1)) < int(b.get("peer_id", -1))
		return slot_a < slot_b
	)
	players = player_slots.duplicate(true)
	spawn_assignments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var slot_a := int(a.get("slot_index", -1))
		var slot_b := int(b.get("slot_index", -1))
		if slot_a == slot_b:
			return int(a.get("peer_id", -1)) < int(b.get("peer_id", -1))
		return slot_a < slot_b
	)


func validate(options: Dictionary = {}) -> Dictionary:
	_sync_player_aliases()
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var expected_protocol_version := int(options.get("expected_protocol_version", DEFAULT_PROTOCOL_VERSION))
	var expected_gameplay_rule_version := int(options.get("expected_gameplay_rule_version", DEFAULT_GAMEPLAY_RULE_VERSION))
	var map_metadata: Dictionary = options.get("map_metadata", {})

	if protocol_version != expected_protocol_version:
		errors.append("protocol_version mismatch: expected %d, got %d" % [expected_protocol_version, protocol_version])
	if gameplay_rule_version != expected_gameplay_rule_version:
		errors.append("gameplay_rule_version mismatch: expected %d, got %d" % [expected_gameplay_rule_version, gameplay_rule_version])
	if build_mode != BUILD_MODE_CANDIDATE and build_mode != BUILD_MODE_CANONICAL:
		errors.append("build_mode is invalid: %s" % build_mode)
	if room_id.is_empty():
		errors.append("room_id is required")
	if match_id.is_empty():
		errors.append("match_id is required")
	if map_id.is_empty():
		errors.append("map_id is required")
	if map_version <= 0:
		errors.append("map_version must be positive")
	if map_content_hash.is_empty():
		errors.append("map_content_hash is required")
	if match_duration_ticks <= 0:
		errors.append("match_duration_ticks must be positive")
	if player_slots.is_empty():
		errors.append("player_slots must not be empty")
	if spawn_assignments.is_empty():
		errors.append("spawn_assignments must not be empty")
	if authority_port <= 0:
		errors.append("authority_port must be positive")
	if session_mode.is_empty():
		errors.append("session_mode is required")
	if topology.is_empty():
		errors.append("topology is required")
	if session_mode != "singleplayer_local" and session_mode != "network_client" and session_mode != "network_dedicated_server":
		errors.append("session_mode is invalid: %s" % session_mode)
	if topology != "listen" and topology != "dedicated_server":
		errors.append("topology is invalid: %s" % topology)

	var peer_ids: Dictionary = {}
	var slot_indices: Dictionary = {}
	for player_entry in player_slots:
		var peer_id := int(player_entry.get("peer_id", -1))
		var slot_index := int(player_entry.get("slot_index", -1))
		if peer_id <= 0:
			errors.append("player_slots contains invalid peer_id")
		elif peer_ids.has(peer_id):
			errors.append("duplicate peer_id in player_slots: %d" % peer_id)
		else:
			peer_ids[peer_id] = true
		if slot_index < 0:
			errors.append("player_slots contains invalid slot_index")
		elif slot_indices.has(slot_index):
			errors.append("duplicate slot_index in player_slots: %d" % slot_index)
		else:
			slot_indices[slot_index] = true

	var spawn_peer_ids: Dictionary = {}
	for assignment in spawn_assignments:
		var peer_id := int(assignment.get("peer_id", -1))
		var slot_index := int(assignment.get("slot_index", -1))
		if peer_id <= 0 or not peer_ids.has(peer_id):
			errors.append("spawn_assignments contains unknown peer_id: %d" % peer_id)
		if slot_index < 0 or not slot_indices.has(slot_index):
			errors.append("spawn_assignments contains unknown slot_index: %d" % slot_index)
		if spawn_peer_ids.has(peer_id):
			errors.append("duplicate peer_id in spawn_assignments: %d" % peer_id)
		else:
			spawn_peer_ids[peer_id] = true
	if spawn_peer_ids.size() != peer_ids.size() and not peer_ids.is_empty():
		errors.append("spawn_assignments must cover every player_slot")
	if topology == "dedicated_server":
		if local_peer_id < 0:
			errors.append("local_peer_id must not be negative")
		if controlled_peer_id < 0:
			errors.append("controlled_peer_id must not be negative")
		if local_peer_id > 0 and not peer_ids.has(local_peer_id):
			errors.append("local_peer_id must belong to player_slots in dedicated_server topology")
		if controlled_peer_id > 0 and not peer_ids.has(controlled_peer_id):
			errors.append("controlled_peer_id must belong to player_slots in dedicated_server topology")
		if session_mode == "network_client":
			if local_peer_id <= 0:
				errors.append("network_client config requires a valid local_peer_id")
			if controlled_peer_id <= 0:
				errors.append("network_client config requires a valid controlled_peer_id")
		if session_mode == "network_dedicated_server":
			if local_peer_id != 0:
				errors.append("network_dedicated_server config must not control a local peer")
			if controlled_peer_id != 0:
				errors.append("network_dedicated_server config must not control a player peer")
	if topology == "listen":
		if session_mode != "singleplayer_local":
			errors.append("listen topology requires session_mode=singleplayer_local")
		if local_peer_id <= 0:
			errors.append("listen topology requires a valid local_peer_id")
		if session_mode == "singleplayer_local" and controlled_peer_id <= 0:
			errors.append("singleplayer_local config requires controlled_peer_id")
		if controlled_peer_id != local_peer_id:
			errors.append("listen topology requires controlled_peer_id to match local_peer_id")
	if owner_peer_id <= 0:
		errors.append("owner_peer_id is required")
	elif not peer_ids.has(owner_peer_id):
		errors.append("owner_peer_id must belong to player_slots")

	if not map_metadata.is_empty():
		if map_id != String(map_metadata.get("map_id", map_id)):
			errors.append("map_id mismatch with catalog metadata")
		if map_version != int(map_metadata.get("version", map_version)):
			errors.append("map_version mismatch with catalog metadata")
		if map_content_hash != String(map_metadata.get("content_hash", map_content_hash)):
			errors.append("map_content_hash mismatch with catalog metadata")
		var expected_item_profile := String(map_metadata.get("item_spawn_profile_id", item_spawn_profile_id))
		if item_spawn_profile_id != expected_item_profile:
			errors.append("item_spawn_profile_id mismatch with catalog metadata")
		var spawn_points: Array = map_metadata.get("spawn_points", [])
		if spawn_points.size() < player_slots.size():
			errors.append("map spawn_points are insufficient for player_slots")
	else:
		warnings.append("map_metadata unavailable for validation")
	if not character_loadouts.is_empty():
		if character_loadouts.size() != player_slots.size():
			errors.append("character_loadouts must cover every player_slot")
		var loadout_peer_ids: Dictionary = {}
		for loadout in character_loadouts:
			var loadout_peer_id := int(loadout.get("peer_id", -1))
			if loadout_peer_id <= 0 or not peer_ids.has(loadout_peer_id):
				errors.append("character_loadouts contains unknown peer_id: %d" % loadout_peer_id)
				continue
			if loadout_peer_ids.has(loadout_peer_id):
				errors.append("duplicate peer_id in character_loadouts: %d" % loadout_peer_id)
				continue
			loadout_peer_ids[loadout_peer_id] = true
			if String(loadout.get("character_id", "")).is_empty():
				errors.append("character_loadouts contains empty character_id for peer %d" % loadout_peer_id)
			if String(loadout.get("content_hash", "")).is_empty():
				errors.append("character_loadouts contains empty content_hash for peer %d" % loadout_peer_id)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
	}


func to_pretty_json() -> String:
	return JSON.stringify(to_dict(), "\t")


func to_log_string() -> String:
	var validation := validate()
	return "BattleStartConfig(match_id=%s, map_id=%s, players=%d, spawns=%d, valid=%s)" % [
		match_id,
		map_id,
		player_slots.size(),
		spawn_assignments.size(),
		str(bool(validation.get("ok", false))),
	]


func _sync_player_aliases() -> void:
	if player_slots.is_empty() and not players.is_empty():
		player_slots = _duplicate_dict_array(players)
	if players.is_empty() and not player_slots.is_empty():
		players = _duplicate_dict_array(player_slots)
	if not player_slots.is_empty():
		players = _duplicate_dict_array(player_slots)


static func _duplicate_dict_array(value: Variant) -> Array[Dictionary]:
	var duplicated: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				duplicated.append(entry.duplicate(true))
	return duplicated
