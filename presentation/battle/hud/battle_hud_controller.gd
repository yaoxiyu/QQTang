class_name BattleHudController
extends Node

const CountdownPanelScript = preload("res://presentation/battle/hud/countdown_panel.gd")
const PlayerStatusPanelScript = preload("res://presentation/battle/hud/player_status_panel.gd")
const NetworkStatusPanelScript = preload("res://presentation/battle/hud/network_status_panel.gd")
const MatchMessagePanelScript = preload("res://presentation/battle/hud/match_message_panel.gd")
const BattleMetaPanelScript = preload("res://presentation/battle/hud/battle_meta_panel.gd")
const LocalPlayerAbilityPanelScript = preload("res://presentation/battle/hud/local_player_ability_panel.gd")
const BattleHudResourceBinderScript = preload("res://presentation/battle/hud/battle_hud_resource_binder.gd")
const WorldTiming = preload("res://gameplay/shared/world_timing.gd")

@export var countdown_panel_path: NodePath = ^"../CountdownPanel"
@export var player_status_panel_path: NodePath = ^"../PlayerStatusPanel"
@export var network_status_panel_path: NodePath = ^"../NetworkStatusPanel"
@export var match_message_panel_path: NodePath = ^"../MatchMessagePanel"
@export var battle_meta_panel_path: NodePath = ^"../BattleMetaPanel"
@export var local_player_ability_panel_path: NodePath = ^"../LocalPlayerAbilityPanel"
@export var team_score_panel_path: NodePath = ^"../TeamScorePanel/TeamScoreLabel"
@export var local_life_state_panel_path: NodePath = ^"../LocalLifeStatePanel"
@export var tick_rate: int = WorldTiming.TICK_RATE

var countdown_panel: CountdownPanel = null
var player_status_panel: PlayerStatusPanel = null
var network_status_panel: NetworkStatusPanel = null
var match_message_panel: MatchMessagePanel = null
var battle_meta_panel: Node = null
var local_player_ability_panel: Node = null
var team_score_panel: Label = null
var local_life_state_panel: Label = null

var _last_message: String = ""
var _local_player_entity_id: int = -1
var _pending_map_display_name: String = ""
var _pending_rule_display_name: String = ""
var _pending_match_meta_text: String = ""
var _pending_character_display_name: String = ""
var _pending_bubble_display_name: String = ""
var _hud_asset_bindings: Dictionary = {}


func _ready() -> void:
	countdown_panel = _resolve_panel(countdown_panel_path, CountdownPanelScript)
	player_status_panel = _resolve_panel(player_status_panel_path, PlayerStatusPanelScript)
	network_status_panel = _resolve_panel(network_status_panel_path, NetworkStatusPanelScript)
	match_message_panel = _resolve_panel(match_message_panel_path, MatchMessagePanelScript)
	battle_meta_panel = _resolve_panel(battle_meta_panel_path, BattleMetaPanelScript)
	local_player_ability_panel = _resolve_panel(local_player_ability_panel_path, LocalPlayerAbilityPanelScript)
	team_score_panel = get_node_or_null(team_score_panel_path)
	local_life_state_panel = get_node_or_null(local_life_state_panel_path)
	_bind_hud_resource_ids()
	_apply_formal_hud_layout()
	_apply_pending_battle_metadata()


func consume_battle_state(world: SimWorld) -> void:
	if world == null:
		return

	if countdown_panel != null:
		countdown_panel.apply_countdown(world.state.match_state.remaining_ticks, tick_rate)

	if player_status_panel != null:
		player_status_panel.apply_player_statuses(_build_player_statuses(world))

	if local_player_ability_panel != null:
		local_player_ability_panel.apply_player_ability(_build_local_player_status(world))

	if match_message_panel != null:
		match_message_panel.apply_message(_build_phase_message(world))

	_apply_team_scores(world)
	_apply_local_life_state(world)


func consume_network_metrics(metrics: Dictionary) -> void:
	if network_status_panel == null:
		return

	network_status_panel.apply_network_metrics(metrics)


func on_player_killed_event(event: SimEvent) -> void:
	if event == null or match_message_panel == null:
		return

	var victim_player_id := int(event.payload.get("victim_player_id", -1))
	if victim_player_id >= 0:
		_last_message = "Player %d Down" % [victim_player_id]
		match_message_panel.apply_message(_last_message)


func on_item_picked_event(event: SimEvent, local_player_entity_id: int = -1) -> void:
	if event == null or match_message_panel == null:
		return

	var picker_id := int(event.payload.get("player_id", -1))
	if local_player_entity_id >= 0 and picker_id != local_player_entity_id:
		return

	var item_type := int(event.payload.get("item_type", 0))
	match item_type:
		1:
			_last_message = "Range Up"
		2:
			_last_message = "Bomb Capacity Up"
		3:
			_last_message = "Speed Up"
		_:
			_last_message = "Item Picked"
	match_message_panel.apply_message(_last_message)


func on_match_ended_event(event: SimEvent, local_peer_id: int = -1) -> void:
	if event == null or match_message_panel == null:
		return

	var winner_player_id := int(event.payload.get("winner_player_id", -1))
	var reason_value = event.payload.get("reason", MatchState.EndReason.NONE)
	var ended_reason: int = int(reason_value)
	if local_peer_id >= 0 and winner_player_id == local_peer_id:
		_last_message = "Victory"
	elif winner_player_id >= 0:
		_last_message = "Defeat"
	elif ended_reason == MatchState.EndReason.TIME_UP:
		_last_message = "Draw"
	else:
		_last_message = "Match Ended"
	match_message_panel.apply_message(_last_message)


func debug_dump_hud_state() -> Dictionary:
	var meta_dump: Dictionary = battle_meta_panel.debug_dump_state() if battle_meta_panel != null and battle_meta_panel.has_method("debug_dump_state") else {}
	return {
		"countdown_text": countdown_panel.text if countdown_panel != null else "",
		"player_status_text": player_status_panel.text if player_status_panel != null else "",
		"network_status_text": network_status_panel.text if network_status_panel != null else "",
		"match_message_text": match_message_panel.text if match_message_panel != null else "",
		"team_score_text": team_score_panel.text if team_score_panel != null else "",
		"local_life_state_text": local_life_state_panel.text if local_life_state_panel != null else "",
		"battle_meta_map_text": String(meta_dump.get("map_text", "")),
		"battle_meta_rule_text": String(meta_dump.get("rule_text", "")),
		"battle_meta_match_text": String(meta_dump.get("match_text", "")),
		"hud_asset_bindings": _hud_asset_bindings.duplicate(),
	}


func reset_hud() -> void:
	_last_message = ""
	if countdown_panel != null:
		countdown_panel.apply_message("")
	if player_status_panel != null:
		player_status_panel.apply_player_statuses([])
	if network_status_panel != null:
		network_status_panel.apply_network_metrics({})
	if match_message_panel != null:
		match_message_panel.apply_message("")
	if battle_meta_panel != null:
		if battle_meta_panel.has_method("apply_extended_metadata"):
			battle_meta_panel.apply_extended_metadata("", "", "", "", "")
		else:
			battle_meta_panel.apply_metadata("", "", "")
	if local_player_ability_panel != null:
		local_player_ability_panel.apply_player_ability({})
	if team_score_panel != null:
		team_score_panel.text = ""
	if local_life_state_panel != null:
		local_life_state_panel.text = ""


func _resolve_panel(path: NodePath, fallback_script: Script) -> Node:
	var existing := get_node_or_null(path)
	if existing != null:
		return existing
	if fallback_script == null:
		return null
	var panel: Node = fallback_script.new()
	add_child(panel)
	return panel


func _bind_hud_resource_ids() -> void:
	var binder = BattleHudResourceBinderScript.new()
	_hud_asset_bindings = binder.bind_panel_assets({
		"countdown_panel": countdown_panel,
		"player_status_panel": player_status_panel,
		"network_status_panel": network_status_panel,
		"match_message_panel": match_message_panel,
		"battle_meta_panel": battle_meta_panel,
		"local_player_ability_panel": local_player_ability_panel,
		"team_score_panel": team_score_panel,
		"local_life_state_panel": local_life_state_panel,
	})


func _apply_formal_hud_layout() -> void:
	_style_label_panel(countdown_panel, Vector2(28, 22), Vector2(248, 68), 24, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label_panel(player_status_panel, Vector2(28, 82), Vector2(360, 220), 15, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label_panel(network_status_panel, Vector2(816, 22), Vector2(1180, 210), 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_style_label_panel(match_message_panel, Vector2(404, 24), Vector2(780, 76), 20, HORIZONTAL_ALIGNMENT_CENTER)
	_style_panel(battle_meta_panel)
	_style_panel(local_player_ability_panel)
	_style_label_panel(team_score_panel, Vector2(970, 226), Vector2(1180, 332), 16, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label_panel(local_life_state_panel, Vector2(28, 400), Vector2(300, 442), 18, HORIZONTAL_ALIGNMENT_LEFT)
	if battle_meta_panel is Control:
		_set_control_rect(battle_meta_panel, Vector2(28, 238), Vector2(360, 360))
	if local_player_ability_panel is Control:
		_set_control_rect(local_player_ability_panel, Vector2(28, 372), Vector2(440, 424))


func _style_label_panel(label_node: Label, position: Vector2, size: Vector2, font_size: int, alignment: int) -> void:
	if label_node == null:
		return
	_set_control_rect(label_node, position, size)
	label_node.horizontal_alignment = alignment
	label_node.add_theme_font_size_override("font_size", font_size)
	label_node.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	label_node.add_theme_stylebox_override("normal", _make_hud_style(Color(0.04, 0.07, 0.10, 0.72), Color(0.36, 0.58, 0.78, 0.72), 6))


func _style_panel(panel: Node) -> void:
	if panel == null or not (panel is PanelContainer):
		return
	panel.add_theme_stylebox_override("panel", _make_hud_style(Color(0.04, 0.07, 0.10, 0.76), Color(0.36, 0.58, 0.78, 0.78), 6))


func _set_control_rect(control: Control, position: Vector2, size: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = position.x
	control.offset_top = position.y
	control.offset_right = size.x
	control.offset_bottom = size.y


func _make_hud_style(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _build_player_statuses(world: SimWorld) -> Array[Dictionary]:
	var statuses: Array[Dictionary] = []
	var player_ids := world.state.players.active_ids.duplicate()
	player_ids.sort()

	for player_id in player_ids:
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		statuses.append({
			"entity_id": player.entity_id,
			"player_slot": player.player_slot,
			"alive": player.alive,
			"life_state_text": _life_state_to_text(player.life_state),
			"bomb_available": player.bomb_available,
			"bomb_capacity": player.bomb_capacity,
			"bomb_range": player.bomb_range,
			"speed_level": player.speed_level,
			"has_kick": player.has_kick,
		})

	return statuses


func set_battle_metadata(map_display_name: String, rule_display_name: String, match_meta_text: String) -> void:
	_pending_map_display_name = map_display_name
	_pending_rule_display_name = rule_display_name
	_pending_match_meta_text = match_meta_text
	_apply_pending_battle_metadata()


func set_extended_battle_metadata(
	map_display_name: String,
	rule_display_name: String,
	match_meta_text: String,
	character_display_name: String,
	bubble_display_name: String
) -> void:
	_pending_map_display_name = map_display_name
	_pending_rule_display_name = rule_display_name
	_pending_match_meta_text = match_meta_text
	_pending_character_display_name = character_display_name
	_pending_bubble_display_name = bubble_display_name
	_apply_pending_battle_metadata()


func set_local_player_entity_id(entity_id: int) -> void:
	_local_player_entity_id = entity_id


func _build_local_player_status(world: SimWorld) -> Dictionary:
	if world == null:
		return {}
	var controlled_slot := -1
	if world.state != null and world.state.runtime_flags != null:
		controlled_slot = int(world.state.runtime_flags.client_controlled_player_slot)
	if _local_player_entity_id >= 0:
		for player_id in world.state.players.active_ids:
			var player := world.state.players.get_player(player_id)
			if player == null:
				continue
			if player.entity_id != _local_player_entity_id:
				continue
			return {
				"entity_id": player.entity_id,
				"bomb_available": player.bomb_available,
				"bomb_capacity": player.bomb_capacity,
				"bomb_range": player.bomb_range,
				"speed_level": player.speed_level,
				"has_kick": player.has_kick,
			}
	if controlled_slot >= 0:
		for player_id in world.state.players.active_ids:
			var player := world.state.players.get_player(player_id)
			if player == null:
				continue
			if int(player.player_slot) != controlled_slot:
				continue
			return {
				"entity_id": player.entity_id,
				"bomb_available": player.bomb_available,
				"bomb_capacity": player.bomb_capacity,
				"bomb_range": player.bomb_range,
				"speed_level": player.speed_level,
				"has_kick": player.has_kick,
			}
	for player_id in world.state.players.active_ids:
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		return {
			"entity_id": player.entity_id,
			"bomb_available": player.bomb_available,
			"bomb_capacity": player.bomb_capacity,
			"bomb_range": player.bomb_range,
			"speed_level": player.speed_level,
			"has_kick": player.has_kick,
		}
	return {}


func _build_phase_message(world: SimWorld) -> String:
	match int(world.state.match_state.phase):
		MatchState.Phase.COUNTDOWN:
			return "Ready"
		MatchState.Phase.ENDING:
			return "Finishing"
		MatchState.Phase.ENDED:
			if not _last_message.is_empty():
				return _last_message
			if int(world.state.match_state.ended_reason) == MatchState.EndReason.TIME_UP:
				return "Draw"
			return "Match Ended"
		_:
			return ""


func _apply_team_scores(world: SimWorld) -> void:
	if team_score_panel == null or world == null:
		return

	var participating_team_ids := _collect_participating_team_ids(world)
	if participating_team_ids.is_empty():
		team_score_panel.text = ""
		return

	var lines: Array[String] = []
	for team_id in participating_team_ids:
		var score := int(world.state.mode.team_scores.get(team_id, 0))
		lines.append("Team %d: %d" % [team_id, score])
	team_score_panel.text = "\n".join(lines)


func _apply_local_life_state(world: SimWorld) -> void:
	if local_life_state_panel == null or world == null:
		return

	var player := _resolve_local_player_for_life_state(world)
	if player == null:
		local_life_state_panel.text = ""
		return

	match int(player.life_state):
		PlayerState.LifeState.NORMAL:
			local_life_state_panel.text = ""
		PlayerState.LifeState.TRAPPED:
			local_life_state_panel.text = "Jelly"
		PlayerState.LifeState.REVIVING:
			var seconds_left := int(ceil(float(max(player.respawn_ticks, 0)) / float(max(tick_rate, 1))))
			local_life_state_panel.text = "Respawn in %d" % seconds_left
		PlayerState.LifeState.DEAD:
			local_life_state_panel.text = "Out"
		_:
			local_life_state_panel.text = ""


func _collect_participating_team_ids(world: SimWorld) -> Array[int]:
	var teams: Dictionary = {}
	for player_id in range(world.state.players.size()):
		var player := world.state.players.get_player(player_id)
		if player == null or player.team_id < 1:
			continue
		teams[player.team_id] = true
	var team_ids: Array[int] = []
	for team_id in teams.keys():
		team_ids.append(int(team_id))
	team_ids.sort()
	return team_ids


func _resolve_local_player_for_life_state(world: SimWorld) -> PlayerState:
	if world == null:
		return null

	if _local_player_entity_id >= 0:
		var player_by_entity := world.state.players.get_player(_local_player_entity_id)
		if player_by_entity != null:
			return player_by_entity

	var controlled_slot := -1
	if world.state != null and world.state.runtime_flags != null:
		controlled_slot = int(world.state.runtime_flags.client_controlled_player_slot)
	if controlled_slot >= 0:
		for player_id in range(world.state.players.size()):
			var player := world.state.players.get_player(player_id)
			if player == null:
				continue
			if int(player.player_slot) == controlled_slot:
				return player

	for player_id in range(world.state.players.size()):
		var player := world.state.players.get_player(player_id)
		if player != null:
			return player
	return null


func _life_state_to_text(life_state: int) -> String:
	match life_state:
		PlayerState.LifeState.NORMAL:
			return "NORMAL"
		PlayerState.LifeState.TRAPPED:
			return "TRAPPED"
		PlayerState.LifeState.DEAD:
			return "DEAD"
		PlayerState.LifeState.REVIVING:
			return "REVIVING"
		_:
			return "UNKNOWN"


func _apply_pending_battle_metadata() -> void:
	if battle_meta_panel == null:
		return
	if battle_meta_panel.has_method("apply_extended_metadata"):
		battle_meta_panel.apply_extended_metadata(
			_pending_map_display_name,
			_pending_rule_display_name,
			_pending_match_meta_text,
			_pending_character_display_name,
			_pending_bubble_display_name
		)
	else:
		battle_meta_panel.apply_metadata(
			_pending_map_display_name,
			_pending_rule_display_name,
			_pending_match_meta_text
		)
