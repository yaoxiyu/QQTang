extends RefCounted

const BattleContentManifestBuilderScript = preload("res://gameplay/battle/config/battle_content_manifest_builder.gd")
const BattleRuntimeConfigBuilderScript = preload("res://gameplay/battle/runtime/battle_runtime_config_builder.gd")
const ExplosionActorViewScript = preload("res://presentation/battle/actors/explosion_actor_view.gd")
const BattlePlayerVisualProfileBuilderScript = preload("res://presentation/battle/actors/battle_player_visual_profile_builder.gd")
const RoomSelectionStateScript = preload("res://gameplay/front/room_selection/room_selection_state.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const RoomTeamPaletteScript = preload("res://app/front/room/room_team_palette.gd")
const ItemSpawnSystemScript = preload("res://gameplay/simulation/systems/item_spawn_system.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const ONLINE_LOG_PREFIX := "[QQT_ONLINE]"

var _content_manifest_builder = BattleContentManifestBuilderScript.new()
var _battle_runtime_config_builder = BattleRuntimeConfigBuilderScript.new()
var _battle_player_visual_profile_builder = BattlePlayerVisualProfileBuilderScript.new()
var _runtime_config_cache_key: String = ""
var _runtime_config_cache: BattleRuntimeConfig = null


func consume_authoritative_tick(
	app_runtime: Node,
	battle_context: BattleContext,
	presentation_bridge: Node,
	battle_hud: Node,
	tick_result: Dictionary,
	metrics: Dictionary
) -> void:
	if battle_context == null or battle_context.sim_world == null:
		return
	var local_player_entity_id := resolve_local_player_entity_id(app_runtime, battle_context)
	presentation_bridge.set_local_player_entity_id(local_player_entity_id)
	battle_hud.set_local_player_entity_id(local_player_entity_id)
	presentation_bridge.consume_tick_result(tick_result, battle_context.sim_world, tick_result.get("events", []))
	battle_hud.consume_battle_state(battle_context.sim_world)
	battle_hud.consume_network_metrics(metrics)


func initialize_battle_context(
	app_runtime: Node,
	battle_context: BattleContext,
	session_adapter: Node,
	battle_bootstrap: Node,
	presentation_bridge: Node,
	battle_hud: Node,
	battle_camera_controller: Node,
	map_theme_environment_controller: Node,
	map_root: Node,
	reveal_initial_frame: bool = true
) -> void:
	if battle_context == null:
		return
	if app_runtime != null and app_runtime.current_start_config == null and battle_context.battle_start_config != null:
		app_runtime.apply_canonical_start_config(battle_context.battle_start_config)
	var resolved_manifest: Dictionary = {}
	if app_runtime != null and not app_runtime.current_battle_content_manifest.is_empty():
		resolved_manifest = app_runtime.current_battle_content_manifest.duplicate(true)
	elif battle_context.battle_start_config != null:
		resolved_manifest = _content_manifest_builder.build_for_start_config(battle_context.battle_start_config)
	battle_context.battle_content_manifest = resolved_manifest
	battle_bootstrap.bind_context(battle_context)
	if app_runtime != null and app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("mark_match_started"):
		var match_id: String = app_runtime.current_start_config.match_id if app_runtime.current_start_config != null else ""
		app_runtime.room_session_controller.mark_match_started(match_id)
	battle_camera_controller.configure_from_world(battle_context.sim_world, presentation_bridge.cell_size)
	apply_content_style_overrides(app_runtime, presentation_bridge)
	apply_player_visual_profiles(app_runtime, presentation_bridge)
	apply_player_list_panel_config(app_runtime, battle_hud)
	apply_map_theme(app_runtime, presentation_bridge, map_theme_environment_controller, map_root)
	var local_player_entity_id := resolve_local_player_entity_id(app_runtime, battle_context)
	presentation_bridge.set_local_player_entity_id(local_player_entity_id)
	battle_hud.set_local_player_entity_id(local_player_entity_id)
	apply_battle_metadata(app_runtime, battle_context, battle_hud, null, null, null, null, null, null)
	if reveal_initial_frame:
		presentation_bridge.consume_tick_result({}, battle_context.sim_world, [])
		battle_hud.consume_battle_state(battle_context.sim_world)
		if session_adapter != null:
			battle_hud.consume_network_metrics(session_adapter.build_runtime_metrics_snapshot())
		battle_hud.match_message_panel.apply_message(
			"J Latency  K Loss  L ForceRollback  I DropRate %d%%  O RemoteDebug %s" % [
				ItemSpawnSystemScript.get_debug_drop_rate_percent(),
				"On" if session_adapter != null and session_adapter.use_remote_debug_inputs else "Off"
			]
		)


func apply_battle_metadata(
	app_runtime: Node,
	battle_context: BattleContext,
	battle_hud: Node,
	battle_meta_panel: Node,
	battle_meta_map_label: Label,
	battle_meta_rule_label: Label,
	battle_meta_match_label: Label,
	battle_meta_character_label: Label,
	battle_meta_bubble_label: Label
) -> void:
	if battle_hud == null:
		return
	var resolved_start_config: BattleStartConfig = null
	if battle_context != null and battle_context.battle_start_config != null:
		resolved_start_config = battle_context.battle_start_config
	elif app_runtime != null and app_runtime.current_start_config != null:
		resolved_start_config = app_runtime.current_start_config
	if resolved_start_config == null:
		return
	var manifest: Dictionary = {}
	if battle_context != null and not battle_context.battle_content_manifest.is_empty():
		manifest = battle_context.battle_content_manifest
	elif app_runtime != null and not app_runtime.current_battle_content_manifest.is_empty():
		manifest = app_runtime.current_battle_content_manifest
	if manifest.is_empty():
		manifest = _content_manifest_builder.build_for_start_config(resolved_start_config)
		if battle_context != null:
			battle_context.battle_content_manifest = manifest.duplicate(true)
	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	var local_character_display_name := _resolve_local_character_display_name(app_runtime, manifest, resolved_start_config)
	var local_bubble_display_name := _resolve_local_bubble_display_name(app_runtime, manifest, resolved_start_config)
	var mode_display_name := String(ui_summary.get("mode_display_name", resolved_start_config.mode_id))
	var match_meta_text := "模式: %s | Match: %s | Profile: %s" % [
		mode_display_name,
		String(resolved_start_config.match_id),
		String(ui_summary.get("item_profile_id", resolved_start_config.item_spawn_profile_id)),
	]
	var item_brief := String(ui_summary.get("item_brief", ""))
	if not item_brief.is_empty():
		match_meta_text = "%s | %s" % [match_meta_text, item_brief]
	battle_hud.set_extended_battle_metadata(
		String(ui_summary.get("map_display_name", resolved_start_config.map_id)),
		String(ui_summary.get("rule_display_name", resolved_start_config.rule_set_id)),
		match_meta_text,
		local_character_display_name,
		local_bubble_display_name
	)
	var resolved_map_display_name := String(ui_summary.get("map_display_name", resolved_start_config.map_id))
	var resolved_rule_display_name := String(ui_summary.get("rule_display_name", resolved_start_config.rule_set_id))
	if battle_meta_panel != null:
		battle_meta_panel.apply_extended_metadata(
			resolved_map_display_name,
			resolved_rule_display_name,
			match_meta_text,
			local_character_display_name,
			local_bubble_display_name
		)
	if battle_meta_map_label != null:
		battle_meta_map_label.text = "地图: %s" % resolved_map_display_name
	if battle_meta_rule_label != null:
		battle_meta_rule_label.text = "规则: %s" % resolved_rule_display_name
	if battle_meta_match_label != null:
		battle_meta_match_label.text = match_meta_text
	if battle_meta_character_label != null:
		battle_meta_character_label.text = "角色: %s" % local_character_display_name
	if battle_meta_bubble_label != null:
		battle_meta_bubble_label.text = "泡泡: %s" % local_bubble_display_name


func apply_content_style_overrides(app_runtime: Node, presentation_bridge: Node) -> void:
	if presentation_bridge == null or app_runtime == null or app_runtime.current_start_config == null:
		return
	var player_style_by_slot: Dictionary = {}
	var bubble_style_by_slot: Dictionary = {}
	var bubble_color_by_slot: Dictionary = {}
	for loadout in app_runtime.current_start_config.character_loadouts:
		var peer_id := int(loadout.get("peer_id", -1))
		var slot_index := _find_slot_index_for_peer(app_runtime, peer_id)
		if slot_index < 0:
			continue
		var team_id := _find_team_id_for_peer(app_runtime, peer_id)
		player_style_by_slot[slot_index] = RoomTeamPaletteScript.color_for_team(team_id)
	for loadout in app_runtime.current_start_config.player_bubble_loadouts:
		var peer_id := int(loadout.get("peer_id", -1))
		var slot_index := _find_slot_index_for_peer(app_runtime, peer_id)
		if slot_index < 0:
			continue
		var bubble_style_id := String(loadout.get("bubble_style_id", ""))
		var team_id := _find_team_id_for_peer(app_runtime, peer_id)
		bubble_style_by_slot[slot_index] = bubble_style_id
		bubble_color_by_slot[slot_index] = RoomTeamPaletteScript.color_for_team(team_id).lightened(0.1)
	presentation_bridge.configure_content_styles(player_style_by_slot, bubble_style_by_slot, bubble_color_by_slot)


func apply_player_visual_profiles(app_runtime: Node, presentation_bridge: Node) -> void:
	if presentation_bridge == null or app_runtime == null:
		return
	var start_config: BattleStartConfig = app_runtime.current_start_config
	if start_config == null:
		return
	var room_snapshot := _resolve_battle_room_snapshot(app_runtime, start_config)
	if room_snapshot == null:
		return
	var runtime_config := _get_runtime_config(app_runtime, start_config, room_snapshot)
	if runtime_config == null:
		return
	var player_visual_profiles := _battle_player_visual_profile_builder.build(runtime_config, start_config.player_slots)
	LogFrontScript.debug(
		"%s[battle_scene] player_visual_profiles_applied room_id=%s room_members=%d start_players=%d profiles=%d" % [
			ONLINE_LOG_PREFIX,
			String(room_snapshot.room_id),
			room_snapshot.member_count(),
			start_config.player_slots.size(),
			player_visual_profiles.size(),
		],
		"",
		0,
		"front.battle.scene"
	)
	presentation_bridge.configure_player_visual_profiles(player_visual_profiles)
	var player_name_by_slot: Dictionary = {}
	for entry in start_config.player_slots:
		var slot_idx := int(entry.get("slot_index", -1))
		if slot_idx < 0:
			continue
		player_name_by_slot[slot_idx] = String(entry.get("player_name", entry.get("display_name", "")))
	if presentation_bridge.has_method("configure_player_names_by_slot"):
		presentation_bridge.configure_player_names_by_slot(player_name_by_slot)
	var character_gender_by_slot: Dictionary = {}
	for entry in start_config.player_slots:
		var slot_idx2 := int(entry.get("slot_index", -1))
		if slot_idx2 < 0:
			continue
		var character_id := String(entry.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			continue
		var meta := CharacterCatalogScript.get_character_metadata(character_id)
		var character_gender := String(meta.get("gender", "male")).strip_edges().to_lower()
		if character_gender != "female":
			character_gender = "male"
		character_gender_by_slot[slot_idx2] = character_gender
	if presentation_bridge.has_method("configure_character_gender_by_slot"):
		presentation_bridge.configure_character_gender_by_slot(character_gender_by_slot)


func apply_player_list_panel_config(app_runtime: Node, battle_hud: Node) -> void:
	if battle_hud == null or not battle_hud.has_method("configure_player_list_panel"):
		return
	var start_config: BattleStartConfig = app_runtime.current_start_config if app_runtime != null else null
	if start_config == null:
		return
	var rule_set_def := RuleSetCatalogScript.get_by_id(String(start_config.rule_set_id))
	var show_score := false
	if rule_set_def != null:
		show_score = bool(rule_set_def.show_score)
	var room_snapshot := _resolve_battle_room_snapshot(app_runtime, start_config)
	if room_snapshot == null:
		return
	var runtime_config := _get_runtime_config(app_runtime, start_config, room_snapshot)
	if runtime_config == null:
		return
	var player_visual_profiles := _battle_player_visual_profile_builder.build(runtime_config, start_config.player_slots)
	var player_names: Array[String] = []
	player_names.resize(8)
	player_names.fill("")
	for entry in start_config.player_slots:
		var slot_idx: int = int(entry.get("slot_index", -1))
		var slot_0 := slot_idx
		if slot_0 >= 8:
			slot_0 = slot_idx - 1
		if slot_0 < 0 or slot_0 >= 8:
			continue
		var name_str: String = String(entry.get("player_name", entry.get("display_name", "")))
		player_names[slot_0] = name_str
	battle_hud.configure_player_list_panel(show_score, player_visual_profiles, player_names)


func apply_map_theme(app_runtime: Node, presentation_bridge: Node, map_theme_environment_controller: Node, map_root: Node) -> void:
	if app_runtime == null:
		return
	var start_config: BattleStartConfig = app_runtime.current_start_config
	if start_config == null:
		return
	var room_snapshot := _resolve_battle_room_snapshot(app_runtime, start_config)
	if room_snapshot == null:
		return
	var map_runtime_layout := MapLoaderScript.load_runtime_layout(String(start_config.map_id))
	var runtime_config := _get_runtime_config(app_runtime, start_config, room_snapshot)
	if runtime_config == null or runtime_config.map_theme == null:
		return
	if presentation_bridge != null and map_runtime_layout != null:
		presentation_bridge.configure_map_presentation(map_runtime_layout, runtime_config.map_theme)
		ExplosionActorViewScript.prewarm_segment_textures()
	if map_theme_environment_controller != null:
		map_theme_environment_controller.apply_map_theme(runtime_config.map_theme)
	if map_root != null:
		map_root.apply_map_theme(runtime_config.map_theme)


func _get_runtime_config(app_runtime: Node, start_config: BattleStartConfig, room_snapshot: RoomSnapshot) -> BattleRuntimeConfig:
	var cache_key := _build_runtime_config_cache_key(app_runtime, start_config, room_snapshot)
	if _runtime_config_cache != null and cache_key == _runtime_config_cache_key:
		return _runtime_config_cache
	var room_selection_state := _build_room_selection_state_from_snapshot(room_snapshot, start_config)
	var runtime_config := _battle_runtime_config_builder.build(room_selection_state)
	_runtime_config_cache_key = cache_key
	_runtime_config_cache = runtime_config
	return runtime_config


func _build_runtime_config_cache_key(app_runtime: Node, start_config: BattleStartConfig, room_snapshot: RoomSnapshot) -> String:
	var parts := PackedStringArray()
	parts.append(String(start_config.map_id))
	parts.append(String(start_config.mode_id))
	parts.append(String(start_config.rule_set_id))
	for member in room_snapshot.sorted_members():
		if member == null:
			continue
		parts.append("%d:%d:%d:%s:%s" % [
			int(member.peer_id),
			int(member.slot_index),
			int(member.team_id),
			String(member.character_id),
			String(member.bubble_style_id),
		])
	return "|".join(parts)


func resolve_local_player_entity_id(app_runtime: Node, battle_context: BattleContext) -> int:
	if battle_context == null or battle_context.sim_world == null or app_runtime == null or app_runtime.current_start_config == null:
		return -1
	var controlled_peer_id := int(app_runtime.current_start_config.controlled_peer_id)
	if controlled_peer_id <= 0:
		controlled_peer_id = app_runtime.local_peer_id
	for player_entry in app_runtime.current_start_config.players:
		if int(player_entry.get("peer_id", -1)) != controlled_peer_id:
			continue
		var slot_index: int = int(player_entry.get("slot_index", -1))
		for player_id in range(battle_context.sim_world.state.players.size()):
			var player: PlayerState = battle_context.sim_world.state.players.get_player(player_id)
			if player != null and player.player_slot == slot_index:
				return player.entity_id
	return -1


func build_start_config_from_battle_entry(ctx: BattleEntryContext) -> BattleStartConfig:
	var config := BattleStartConfig.new()
	config.session_mode = "network_client"
	config.topology = "dedicated_server"
	config.authority_host = ctx.battle_server_host
	config.authority_port = ctx.battle_server_port
	config.battle_id = ctx.battle_id
	config.match_id = ctx.match_id
	config.map_id = ctx.map_id
	config.mode_id = ctx.mode_id
	config.rule_set_id = ctx.rule_set_id
	config.room_id = ctx.source_room_id
	config.build_mode = BattleStartConfig.BUILD_MODE_CANONICAL
	return config


func _resolve_battle_room_snapshot(app_runtime: Node, start_config: BattleStartConfig) -> RoomSnapshot:
	if start_config == null:
		return null
	var current_snapshot: RoomSnapshot = app_runtime.current_room_snapshot if app_runtime != null else null
	if _snapshot_covers_start_config_players(current_snapshot, start_config):
		return current_snapshot
	return _build_fallback_room_snapshot_from_start_config(start_config)


func _snapshot_covers_start_config_players(snapshot: RoomSnapshot, start_config: BattleStartConfig) -> bool:
	if snapshot == null or start_config == null:
		return false
	var member_peer_ids: Dictionary = {}
	for member in snapshot.members:
		if member == null:
			continue
		member_peer_ids[int(member.peer_id)] = true
	for player_entry in start_config.player_slots:
		var peer_id := int(player_entry.get("peer_id", -1))
		if peer_id <= 0 or not member_peer_ids.has(peer_id):
			return false
	return true


func _build_fallback_room_snapshot_from_start_config(start_config: BattleStartConfig) -> RoomSnapshot:
	if start_config == null:
		return null
	var snapshot := RoomSnapshot.new()
	snapshot.selected_map_id = String(start_config.map_id)
	snapshot.rule_set_id = String(start_config.rule_set_id)
	for player_entry in start_config.player_slots:
		var peer_id := int(player_entry.get("peer_id", -1))
		if peer_id <= 0:
			continue
		var member := RoomMemberState.new()
		member.peer_id = peer_id
		member.player_name = String(player_entry.get("player_name", player_entry.get("display_name", "Player%d" % peer_id)))
		member.ready = true
		member.slot_index = int(player_entry.get("slot_index", -1))
		member.team_id = int(player_entry.get("team_id", 1))
		member.character_id = _resolve_character_id_from_start_config(start_config, peer_id)
		member.bubble_style_id = _resolve_bubble_style_id_from_start_config(start_config, peer_id)
		snapshot.members.append(member)
	return snapshot


func _resolve_character_id_from_start_config(start_config: BattleStartConfig, peer_id: int) -> String:
	if start_config == null:
		return ""
	var player_entry := _find_player_entry_for_peer(start_config, peer_id)
	if not player_entry.is_empty() and not String(player_entry.get("character_id", "")).strip_edges().is_empty():
		return String(player_entry.get("character_id", ""))
	for loadout in start_config.character_loadouts:
		if int(loadout.get("peer_id", -1)) == peer_id:
			return String(loadout.get("character_id", ""))
	return ""


func _resolve_team_id_from_start_config(start_config: BattleStartConfig, peer_id: int, fallback_team_id: int = 0) -> int:
	if start_config == null:
		return fallback_team_id
	var player_entry := _find_player_entry_for_peer(start_config, peer_id)
	if not player_entry.is_empty():
		var team_id := int(player_entry.get("team_id", fallback_team_id))
		if team_id > 0:
			return team_id
	return fallback_team_id


func _resolve_bubble_style_id_from_start_config(start_config: BattleStartConfig, peer_id: int) -> String:
	if start_config == null:
		return ""
	var player_entry := _find_player_entry_for_peer(start_config, peer_id)
	if not player_entry.is_empty() and not String(player_entry.get("bubble_style_id", "")).strip_edges().is_empty():
		return String(player_entry.get("bubble_style_id", ""))
	for loadout in start_config.player_bubble_loadouts:
		if int(loadout.get("peer_id", -1)) == peer_id:
			return String(loadout.get("bubble_style_id", ""))
	return ""


func _find_player_entry_for_peer(start_config: BattleStartConfig, peer_id: int) -> Dictionary:
	if start_config == null:
		return {}
	for player_entry in start_config.player_slots:
		if int(player_entry.get("peer_id", -1)) == peer_id:
			return player_entry
	return {}


func _build_room_selection_state_from_snapshot(snapshot: RoomSnapshot, start_config: BattleStartConfig) -> RoomSelectionState:
	var state := RoomSelectionStateScript.new()
	state.mode_id = String(start_config.mode_id)
	state.map_id = String(snapshot.selected_map_id)
	state.rule_set_id = String(snapshot.rule_set_id)
	for member in snapshot.sorted_members():
		var peer_id := int(member.peer_id)
		state.players[member.peer_id] = {
			"peer_id": member.peer_id,
			"slot_index": member.slot_index,
			"team_id": _resolve_team_id_from_start_config(start_config, peer_id, member.team_id),
			"character_id": _resolve_character_id_from_start_config(start_config, peer_id),
			"bubble_style_id": _resolve_bubble_style_id(_resolve_bubble_style_id_from_start_config(start_config, peer_id)),
			"ready": member.ready,
		}
	return state


func _resolve_bubble_style_id(bubble_style_id: String) -> String:
	if BubbleCatalogScript.has_bubble(bubble_style_id):
		return bubble_style_id
	return BubbleCatalogScript.get_default_bubble_id()


func _find_slot_index_for_peer(app_runtime: Node, peer_id: int) -> int:
	if app_runtime == null or app_runtime.current_start_config == null:
		return -1
	for player_entry in app_runtime.current_start_config.player_slots:
		if int(player_entry.get("peer_id", -1)) == peer_id:
			return int(player_entry.get("slot_index", -1))
	return -1


func _find_team_id_for_peer(app_runtime: Node, peer_id: int) -> int:
	if app_runtime == null or app_runtime.current_start_config == null:
		return 1
	for player_entry in app_runtime.current_start_config.player_slots:
		if int(player_entry.get("peer_id", -1)) == peer_id:
			return int(player_entry.get("team_id", 1))
	return 1


func _resolve_local_character_display_name(app_runtime: Node, manifest: Dictionary, resolved_start_config: BattleStartConfig) -> String:
	var local_peer_id := _resolve_local_peer_id(app_runtime, resolved_start_config)
	for entry in manifest.get("characters", []):
		if int(entry.get("peer_id", -1)) == local_peer_id:
			return String(entry.get("display_name", entry.get("character_id", "")))
	if not resolved_start_config.character_loadouts.is_empty():
		return String(resolved_start_config.character_loadouts[0].get("display_name", resolved_start_config.character_loadouts[0].get("character_id", "")))
	return ""


func _resolve_local_bubble_display_name(app_runtime: Node, manifest: Dictionary, resolved_start_config: BattleStartConfig) -> String:
	var local_peer_id := _resolve_local_peer_id(app_runtime, resolved_start_config)
	for entry in manifest.get("bubbles", []):
		if int(entry.get("peer_id", -1)) == local_peer_id:
			return String(entry.get("display_name", entry.get("bubble_style_id", "")))
	if not resolved_start_config.player_bubble_loadouts.is_empty():
		return String(resolved_start_config.player_bubble_loadouts[0].get("bubble_style_id", ""))
	return ""


func _resolve_local_peer_id(app_runtime: Node, resolved_start_config: BattleStartConfig) -> int:
	var local_peer_id := int(resolved_start_config.controlled_peer_id)
	if local_peer_id <= 0:
		local_peer_id = int(resolved_start_config.local_peer_id)
	if local_peer_id <= 0 and app_runtime != null:
		local_peer_id = int(app_runtime.local_peer_id)
	return local_peer_id
