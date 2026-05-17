## DEV ONLY: Quick launcher for battle testing without going through
## lobby -> room -> matchmaking -> loading flow.
##
## Supports two modes:
##   LOCAL_LOOPBACK (default): Everything in one process. Fastest iteration.
##   DS_CLIENT: Connect to a dev-mode dedicated server for network testing.
##
## Usage:
##   Godot --path . res://scenes/dev/dev_battle_launcher.tscn
##   Godot --path . res://scenes/dev/dev_battle_launcher.tscn -- --qqt-dev-launcher-ds-addr 127.0.0.1 --qqt-dev-launcher-ds-port 9000
##   Godot --path . res://scenes/dev/dev_battle_launcher.tscn -- --qqt-dev-launcher-map-id map_ice_world

class_name DevBattleLauncher
extends Node2D

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const RuntimeLifecycleStateScript = preload("res://app/flow/runtime_lifecycle_state.gd")
const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const LogSystemInitializerScript = preload("res://app/logging/log_system_initializer.gd")
const BattleEntryContextScript = preload("res://app/front/battle/battle_entry_context.gd")
const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")

const BATTLE_SCENE_PATH := "res://scenes/battle/battle_main.tscn"
const LOG_PREFIX := "[dev_launcher]"
const RANDOM_CHARACTER_ID := "12301"

enum LaunchMode {
	LOCAL_LOOPBACK,
	DS_CLIENT,
}

var launch_mode: int = LaunchMode.LOCAL_LOOPBACK
var _app_runtime: Node = null
var _session_adapter: Node = null
var _config: BattleStartConfig = null
var _battle_scene: Node = null
var _player_count: int = 2
var _team_count: int = 2
var _map_id_override: String = ""
var _rule_set_id_override: String = ""
var _ds_address: String = "127.0.0.1"
var _ds_port: int = 9000
var _battle_id: String = "dev_battle_local"


func _ready() -> void:
	LogSystemInitializerScript.initialize_client()
	_parse_command_line()
	_log("Dev Battle Launcher starting mode=%d player_count=%d team_count=%d" % [launch_mode, _player_count, _team_count])
	_print_available_maps()

	match launch_mode:
		LaunchMode.LOCAL_LOOPBACK:
			_start_local_loopback()
		LaunchMode.DS_CLIENT:
			_start_ds_client()
		_:
			_log("Unknown launch mode, defaulting to local loopback")
			_start_local_loopback()


func _start_local_loopback() -> void:
	_setup_app_runtime()

	# Enable AI debug input for non-player peers by default in dev mode.
	# Toggle with 'O' key during battle.
	_session_adapter.use_remote_debug_inputs = true

	_config = _build_local_loopback_config()
	_session_adapter.setup_from_start_config(_config)
	_app_runtime.battle_session_adapter = _session_adapter
	_app_runtime.apply_canonical_start_config(_config)

	_log("Local loopback battle ready. Controls: Arrows=move Space=bomb O=toggle_AI J=latency K=loss")
	_log("Map: %s  Mode: %s  Rule: %s" % [_config.map_id, _config.mode_id, _config.rule_set_id])
	_instance_battle_scene()


func _start_ds_client() -> void:
	_setup_app_runtime()

	_config = _build_ds_client_config()
	_session_adapter.setup_from_start_config(_config)
	_app_runtime.battle_session_adapter = _session_adapter
	_app_runtime.apply_canonical_start_config(_config)

	# Build a dev BattleEntryContext so the network gateway can send
	# BATTLE_ENTRY_REQUEST when the transport connects to the DS.
	# The DS in --qqt-dev-mode accepts any ticket.
	var entry_ctx := BattleEntryContextScript.new()
	entry_ctx.battle_id = _config.battle_id
	entry_ctx.match_id = _config.match_id
	entry_ctx.map_id = _config.map_id
	entry_ctx.mode_id = _config.mode_id
	entry_ctx.rule_set_id = _config.rule_set_id
	entry_ctx.battle_server_host = _ds_address
	entry_ctx.battle_server_port = _ds_port
	entry_ctx.battle_ticket = "dev_ticket"
	entry_ctx.battle_ticket_id = "dev_ticket_1"
	entry_ctx.source_room_id = "dev_room_ds"
	_app_runtime.current_battle_entry_context = entry_ctx

	# Provide a minimal AuthSessionState for device_session_id in the entry request.
	var auth_state := AuthSessionStateScript.new()
	auth_state.device_session_id = "dev_session_1"
	_app_runtime.auth_session_state = auth_state

	_log("DS client connecting to %s:%d battle_id=%s" % [_ds_address, _ds_port, _config.battle_id])
	_log("Controls: Arrows=move Space=bomb F3=debug J=latency K=loss L=rollback O=toggle_remote_AI(dev_only)")
	_instance_battle_scene()
	# ------------------------------------------------------------------
	# DEV MODE ONLY: Mount the dev DS AI toggle helper so the O key in
	# DS_CLIENT mode can pause/resume the server-side AI drivers.
	# The helper only runs while this dev launcher is alive and is never
	# referenced by production scenes / flows.
	# ------------------------------------------------------------------
	var DevDsAiToggleScript := load("res://scenes/dev/dev_ds_ai_toggle.gd")
	if DevDsAiToggleScript != null:
		var toggle_node: Node = DevDsAiToggleScript.new()
		toggle_node.name = "DevDsAiToggle"
		add_child(toggle_node)
		toggle_node.configure(_session_adapter)
	# ------------------------------------------------------------------
	# END DEV MODE ONLY
	# ------------------------------------------------------------------


func _setup_app_runtime() -> void:
	# Create minimal AppRuntimeRoot without full initialization flow.
	# Must be a direct child of the tree root because battle_main_controller
	# uses AppRuntimeRootScript.get_existing() which only checks root's children.
	# Uses call_deferred because _ready() runs during tree setup and the root
	# won't accept synchronous add_child.
	_app_runtime = AppRuntimeRootScript.new()
	_app_runtime.name = "AppRoot"
	_app_runtime.runtime_lifecycle_state = RuntimeLifecycleStateScript.Value.READY
	_app_runtime.local_peer_id = 1

	# Create session adapter (children can be added before entering tree).
	_session_adapter = BattleSessionAdapterScript.new()
	_session_adapter.name = "BattleSessionAdapter"
	var session_root := Node.new()
	session_root.name = "SessionRoot"
	_app_runtime.add_child(session_root)
	session_root.add_child(_session_adapter)

	# Defer adding to root so it happens after current _ready() phase completes.
	get_tree().root.add_child.call_deferred(_app_runtime)


func _instance_battle_scene() -> void:
	var battle_resource := load(BATTLE_SCENE_PATH)
	if battle_resource == null:
		_log("ERROR: Failed to load battle scene: %s" % BATTLE_SCENE_PATH)
		return
	_battle_scene = battle_resource.instantiate()
	_battle_scene.name = "BattleMain"
	add_child(_battle_scene)
	_log("Battle scene instantiated")


func _build_local_loopback_config() -> BattleStartConfig:
	var map_id := _resolve_map_id()
	var map_metadata := MapLoaderScript.load_map_metadata(map_id)
	var resolved_team_count := _resolve_team_count()

	# Resolve mode and rule set from map binding (authoritative), with CLI override support.
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	var mode_id := String(binding.get("bound_mode_id", ""))
	var rule_set_id := String(binding.get("bound_rule_set_id", ""))
	if _rule_set_id_override.is_empty() and rule_set_id.is_empty():
		rule_set_id = RuleSetCatalogScript.get_default_rule_id()
	elif not _rule_set_id_override.is_empty():
		rule_set_id = _rule_set_id_override
		# Try to resolve mode from the override rule set's default mode
		var fallback_mode_id := ModeCatalogScript.get_default_mode_id()
		if mode_id.is_empty() or not ModeCatalogScript.has_mode(mode_id):
			mode_id = fallback_mode_id

	var rule_metadata := RuleSetCatalogScript.get_rule_metadata(rule_set_id)

	# All players use the random placeholder character (12301).
	# The resolution below assigns different random characters per player.
	var player_slots: Array[Dictionary] = []
	for i in range(_player_count):
		player_slots.append({
			"peer_id": i + 1,
			"player_name": "Player%d" % (i + 1),
			"display_name": "Player%d" % (i + 1),
			"slot_index": i,
			"spawn_slot": i,
			"team_id": (i % resolved_team_count) + 1,
			"character_id": RANDOM_CHARACTER_ID,
			"bubble_style_id": BubbleCatalogScript.get_default_bubble_id(),
		})

	# Resolve random placeholder characters — uses the same logic as
	# BattleStartConfigBuilder._resolve_random_placeholder_player_slots().
	var battle_seed := int(Time.get_unix_time_from_system())
	_resolve_random_characters(player_slots, battle_seed)

	# Build spawn assignments from map spawn points.
	var spawn_assignments: Array[Dictionary] = []
	var spawn_points: Array = map_metadata.get("spawn_points", [])
	for i in range(player_slots.size()):
		var spawn_point: Vector2i = spawn_points[i] if i < spawn_points.size() and spawn_points[i] is Vector2i else Vector2i(i + 1, i + 1)
		spawn_assignments.append({
			"peer_id": int(player_slots[i].get("peer_id", i + 1)),
			"slot_index": int(player_slots[i].get("slot_index", i)),
			"spawn_index": i,
			"spawn_cell_x": spawn_point.x,
			"spawn_cell_y": spawn_point.y,
		})

	# Build character loadouts (after random resolution).
	var character_loadouts: Array[Dictionary] = []
	for player_entry in player_slots:
		character_loadouts.append(
			CharacterLoaderScript.build_character_loadout(
				String(player_entry.get("character_id", CharacterCatalogScript.get_default_character_id())),
				int(player_entry.get("peer_id", -1))
			)
		)

	var round_time_sec := int(rule_metadata.get("round_time_sec", 180))

	var config := BattleStartConfigScript.new()
	config.room_id = "dev_room_local"
	config.battle_id = _battle_id
	config.match_id = "dev_match_local"
	config.map_id = map_id
	config.map_version = int(map_metadata.get("version", BattleStartConfigScript.DEFAULT_MAP_VERSION))
	config.map_content_hash = String(map_metadata.get("content_hash", ""))
	config.mode_id = mode_id
	config.rule_set_id = rule_set_id
	config.players = player_slots.duplicate(true)
	config.player_slots = player_slots.duplicate(true)
	config.spawn_assignments = spawn_assignments
	config.battle_seed = battle_seed
	config.start_tick = 0
	config.match_duration_ticks = max(round_time_sec * TickRunnerScript.TICK_RATE, 60)
	config.opening_input_freeze_ticks = 2 * TickRunnerScript.TICK_RATE
	config.network_input_lead_ticks = 3
	config.item_spawn_profile_id = String(map_metadata.get("item_spawn_profile_id", BattleStartConfigScript.DEFAULT_ITEM_SPAWN_PROFILE_ID))
	config.session_mode = "singleplayer_local"
	config.topology = "listen"
	config.authority_host = "127.0.0.1"
	config.authority_port = 0
	config.local_peer_id = 1
	config.controlled_peer_id = 1
	config.owner_peer_id = 1
	config.character_loadouts = character_loadouts
	config.player_bubble_loadouts = _build_dev_bubble_loadouts(player_slots)
	config.sort_players()
	return config


func _build_ds_client_config() -> BattleStartConfig:
	var config := _build_local_loopback_config()
	config.session_mode = "network_client"
	config.topology = "dedicated_server"
	config.authority_host = _ds_address
	config.authority_port = _ds_port
	config.local_peer_id = 1
	config.controlled_peer_id = 1
	config.owner_peer_id = 1
	return config


func _resolve_map_id() -> String:
	if not _map_id_override.is_empty():
		if MapCatalogScript.has_map(_map_id_override):
			return _map_id_override
		_log("WARNING: Map '%s' not found, using default" % _map_id_override)
	return MapCatalogScript.get_default_map_id()


func _resolve_random_characters(player_slots: Array[Dictionary], battle_seed: int) -> void:
	var random_pool := CharacterCatalogScript.get_random_battle_character_ids()
	if random_pool.is_empty():
		_log("WARNING: No random battle characters available, keeping placeholder IDs")
		return
	for player_entry in player_slots:
		var requested_id := String(player_entry.get("character_id", "")).strip_edges()
		if not CharacterCatalogScript.is_random_placeholder_character(requested_id):
			continue
		var peer_id := int(player_entry.get("peer_id", -1))
		var slot_index := int(player_entry.get("slot_index", -1))
		var seed_text := "%d:%d:%d" % [battle_seed, peer_id, slot_index]
		var rng := RandomNumberGenerator.new()
		rng.seed = abs(seed_text.hash())
		var resolved_id := random_pool[rng.randi_range(0, random_pool.size() - 1)]
		player_entry["random_placeholder_character_id"] = requested_id
		player_entry["character_id"] = resolved_id
		_log("  Player %d (slot %d): random character %s" % [peer_id, slot_index, resolved_id])


func _build_dev_bubble_loadouts(player_slots: Array[Dictionary]) -> Array[Dictionary]:
	var loadouts: Array[Dictionary] = []
	for player_entry in player_slots:
		var peer_id := int(player_entry.get("peer_id", -1))
		var character_id := String(player_entry.get("character_id", ""))
		var bubble_style_id := String(player_entry.get("bubble_style_id", BubbleCatalogScript.get_default_bubble_id()))
		# Resolve default bubble from character metadata if the set one isn't valid.
		if not BubbleCatalogScript.has_bubble(bubble_style_id):
			var char_meta := CharacterLoaderScript.build_character_metadata(character_id)
			var char_default_bubble := String(char_meta.get("default_bubble_style_id", ""))
			if BubbleCatalogScript.has_bubble(char_default_bubble):
				bubble_style_id = char_default_bubble
			else:
				bubble_style_id = BubbleCatalogScript.get_default_bubble_id()
		loadouts.append({
			"peer_id": peer_id,
			"bubble_style_id": bubble_style_id,
		})
	return loadouts


func _print_available_maps() -> void:
	var map_ids := MapCatalogScript.get_map_ids()
	if map_ids.is_empty():
		return
	_log("Available maps (%d):" % map_ids.size())
	for map_id in map_ids:
		var binding := MapSelectionCatalogScript.get_map_binding(map_id)
		var metadata := MapCatalogScript.get_map_metadata(map_id)
		var display_name := String(metadata.get("display_name", map_id))
		var bound_mode := String(binding.get("bound_mode_id", "?"))
		var active_marker := ""
		if not _map_id_override.is_empty() and map_id == _map_id_override:
			active_marker = "  <-- SELECTED"
		elif _map_id_override.is_empty() and map_id == MapCatalogScript.get_default_map_id():
			active_marker = "  (default)"
		_log("  %s | %s | mode=%s%s" % [map_id, display_name, bound_mode, active_marker])


func _parse_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	var parsed: Dictionary = {}
	for index in range(args.size()):
		var arg := String(args[index])
		if arg.begins_with("--qqt-dev-launcher-") and arg.contains("="):
			var eq_pos := arg.find("=")
			parsed[arg.substr(0, eq_pos)] = arg.substr(eq_pos + 1)
		elif arg.begins_with("--qqt-dev-launcher-") and index + 1 < args.size():
			parsed[arg] = String(args[index + 1])

	if parsed.has("--qqt-dev-launcher-ds-addr"):
		_ds_address = String(parsed["--qqt-dev-launcher-ds-addr"]).strip_edges()
		launch_mode = LaunchMode.DS_CLIENT
	if parsed.has("--qqt-dev-launcher-ds-port"):
		_ds_port = int(String(parsed["--qqt-dev-launcher-ds-port"]).to_int())
		launch_mode = LaunchMode.DS_CLIENT
	if parsed.has("--qqt-dev-launcher-player-count"):
		var pc := int(String(parsed["--qqt-dev-launcher-player-count"]).to_int())
		if pc >= 1:
			_player_count = pc
	if parsed.has("--qqt-dev-launcher-team-count"):
		var tc := int(String(parsed["--qqt-dev-launcher-team-count"]).to_int())
		if tc >= 2:
			_team_count = tc
	if parsed.has("--qqt-dev-launcher-map-id"):
		_map_id_override = String(parsed["--qqt-dev-launcher-map-id"]).strip_edges()
	if parsed.has("--qqt-dev-launcher-rule-set-id"):
		_rule_set_id_override = String(parsed["--qqt-dev-launcher-rule-set-id"]).strip_edges()
	if parsed.has("--qqt-dev-launcher-battle-id"):
		_battle_id = String(parsed["--qqt-dev-launcher-battle-id"]).strip_edges()


func _resolve_team_count() -> int:
	var clamped_player_count: int = max(_player_count, 1)
	if clamped_player_count < 2:
		return 1
	return clampi(_team_count, 2, clamped_player_count)


func _log(message: String) -> void:
	print("%s%s %s" % [LOG_PREFIX, "" if message.is_empty() else "", message])
