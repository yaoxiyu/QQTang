class_name BattleHudController
extends Node

const CountdownPanelScript = preload("res://presentation/battle/hud/countdown_panel.gd")
const PlayerStatusPanelScript = preload("res://presentation/battle/hud/player_status_panel.gd")
const NetworkStatusPanelScript = preload("res://presentation/battle/hud/network_status_panel.gd")
const MatchMessagePanelScript = preload("res://presentation/battle/hud/match_message_panel.gd")
const BattleMetaPanelScript = preload("res://presentation/battle/hud/battle_meta_panel.gd")
const LocalPlayerAbilityPanelScript = preload("res://presentation/battle/hud/local_player_ability_panel.gd")
const WorldTiming = preload("res://gameplay/shared/world_timing.gd")

@export var countdown_panel_path: NodePath = ^"../CountdownPanel"
@export var player_status_panel_path: NodePath = ^"../PlayerStatusPanel"
@export var network_status_panel_path: NodePath = ^"../NetworkStatusPanel"
@export var match_message_panel_path: NodePath = ^"../MatchMessagePanel"
@export var battle_meta_panel_path: NodePath = ^"../BattleMetaPanel"
@export var local_player_ability_panel_path: NodePath = ^"../LocalPlayerAbilityPanel"
@export var tick_rate: int = WorldTiming.TICK_RATE

var countdown_panel: CountdownPanel = null
var player_status_panel: PlayerStatusPanel = null
var network_status_panel: NetworkStatusPanel = null
var match_message_panel: MatchMessagePanel = null
var battle_meta_panel: Node = null
var local_player_ability_panel: Node = null

var _last_message: String = ""
var _local_player_entity_id: int = -1
var _pending_map_display_name: String = ""
var _pending_rule_display_name: String = ""
var _pending_match_meta_text: String = ""
var _pending_character_display_name: String = ""
var _pending_bubble_display_name: String = ""


func _ready() -> void:
	countdown_panel = _resolve_panel(countdown_panel_path, CountdownPanelScript)
	player_status_panel = _resolve_panel(player_status_panel_path, PlayerStatusPanelScript)
	network_status_panel = _resolve_panel(network_status_panel_path, NetworkStatusPanelScript)
	match_message_panel = _resolve_panel(match_message_panel_path, MatchMessagePanelScript)
	battle_meta_panel = _resolve_panel(battle_meta_panel_path, BattleMetaPanelScript)
	local_player_ability_panel = _resolve_panel(local_player_ability_panel_path, LocalPlayerAbilityPanelScript)
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
		"battle_meta_map_text": String(meta_dump.get("map_text", "")),
		"battle_meta_rule_text": String(meta_dump.get("rule_text", "")),
		"battle_meta_match_text": String(meta_dump.get("match_text", "")),
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


func _resolve_panel(path: NodePath, fallback_script: Script) -> Node:
	var existing := get_node_or_null(path)
	if existing != null:
		return existing
	if fallback_script == null:
		return null
	var panel: Node = fallback_script.new()
	add_child(panel)
	return panel


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
	for player_id in world.state.players.active_ids:
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		if _local_player_entity_id >= 0 and player.entity_id != _local_player_entity_id:
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
