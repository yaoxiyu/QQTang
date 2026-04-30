class_name BattleStartConfigBuilder
extends RefCounted

const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const CharacterTeamAnimationResolverScript = preload("res://content/character_animation_sets/runtime/character_team_animation_resolver.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")

const DEFAULT_START_TICK: int = 0
const DEFAULT_PROTOCOL_VERSION: int = BattleStartConfigScript.DEFAULT_PROTOCOL_VERSION
const DEFAULT_GAMEPLAY_RULE_VERSION: int = BattleStartConfigScript.DEFAULT_GAMEPLAY_RULE_VERSION
const DEFAULT_OPENING_INPUT_FREEZE_TICKS: int = 2 * TickRunnerScript.TICK_RATE
const DEFAULT_NETWORK_INPUT_LEAD_TICKS: int = 3

var match_id_prefix: String = "match"
var next_match_sequence: int = 1
var forced_seed: int = -1
var selected_mode_id: String = ""
var local_player_bubble_style_id: String = ""


func can_build_from_room(snapshot: RoomSnapshot) -> bool:
	if snapshot == null:
		return false
	var resolved_selection := _resolve_authoritative_selection(snapshot, null)
	if resolved_selection.is_empty():
		return false
	var binding := MapSelectionCatalogScript.get_map_binding(String(resolved_selection.get("map_id", "")))
	var required_team_count := int(binding.get("required_team_count", snapshot.min_start_players))
	if snapshot.member_count() < snapshot.min_start_players:
		return false
	if _collect_distinct_team_ids(snapshot).size() < required_team_count:
		return false
	if not snapshot.all_ready:
		return false
	if not MapCatalogScript.has_map(String(resolved_selection.get("map_id", ""))):
		return false
	if not RuleSetCatalogScript.has_rule(String(resolved_selection.get("rule_set_id", ""))):
		return false
	var resolved_mode_id := String(resolved_selection.get("mode_id", ""))
	if not ModeCatalogScript.has_mode(resolved_mode_id):
		return false
	return true


func _collect_distinct_team_ids(snapshot: RoomSnapshot) -> Array[int]:
	var team_ids: Array[int] = []
	if snapshot == null:
		return team_ids
	for member in snapshot.members:
		if member == null or member.team_id < 1:
			continue
		if not team_ids.has(member.team_id):
			team_ids.append(member.team_id)
	team_ids.sort()
	return team_ids


func build_start_config(snapshot: RoomSnapshot, room_runtime_context: RoomRuntimeContext = null) -> BattleStartConfig:
	if not can_build_from_room(snapshot):
		return BattleStartConfig.new()

	return _build_start_config_internal(snapshot, true, room_runtime_context)


func build_client_request_payload(
	snapshot: RoomSnapshot,
	local_peer_id: int,
	authority_host: String = "127.0.0.1",
	authority_port: int = 9000,
	room_runtime_context: RoomRuntimeContext = null
) -> BattleStartConfig:
	if snapshot == null:
		return BattleStartConfig.new()
	var config := _build_start_config_internal(snapshot, false, room_runtime_context)
	if config == null:
		return BattleStartConfig.new()
	config.build_mode = BattleStartConfigScript.BUILD_MODE_CANDIDATE
	config.session_mode = "network_client"
	config.topology = "dedicated_server"
	config.authority_host = authority_host
	config.authority_port = authority_port
	config.local_peer_id = local_peer_id
	config.controlled_peer_id = local_peer_id
	config.owner_peer_id = snapshot.owner_peer_id
	config.server_match_revision = 0
	config.character_loadouts = _build_character_loadouts(config.player_slots)
	config.player_bubble_loadouts = _build_player_bubble_loadouts(config.player_slots, local_peer_id)
	config.sort_players()
	return config


func build_server_canonical_config(
	snapshot: RoomSnapshot,
	authority_host: String,
	authority_port: int,
	server_match_revision: int,
	room_runtime_context: RoomRuntimeContext = null
) -> BattleStartConfig:
	if not can_build_from_room(snapshot):
		return BattleStartConfig.new()
	var config := _build_start_config_internal(snapshot, true, room_runtime_context)
	config.build_mode = BattleStartConfigScript.BUILD_MODE_CANONICAL
	config.session_mode = "network_dedicated_server"
	config.topology = "dedicated_server"
	config.authority_host = authority_host
	config.authority_port = authority_port
	config.local_peer_id = 0
	config.controlled_peer_id = 0
	config.owner_peer_id = snapshot.owner_peer_id
	config.server_match_revision = server_match_revision
	config.character_loadouts = _build_character_loadouts(config.player_slots)
	config.player_bubble_loadouts = _build_player_bubble_loadouts(config.player_slots, 0)
	config.sort_players()
	return config


func assign_spawn_slots(snapshot: RoomSnapshot) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for member in snapshot.sorted_members():
		players.append({
			"peer_id": member.peer_id,
			"player_name": member.player_name,
			"display_name": member.player_name,
			"slot_index": member.slot_index,
			"spawn_slot": member.slot_index,
			"character_id": _resolve_character_id(member.character_id),
			"character_skin_id": _resolve_character_skin_id(member.character_skin_id),
			"bubble_style_id": _resolve_member_bubble_style_id(member),
			"bubble_skin_id": _resolve_bubble_skin_id(member.bubble_skin_id),
			"team_id": member.team_id,
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
	var resolved_selection := _resolve_authoritative_selection(snapshot, room_runtime_context)
	var resolved_map_id := String(resolved_selection.get("map_id", ""))
	var resolved_rule_set_id := String(resolved_selection.get("rule_set_id", ""))
	var resolved_mode_id := String(resolved_selection.get("mode_id", ""))

	var map_metadata := _load_map_metadata(resolved_map_id)
	var rule_metadata := _load_rule_metadata(resolved_rule_set_id)
	var player_slots := assign_spawn_slots(snapshot)
	var resolved_topology := _resolve_topology(snapshot, room_runtime_context)
	var config := BattleStartConfig.new()
	config.protocol_version = DEFAULT_PROTOCOL_VERSION
	config.gameplay_rule_version = int(rule_metadata.get("version", DEFAULT_GAMEPLAY_RULE_VERSION))
	config.build_mode = BattleStartConfigScript.BUILD_MODE_CANDIDATE
	config.room_id = snapshot.room_id
	config.match_id = _resolve_match_id(snapshot, consume_match_id)
	config.map_id = resolved_map_id
	config.map_version = int(map_metadata.get("version", BattleStartConfigScript.DEFAULT_MAP_VERSION))
	config.map_content_hash = String(map_metadata.get("content_hash", ""))
	config.mode_id = resolved_mode_id
	config.rule_set_id = resolved_rule_set_id
	config.players = player_slots.duplicate(true)
	config.player_slots = player_slots.duplicate(true)
	config.spawn_assignments = _build_spawn_assignments(player_slots, map_metadata)
	config.battle_seed = generate_seed()
	config.start_tick = DEFAULT_START_TICK
	config.opening_input_freeze_ticks = DEFAULT_OPENING_INPUT_FREEZE_TICKS if resolved_topology == "dedicated_server" else 0
	config.network_input_lead_ticks = DEFAULT_NETWORK_INPUT_LEAD_TICKS if resolved_topology == "dedicated_server" else 0
	config.match_duration_ticks = _resolve_match_duration_ticks(resolved_rule_set_id)
	config.item_spawn_profile_id = String(map_metadata.get("item_spawn_profile_id", BattleStartConfigScript.DEFAULT_ITEM_SPAWN_PROFILE_ID))
	config.session_mode = _resolve_session_mode(resolved_topology)
	config.topology = resolved_topology
	config.local_peer_id = int(player_slots[0].get("peer_id", 0)) if not player_slots.is_empty() else 0
	config.controlled_peer_id = config.local_peer_id
	config.owner_peer_id = snapshot.owner_peer_id
	config.character_loadouts = _build_character_loadouts(player_slots)
	config.player_bubble_loadouts = _build_player_bubble_loadouts(
		player_slots,
		room_runtime_context.local_player_id if room_runtime_context != null else config.local_peer_id
	)
	config.sort_players()
	return config


func _resolve_match_id(snapshot: RoomSnapshot, consume_match_id: bool) -> String:
	# Dedicated-server assignment flow must preserve authoritative match_id from room snapshot.
	var authoritative_match_id := String(snapshot.current_match_id).strip_edges()
	if not authoritative_match_id.is_empty():
		return authoritative_match_id
	return _generate_match_id(snapshot) if consume_match_id else _peek_match_id(snapshot)


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


func _build_character_loadouts(player_slots: Array[Dictionary]) -> Array[Dictionary]:
	var loadouts: Array[Dictionary] = []
	for player_entry in player_slots:
		var character_id := _resolve_character_id(String(player_entry.get("character_id", "")))
		var team_id := int(player_entry.get("team_id", 0))
		var loadout := CharacterLoaderScript.build_character_loadout(
			character_id,
			int(player_entry.get("peer_id", -1))
		)
		loadout["slot_index"] = int(player_entry.get("slot_index", -1))
		loadout["team_id"] = team_id
		loadout["character_skin_id"] = _resolve_character_skin_id(String(player_entry.get("character_skin_id", "")))
		loadout["animation_set_id"] = _resolve_team_animation_set_id(character_id, team_id)
		loadouts.append(loadout)
	return loadouts


func _build_player_bubble_loadouts(player_slots: Array[Dictionary], local_peer_id: int) -> Array[Dictionary]:
	var loadouts: Array[Dictionary] = []
	for player_entry in player_slots:
		var peer_id := int(player_entry.get("peer_id", -1))
		var character_id := _resolve_character_id(String(player_entry.get("character_id", "")))
		var bubble_style_id := String(player_entry.get("bubble_style_id", "")).strip_edges()
		if not BubbleCatalogScript.has_bubble(bubble_style_id):
			bubble_style_id = _resolve_bubble_style_id(character_id, peer_id, local_peer_id)
		loadouts.append({
			"peer_id": peer_id,
			"slot_index": int(player_entry.get("slot_index", -1)),
			"team_id": int(player_entry.get("team_id", 0)),
			"bubble_style_id": bubble_style_id,
			"bubble_skin_id": _resolve_bubble_skin_id(String(player_entry.get("bubble_skin_id", ""))),
		})
	return loadouts


func _load_map_metadata(map_id: String) -> Dictionary:
	return MapLoaderScript.load_map_metadata(map_id)


func _load_rule_metadata(rule_set_id: String) -> Dictionary:
	return RuleSetCatalogScript.get_rule_metadata(rule_set_id)


func _resolve_match_duration_ticks(rule_set_id: String) -> int:
	var rule_config := _load_rule_metadata(rule_set_id)
	if rule_config.is_empty():
		return BattleStartConfigScript.DEFAULT_MATCH_DURATION_TICKS
	var round_time_sec := int(rule_config.get("round_time_sec", 0))
	if round_time_sec <= 0:
		return BattleStartConfigScript.DEFAULT_MATCH_DURATION_TICKS
	return round_time_sec * TickRunnerScript.TICK_RATE


func _resolve_character_id(character_id: String) -> String:
	if CharacterCatalogScript.has_character(character_id):
		return character_id
	return CharacterCatalogScript.get_default_character_id()


func _resolve_character_skin_id(character_skin_id: String) -> String:
	var trimmed := character_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	return trimmed


func _resolve_bubble_skin_id(bubble_skin_id: String) -> String:
	var trimmed := bubble_skin_id.strip_edges()
	if trimmed.is_empty():
		return ""
	if BubbleSkinCatalogScript.has_id(trimmed):
		return trimmed
	return ""


func _resolve_member_bubble_style_id(member: RoomMemberState) -> String:
	if member == null:
		return BubbleCatalogScript.get_default_bubble_id()
	var bubble_style_id := String(member.bubble_style_id).strip_edges()
	if BubbleCatalogScript.has_bubble(bubble_style_id):
		return bubble_style_id
	var character_id := _resolve_character_id(member.character_id)
	var character_metadata := CharacterLoaderScript.build_character_metadata(character_id)
	var default_bubble_style_id := String(character_metadata.get("default_bubble_style_id", ""))
	if BubbleCatalogScript.has_bubble(default_bubble_style_id):
		return default_bubble_style_id
	return BubbleCatalogScript.get_default_bubble_id()


func _resolve_team_animation_set_id(character_id: String, team_id: int) -> String:
	var character_presentation := CharacterLoaderScript.load_character_presentation(character_id)
	if character_presentation == null:
		return ""
	var animation_set_id := String(character_presentation.animation_set_id)
	return CharacterTeamAnimationResolverScript.resolve_animation_set_id(animation_set_id, team_id, false)


func _resolve_authoritative_selection(snapshot: RoomSnapshot, room_runtime_context: RoomRuntimeContext = null) -> Dictionary:
	var resolved_map_id := ""
	if snapshot != null and not String(snapshot.selected_map_id).is_empty():
		resolved_map_id = String(snapshot.selected_map_id)
	elif room_runtime_context != null and not String(room_runtime_context.selected_map_id).is_empty():
		resolved_map_id = String(room_runtime_context.selected_map_id)
	if resolved_map_id.is_empty():
		return {}
	var binding := MapSelectionCatalogScript.get_map_binding(resolved_map_id)
	var binding_mode_id := String(binding.get("bound_mode_id", ""))
	var binding_rule_set_id := String(binding.get("bound_rule_set_id", ""))
	var snapshot_mode_id := String(snapshot.mode_id) if snapshot != null else ""
	var snapshot_rule_set_id := String(snapshot.rule_set_id) if snapshot != null else ""
	var context_mode_id := String(room_runtime_context.mode_id) if room_runtime_context != null else ""
	var context_rule_set_id := String(room_runtime_context.selected_rule_set_id) if room_runtime_context != null else ""
	var resolved_mode_id := binding_mode_id
	var resolved_rule_set_id := binding_rule_set_id
	if resolved_mode_id.is_empty():
		resolved_mode_id = snapshot_mode_id if ModeCatalogScript.has_mode(snapshot_mode_id) else context_mode_id
	if resolved_rule_set_id.is_empty():
		resolved_rule_set_id = snapshot_rule_set_id if RuleSetCatalogScript.has_rule(snapshot_rule_set_id) else context_rule_set_id
	if not binding.is_empty() and bool(binding.get("valid", false)):
		if not snapshot_rule_set_id.is_empty() and snapshot_rule_set_id != resolved_rule_set_id:
			LogNetScript.warn(
				"BattleStartConfigBuilder: rule mismatch map=%s snapshot=%s authoritative=%s" % [
					resolved_map_id,
					snapshot_rule_set_id,
					resolved_rule_set_id,
				],
				"",
				0,
				"net.match_start.config"
			)
		if not snapshot_mode_id.is_empty() and snapshot_mode_id != resolved_mode_id:
			LogNetScript.warn(
				"BattleStartConfigBuilder: mode mismatch map=%s snapshot=%s authoritative=%s" % [
					resolved_map_id,
					snapshot_mode_id,
					resolved_mode_id,
				],
				"",
				0,
				"net.match_start.config"
			)
	return {
		"map_id": resolved_map_id,
		"mode_id": resolved_mode_id,
		"rule_set_id": resolved_rule_set_id,
	}


func _resolve_topology(snapshot: RoomSnapshot, room_runtime_context: RoomRuntimeContext = null) -> String:
	if snapshot != null:
		var snapshot_topology := String(snapshot.topology)
		if snapshot_topology == "local" or snapshot_topology == "dedicated_server":
			return snapshot_topology
	if room_runtime_context != null:
		var context_topology := String(room_runtime_context.topology)
		if context_topology == "local" or context_topology == "dedicated_server":
			return context_topology
	return "local"


func _resolve_session_mode(topology: String) -> String:
	if topology == "dedicated_server":
		return "online_room"
	return "singleplayer_local"


func _resolve_bubble_style_id(character_id: String, peer_id: int, local_peer_id: int) -> String:
	if peer_id == local_peer_id and BubbleCatalogScript.has_bubble(local_player_bubble_style_id):
		return local_player_bubble_style_id
	var character_metadata := CharacterLoaderScript.build_character_metadata(character_id)
	var default_bubble_style_id := String(character_metadata.get("default_bubble_style_id", ""))
	if BubbleCatalogScript.has_bubble(default_bubble_style_id):
		return default_bubble_style_id
	return BubbleCatalogScript.get_default_bubble_id()
