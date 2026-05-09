class_name BattleHudController
extends Node

const CountdownPanelScript = preload("res://presentation/battle/hud/countdown_panel.gd")
const BattleCountdownDigitsScript = preload("res://presentation/battle/hud/battle_countdown_digits.gd")
const PlayerStatusPanelScript = preload("res://presentation/battle/hud/player_status_panel.gd")
const NetworkStatusPanelScript = preload("res://presentation/battle/hud/network_status_panel.gd")
const MatchMessagePanelScript = preload("res://presentation/battle/hud/match_message_panel.gd")
const BattleMetaPanelScript = preload("res://presentation/battle/hud/battle_meta_panel.gd")
const LocalPlayerAbilityPanelScript = preload("res://presentation/battle/hud/local_player_ability_panel.gd")
const BattleHudResourceBinderScript = preload("res://presentation/battle/hud/battle_hud_resource_binder.gd")
const BattleHudAssetIdsScript = preload("res://presentation/battle/hud/battle_hud_asset_ids.gd")
const UiAssetResolverScript = preload("res://app/front/ui_resources/ui_asset_resolver.gd")
const WorldTiming = preload("res://gameplay/shared/world_timing.gd")

@export var countdown_panel_path: NodePath = ^"../CountdownPanel"
@export var player_status_panel_path: NodePath = ^"../PlayerStatusPanel"
@export var network_status_panel_path: NodePath = ^"../NetworkStatusPanel"
@export var match_message_panel_path: NodePath = ^"../MatchMessagePanel"
@export var battle_meta_panel_path: NodePath = ^"../BattleMetaPanel"
@export var local_player_ability_panel_path: NodePath = ^"../LocalPlayerAbilityPanel"
@export var team_score_panel_path: NodePath = ^"../TeamScorePanel/TeamScoreLabel"
@export var local_life_state_panel_path: NodePath = ^"../LocalLifeStatePanel"
@export var countdown_digits_path: NodePath = ^"../CountdownDigits"
@export var tick_rate: int = WorldTiming.TICK_RATE
@export var debug_panels_visible_default: bool = false
@export var bottom_bar_left_shrink_px: float = 18.0
@export var runtime_auto_frame_alignment: bool = false
@export var runtime_apply_layout_overrides: bool = false
@export var runtime_create_reference_item_bar: bool = false

var countdown_panel: CountdownPanel = null
var player_status_panel: PlayerStatusPanel = null
var network_status_panel: NetworkStatusPanel = null
var match_message_panel: MatchMessagePanel = null
var battle_meta_panel: Node = null
var local_player_ability_panel: Node = null
var team_score_panel: Label = null
var local_life_state_panel: Label = null
var countdown_digits: Node = null

var _last_message: String = ""
var _local_player_entity_id: int = -1
var _pending_map_display_name: String = ""
var _pending_rule_display_name: String = ""
var _pending_match_meta_text: String = ""
var _pending_character_display_name: String = ""
var _pending_bubble_display_name: String = ""
var _hud_asset_bindings: Dictionary = {}
var _reference_item_bar: HBoxContainer = null
var _ui_asset_resolver = null
var _map_top_frame: TextureRect = null
var _map_left_frame: TextureRect = null
var _right_player_list_frame: TextureRect = null
var _bottom_status_bar_frame: TextureRect = null
var _battle_camera_controller: Node = null
var _debug_panels_visible: bool = false


func _ready() -> void:
	countdown_panel = _resolve_panel(countdown_panel_path, CountdownPanelScript)
	player_status_panel = _resolve_panel(player_status_panel_path, PlayerStatusPanelScript)
	network_status_panel = _resolve_panel(network_status_panel_path, NetworkStatusPanelScript)
	match_message_panel = _resolve_panel(match_message_panel_path, MatchMessagePanelScript)
	battle_meta_panel = _resolve_panel(battle_meta_panel_path, BattleMetaPanelScript)
	local_player_ability_panel = _resolve_panel(local_player_ability_panel_path, LocalPlayerAbilityPanelScript)
	team_score_panel = get_node_or_null(team_score_panel_path)
	local_life_state_panel = get_node_or_null(local_life_state_panel_path)
	countdown_digits = get_node_or_null(countdown_digits_path)
	_bind_hud_resource_ids()
	_apply_reference_frames()
	_bind_reference_frame_nodes()
	if runtime_apply_layout_overrides:
		_apply_formal_hud_layout()
	set_debug_panels_visible(debug_panels_visible_default)
	_apply_pending_battle_metadata()


func consume_battle_state(world: SimWorld) -> void:
	if world == null:
		return

	if countdown_panel != null:
		countdown_panel.apply_countdown(world.state.match_state.remaining_ticks, tick_rate)
	if countdown_digits != null and countdown_digits.has_method("apply_countdown"):
		countdown_digits.apply_countdown(world.state.match_state.remaining_ticks, tick_rate)

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
	if countdown_digits != null and countdown_digits.has_method("set_countdown_text"):
		countdown_digits.set_countdown_text("00:00")
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


func set_debug_panels_visible(visible: bool) -> void:
	_debug_panels_visible = visible
	for panel in [
		player_status_panel,
		network_status_panel,
		battle_meta_panel,
		local_player_ability_panel,
		team_score_panel,
		local_life_state_panel,
	]:
		if panel == null:
			continue
		panel.visible = visible


func is_debug_panels_visible() -> bool:
	return _debug_panels_visible


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
	_style_label_panel(countdown_panel, Vector2(12, 12), Vector2(176, 44), 20, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label_panel(player_status_panel, Vector2(8, 72), Vector2(228, 238), 12, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label_panel(network_status_panel, Vector2(1048, 12), Vector2(1272, 238), 10, HORIZONTAL_ALIGNMENT_RIGHT)
	_style_label_panel(match_message_panel, Vector2(424, 12), Vector2(760, 48), 16, HORIZONTAL_ALIGNMENT_CENTER)
	_style_panel(battle_meta_panel)
	_style_panel(local_player_ability_panel)
	_style_label_panel(team_score_panel, Vector2(8, 322), Vector2(228, 362), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label_panel(local_life_state_panel, Vector2(8, 542), Vector2(228, 576), 14, HORIZONTAL_ALIGNMENT_LEFT)
	if battle_meta_panel is Control:
		_set_control_rect(battle_meta_panel, Vector2(8, 372), Vector2(228, 452))
		(battle_meta_panel as Control).custom_minimum_size = Vector2.ZERO
		(battle_meta_panel as Control).clip_contents = true
	if local_player_ability_panel is Control:
		_set_control_rect(local_player_ability_panel, Vector2(8, 462), Vector2(228, 526))
		(local_player_ability_panel as Control).custom_minimum_size = Vector2.ZERO
		(local_player_ability_panel as Control).clip_contents = true
	if runtime_create_reference_item_bar:
		_ensure_reference_item_bar()
	_configure_reference_frame_rects()


func _process(_delta: float) -> void:
	if not runtime_auto_frame_alignment:
		return
	_update_reference_frame_alignment()


func _style_label_panel(label_node: Label, position: Vector2, size: Vector2, font_size: int, alignment: int) -> void:
	if label_node == null:
		return
	_set_control_rect(label_node, position, size)
	label_node.custom_minimum_size = Vector2.ZERO
	label_node.clip_text = true
	label_node.horizontal_alignment = alignment
	label_node.add_theme_font_size_override("font_size", font_size)
	label_node.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	label_node.add_theme_stylebox_override("normal", _make_hud_style(Color(0.04, 0.07, 0.10, 0.45), Color(0.36, 0.58, 0.78, 0.72), 6))


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


func _ensure_reference_item_bar() -> void:
	var hud_parent := get_parent()
	if hud_parent == null:
		return
	_reference_item_bar = hud_parent.get_node_or_null("ReferenceItemBar")
	if _reference_item_bar != null:
		return
	_reference_item_bar = HBoxContainer.new()
	_reference_item_bar.name = "ReferenceItemBar"
	_reference_item_bar.anchor_left = 0.5
	_reference_item_bar.anchor_right = 0.5
	_reference_item_bar.anchor_top = 1.0
	_reference_item_bar.anchor_bottom = 1.0
	_reference_item_bar.offset_left = -250.0
	_reference_item_bar.offset_top = -72.0
	_reference_item_bar.offset_right = 250.0
	_reference_item_bar.offset_bottom = -18.0
	_reference_item_bar.add_theme_constant_override("separation", 8)
	if hud_parent.is_node_ready():
		hud_parent.add_child(_reference_item_bar)
	else:
		hud_parent.add_child.call_deferred(_reference_item_bar)
	for index in range(7):
		_reference_item_bar.add_child(_create_reference_item_slot(index + 1))


func _configure_reference_frame_rects() -> void:
	var hud_parent := get_parent()
	if hud_parent == null:
		return
	_set_texture_rect_rect(hud_parent.get_node_or_null("MapTopFrame"), Vector2(0, 0), Vector2(1514, 383))
	_set_texture_rect_rect(hud_parent.get_node_or_null("MapLeftFrame"), Vector2(0, 0), Vector2(76, 977))
	_set_texture_rect_rect(hud_parent.get_node_or_null("RightPlayerListFrame"), Vector2(0, 0), Vector2(500, 1435))
	_set_texture_rect_rect(hud_parent.get_node_or_null("BottomStatusBarFrame"), Vector2(0, 0), Vector2(1517, 126))


func _set_texture_rect_rect(node: Node, position: Vector2, size: Vector2) -> void:
	if node == null or not (node is TextureRect):
		return
	var texture_rect := node as TextureRect
	texture_rect.anchor_left = 0.0
	texture_rect.anchor_top = 0.0
	texture_rect.anchor_right = 0.0
	texture_rect.anchor_bottom = 0.0
	texture_rect.offset_left = position.x
	texture_rect.offset_top = position.y
	texture_rect.offset_right = position.x + size.x
	texture_rect.offset_bottom = position.y + size.y
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE


func _apply_reference_frames() -> void:
	var hud_parent := get_parent()
	if hud_parent == null:
		return
	_set_frame_texture(hud_parent.get_node_or_null("RightPlayerListFrame"), BattleHudAssetIdsScript.FRAME_PLAYER_LIST)
	_set_frame_texture(hud_parent.get_node_or_null("BottomStatusBarFrame"), BattleHudAssetIdsScript.FRAME_STATUS_BAR)
	_set_frame_texture(hud_parent.get_node_or_null("MapTopFrame"), BattleHudAssetIdsScript.FRAME_MAP_TOP)
	_set_frame_texture(hud_parent.get_node_or_null("MapLeftFrame"), BattleHudAssetIdsScript.FRAME_MAP_LEFT)


func _bind_reference_frame_nodes() -> void:
	var hud_parent := get_parent()
	if hud_parent == null:
		return
	_map_top_frame = hud_parent.get_node_or_null("MapTopFrame") as TextureRect
	_map_left_frame = hud_parent.get_node_or_null("MapLeftFrame") as TextureRect
	_right_player_list_frame = hud_parent.get_node_or_null("RightPlayerListFrame") as TextureRect
	_bottom_status_bar_frame = hud_parent.get_node_or_null("BottomStatusBarFrame") as TextureRect
	_battle_camera_controller = hud_parent.get_parent().get_node_or_null("BattleCameraController")


func _update_reference_frame_alignment() -> void:
	if _battle_camera_controller == null:
		return
	if not _battle_camera_controller.has_method("get_map_screen_rect"):
		return
	var map_rect: Rect2 = _battle_camera_controller.get_map_screen_rect()
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return
	var top_size := _texture_size_or_fallback(_map_top_frame, Vector2(1514, 383))
	var left_size := _texture_size_or_fallback(_map_left_frame, Vector2(76, 977))
	var right_size := _texture_size_or_fallback(_right_player_list_frame, Vector2(500, 1435))
	var bottom_size := _texture_size_or_fallback(_bottom_status_bar_frame, Vector2(1517, 126))
	var top_y: float = round(map_rect.position.y - top_size.y)
	var left_x: float = round(map_rect.position.x - left_size.x)
	var map_x: float = round(map_rect.position.x)
	var map_y: float = round(map_rect.position.y)
	var map_w: float = round(map_rect.size.x)
	var map_h: float = round(map_rect.size.y)
	var bottom_y: float = round(map_y + map_h)
	var bottom_left_x: float = round(left_x + max(bottom_bar_left_shrink_px, 0.0))
	var bottom_width: float = round(map_w + left_size.x + right_size.x - max(bottom_bar_left_shrink_px, 0.0))

	# 贴边规则：上贴地图上边，左贴地图左边，右贴地图右边，底贴地图下边。
	_set_texture_rect_rect(_map_top_frame, Vector2(map_x, top_y), Vector2(map_w, top_size.y))
	_set_texture_rect_rect(_map_left_frame, Vector2(left_x, map_y), Vector2(left_size.x, map_h))
	_set_texture_rect_rect(
		_right_player_list_frame,
		Vector2(round(map_x + map_w), top_y),
		Vector2(right_size.x, map_h + top_size.y + bottom_size.y)
	)
	_set_texture_rect_rect(_bottom_status_bar_frame, Vector2(bottom_left_x, bottom_y), Vector2(bottom_width, bottom_size.y))


func _texture_size_or_fallback(node: TextureRect, fallback: Vector2) -> Vector2:
	if node == null or node.texture == null:
		return fallback
	return node.texture.get_size()


func _set_frame_texture(node: Node, asset_id: String) -> void:
	if node == null or not (node is TextureRect):
		return
	var texture := _load_ui_texture(asset_id)
	if texture == null:
		return
	var texture_rect := node as TextureRect
	texture_rect.texture = texture
	texture_rect.set_meta("ui_asset_id", asset_id)


func _load_ui_texture(asset_id: String) -> Texture2D:
	if _ui_asset_resolver == null:
		_ui_asset_resolver = UiAssetResolverScript.new()
		_ui_asset_resolver.configure(null, false)
	var texture: Variant = _ui_asset_resolver.load_resource(asset_id)
	if texture is Texture2D:
		return texture
	var resolved: Dictionary = _ui_asset_resolver.resolve_path(asset_id)
	if not bool(resolved.get("ok", false)):
		return null
	var resource_path := String(resolved.get("resource_path", ""))
	if resource_path.is_empty():
		return null
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var image := Image.new()
	if image.load(absolute_path) != OK:
		return null
	return ImageTexture.create_from_image(image)
	return null


func _create_reference_item_slot(slot_index: int) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(54, 54)
	slot.add_theme_stylebox_override("panel", _make_hud_style(Color(0.92, 0.96, 1.0, 0.92), Color(0.22, 0.58, 0.86, 1.0), 6))
	slot.set_meta("ui_asset_id", "ui.battle.item_slot.empty")
	var label := Label.new()
	label.text = str(slot_index)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.20, 0.35, 0.48, 1.0))
	slot.add_child(label)
	return slot


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
