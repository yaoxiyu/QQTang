class_name BattlePresentationBridge
extends Node2D

const ActorRegistryScript = preload("res://presentation/battle/bridge/actor_registry.gd")
const StateToViewMapperScript = preload("res://presentation/battle/bridge/state_to_view_mapper.gd")
const BattleEventRouterScript = preload("res://presentation/battle/bridge/battle_event_router.gd")
const ExplosionActorViewScript = preload("res://presentation/battle/actors/explosion_actor_view.gd")
const CorrectionMarkerViewScript = preload("res://presentation/battle/actors/correction_marker_view.gd")
const BrickBreakFxPlayerScript = preload("res://presentation/battle/fx/brick_break_fx_player.gd")
const ItemSpawnFxPlayerScript = preload("res://presentation/battle/fx/item_spawn_fx_player.gd")
const ItemPickupFxPlayerScript = preload("res://presentation/battle/fx/item_pickup_fx_player.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")
const SimEventScript = preload("res://gameplay/simulation/events/sim_event.gd")
const BattleAudioEventConfigScript = preload("res://presentation/battle/audio/battle_audio_event_config.gd")
const FxPoolScript = preload("res://presentation/battle/fx/fx_pool.gd")
const LogPresentationScript = preload("res://app/logging/log_presentation.gd")
const TRACE_PREFIX := "[qq_battle_trace]"
const DEBUG_TICK_LOGS := false
const LOG_FX_ANOMALIES := false

@export var map_view_path: NodePath = ^"../../WorldRoot/MapRoot"
@export var actor_layer_path: NodePath = ^"../../WorldRoot/ActorLayer"
@export var fx_layer_path: NodePath = ^"../../WorldRoot/FxLayer"
@export var spawn_fx_controller_path: NodePath = ^"../../SpawnFxController"
@export var cell_size: float = BattleViewMetrics.DEFAULT_CELL_PIXELS
@export var player_actor_scene: PackedScene
@export var bubble_actor_scene: PackedScene
@export var item_actor_scene: PackedScene

var map_view: Node2D = null
var actor_layer: Node2D = null
var fx_layer: Node2D = null
var spawn_fx_controller: Node = null
var _grid_cache: Dictionary = {}

var actor_registry: BattleActorRegistry = null
var state_to_view_mapper: BattleStateToViewMapper = null
var battle_event_router: BattleEventRouter = null
var fx_pool: FxPool = null
var _player_visual_profiles: Dictionary = {}
var _bubble_style_by_slot: Dictionary = {}
var _bubble_color_by_slot: Dictionary = {}

var _last_consumed_tick: int = -1
var _local_player_entity_id: int = -1


func _ready() -> void:
	if has_node(map_view_path):
		map_view = get_node(map_view_path)
	if has_node(actor_layer_path):
		actor_layer = get_node(actor_layer_path)
		if actor_layer != null:
			actor_layer.z_as_relative = false
			actor_layer.z_index = 0
	if has_node(fx_layer_path):
		fx_layer = get_node(fx_layer_path)
		if fx_layer != null:
			fx_layer.z_as_relative = false
			fx_layer.z_index = 0
	if has_node(spawn_fx_controller_path):
		spawn_fx_controller = get_node(spawn_fx_controller_path)

	actor_registry = ActorRegistryScript.new()
	actor_registry.configure(player_actor_scene, bubble_actor_scene, item_actor_scene)
	actor_registry.configure_player_visual_profiles(_player_visual_profiles)
	state_to_view_mapper = StateToViewMapperScript.new()
	state_to_view_mapper.cell_size = cell_size
	battle_event_router = BattleEventRouterScript.new()
	add_child(battle_event_router)
	battle_event_router.explosion_event_routed.connect(_on_explosion_event_routed)
	battle_event_router.cell_destroyed_event_routed.connect(_on_cell_destroyed_event_routed)
	battle_event_router.bubble_placed_event_routed.connect(_on_bubble_placed_event_routed)
	battle_event_router.player_revived_event_routed.connect(_on_player_revived_event_routed)

	fx_pool = FxPoolScript.new()
	fx_pool.register_factory("explosion", func(): return ExplosionActorViewScript.new())
	fx_pool.register_factory("brick_break", func(): return BrickBreakFxPlayerScript.new())
	fx_pool.register_factory("item_spawn", func(): return ItemSpawnFxPlayerScript.new())
	fx_pool.register_factory("item_pickup", func(): return ItemPickupFxPlayerScript.new())
	fx_pool.prewarm("explosion", 4, fx_layer)
	fx_pool.prewarm("brick_break", 8, fx_layer)
	battle_event_router.player_trap_executed_event_routed.connect(_on_player_trap_executed_event_routed)
	battle_event_router.item_spawned_event_routed.connect(_on_item_spawned_event_routed)
	battle_event_router.item_picked_event_routed.connect(_on_item_picked_event_routed)


func consume_tick_result(_result: Dictionary, world: SimWorld, events: Array = []) -> void:
	if world == null or actor_layer == null:
		return

	var tick_id := int(world.state.match_state.tick)
	var runtime_flags := world.state.runtime_flags
	var force_client_refresh := runtime_flags != null and bool(runtime_flags.client_prediction_mode)
	if tick_id == _last_consumed_tick and not force_client_refresh:
		if DEBUG_TICK_LOGS:
			LogPresentationScript.debug(
				"consume_tick_result_skipped tick=%d force_client_refresh=%s event_count=%d" % [
					tick_id,
					str(force_client_refresh),
					events.size(),
				],
				"",
				0,
				"presentation.bridge.skip"
			)
		return
	if DEBUG_TICK_LOGS:
		LogPresentationScript.debug(
			"consume_tick_result tick=%d force_client_refresh=%s event_count=%d phase=%d" % [
				tick_id,
				str(force_client_refresh),
				events.size(),
				int(world.state.match_state.phase),
			],
			"",
			0,
			"presentation.bridge.tick"
		)

	_log_explosion_events("presentation_consume", tick_id, events)
	_play_battle_sfx_for_events(events)
	battle_event_router.route_events(events)
	_grid_cache = state_to_view_mapper.build_grid_cache(world)
	if map_view != null and map_view.has_method("apply_grid_cache"):
		map_view.apply_grid_cache(_grid_cache, cell_size)
	actor_registry.sync_players(actor_layer, state_to_view_mapper.build_player_views(world))
	actor_registry.sync_bubbles(actor_layer, state_to_view_mapper.build_bubble_views(world))
	actor_registry.sync_items(actor_layer, state_to_view_mapper.build_item_views(world))
	_log_actor_sync_anomalies(world, tick_id, events)
	_last_consumed_tick = tick_id


func configure_map_presentation(layout: MapRuntimeLayout, map_theme: MapThemeDef) -> void:
	if map_view != null and map_view.has_method("configure_map_presentation"):
		map_view.configure_map_presentation(layout, map_theme, cell_size)
	if actor_registry != null and map_view != null and map_view.has_method("get_channel_pass_mask_by_cell"):
		actor_registry.configure_channel_pass_mask_by_cell(map_view.get_channel_pass_mask_by_cell())
	if actor_registry != null and map_view != null and map_view.has_method("get_surface_virtual_z_by_cell"):
		actor_registry.configure_surface_virtual_z_by_cell(map_view.get_surface_virtual_z_by_cell())
	if actor_registry != null and map_view != null and map_view.has_method("get_surface_row_max_z"):
		actor_registry.configure_surface_row_max_z(map_view.get_surface_row_max_z())
	if actor_registry != null and map_view != null and map_view.has_method("get_surface_render_z_by_cell"):
		actor_registry.configure_surface_render_z_by_cell(map_view.get_surface_render_z_by_cell())




func clear_bridge() -> void:
	_last_consumed_tick = -1
	_grid_cache.clear()
	if map_view != null and map_view.has_method("clear_map"):
		map_view.clear_map()
	if actor_registry != null:
		actor_registry.configure_channel_pass_mask_by_cell({})
		actor_registry.configure_surface_virtual_z_by_cell({})
		actor_registry.configure_surface_row_max_z({})
		actor_registry.configure_surface_render_z_by_cell({})
		actor_registry.clear_all()
	if spawn_fx_controller != null and spawn_fx_controller.has_method("clear_fx"):
		spawn_fx_controller.clear_fx()
	if fx_pool != null:
		fx_pool.clear()
	fx_pool = null


func shutdown_bridge() -> void:
	clear_bridge()


func dispose() -> void:
	clear_bridge()
	if battle_event_router != null:
		if battle_event_router.explosion_event_routed.is_connected(_on_explosion_event_routed):
			battle_event_router.explosion_event_routed.disconnect(_on_explosion_event_routed)
		if battle_event_router.cell_destroyed_event_routed.is_connected(_on_cell_destroyed_event_routed):
			battle_event_router.cell_destroyed_event_routed.disconnect(_on_cell_destroyed_event_routed)
		if battle_event_router.bubble_placed_event_routed.is_connected(_on_bubble_placed_event_routed):
			battle_event_router.bubble_placed_event_routed.disconnect(_on_bubble_placed_event_routed)
		if battle_event_router.player_revived_event_routed.is_connected(_on_player_revived_event_routed):
			battle_event_router.player_revived_event_routed.disconnect(_on_player_revived_event_routed)
		if battle_event_router.player_trap_executed_event_routed.is_connected(_on_player_trap_executed_event_routed):
			battle_event_router.player_trap_executed_event_routed.disconnect(_on_player_trap_executed_event_routed)
		if battle_event_router.item_spawned_event_routed.is_connected(_on_item_spawned_event_routed):
			battle_event_router.item_spawned_event_routed.disconnect(_on_item_spawned_event_routed)
		if battle_event_router.item_picked_event_routed.is_connected(_on_item_picked_event_routed):
			battle_event_router.item_picked_event_routed.disconnect(_on_item_picked_event_routed)
		if battle_event_router.get_parent() == self:
			remove_child(battle_event_router)
		battle_event_router.free()
		battle_event_router = null
	if actor_registry != null:
		actor_registry.dispose()
		actor_registry = null
	state_to_view_mapper = null
	if spawn_fx_controller != null and spawn_fx_controller.has_method("dispose"):
		spawn_fx_controller.dispose()
	map_view = null
	actor_layer = null
	fx_layer = null
	spawn_fx_controller = null


func debug_dump_actor_summary() -> Dictionary:
	if actor_registry == null:
		return {}
	var dump := actor_registry.debug_dump_actor_summary()
	dump["grid_cells"] = _grid_cache.get("cells", []).size()
	dump["has_map_view"] = map_view != null
	dump["has_spawn_fx_controller"] = spawn_fx_controller != null
	dump["fx_children"] = fx_layer.get_child_count() if fx_layer != null else 0
	return dump


func configure_content_styles(player_style_by_slot: Dictionary, bubble_style_by_slot: Dictionary, bubble_color_by_slot: Dictionary = {}) -> void:
	_bubble_style_by_slot = bubble_style_by_slot.duplicate(true)
	_bubble_color_by_slot = bubble_color_by_slot.duplicate(true)
	if state_to_view_mapper == null:
		return
	state_to_view_mapper.configure_content_styles(player_style_by_slot, bubble_style_by_slot, bubble_color_by_slot)


func configure_player_visual_profiles(player_visual_profiles: Dictionary) -> void:
	_player_visual_profiles = player_visual_profiles.duplicate()
	if actor_registry != null:
		actor_registry.configure_player_visual_profiles(_player_visual_profiles)


func set_local_player_entity_id(entity_id: int) -> void:
	_local_player_entity_id = entity_id
	if state_to_view_mapper == null:
		return
	state_to_view_mapper.set_local_player_entity_id(entity_id)


func _play_battle_sfx_for_events(events: Array) -> void:
	var explosion_count := 0
	for event in events:
		if event == null:
			continue
		match int(event.event_type):
			SimEventScript.EventType.BUBBLE_EXPLODED:
				explosion_count += 1
			_:
				pass
	if explosion_count > 0:
		_play_sfx(
			BattleAudioEventConfigScript.SFX_BUBBLE_EXPLODE,
			BattleAudioEventConfigScript.explosion_volume_boost_db(explosion_count)
		)


func _log_actor_sync_anomalies(world: SimWorld, tick_id: int, events: Array) -> void:
	if actor_registry == null or world == null:
		return
	var actor_summary := actor_registry.debug_dump_actor_summary()
	var world_bubbles := world.state.bubbles.active_ids.size()
	var world_items := world.state.items.active_ids.size()
	var actor_bubbles := int(actor_summary.get("bubbles", 0))
	var actor_items := int(actor_summary.get("items", 0))
	if world_bubbles != actor_bubbles:
		LogPresentationScript.warn(
			"%s[presentation_bridge] anomaly=bubble_view_count_mismatch tick=%d world_bubbles=%d actor_bubbles=%d" % [
				TRACE_PREFIX,
				tick_id,
				world_bubbles,
				actor_bubbles,
			],
			"",
			0,
			"presentation.bridge.anomaly"
		)
	if world_items != actor_items:
		LogPresentationScript.warn(
			"%s[presentation_bridge] anomaly=item_view_count_mismatch tick=%d world_items=%d actor_items=%d" % [
				TRACE_PREFIX,
				tick_id,
				world_items,
				actor_items,
			],
			"",
			0,
			"presentation.bridge.anomaly"
		)
	if _contains_bubble_placed_without_actor(world, events):
		LogPresentationScript.warn(
			"%s[presentation_bridge] anomaly=bubble_placed_without_actor tick=%d world_bubbles=%d actor_bubbles=%d" % [
				TRACE_PREFIX,
				tick_id,
				world_bubbles,
				actor_bubbles,
			],
			"",
			0,
			"presentation.bridge.anomaly"
		)
	if LOG_FX_ANOMALIES and _contains_fx_worthy_event(events) and fx_layer != null and fx_layer.get_child_count() <= 0:
		LogPresentationScript.debug(
			"%s[presentation_bridge] anomaly=events_without_fx tick=%d event_count=%d" % [
				TRACE_PREFIX,
				tick_id,
				events.size(),
			],
			"",
			0,
			"presentation.bridge.fx"
		)


func _contains_fx_worthy_event(events: Array) -> bool:
	for event in events:
		if event == null:
			continue
		match int(event.event_type):
			SimEventScript.EventType.BUBBLE_EXPLODED, \
			SimEventScript.EventType.CELL_DESTROYED, \
			SimEventScript.EventType.ITEM_SPAWNED, \
			SimEventScript.EventType.ITEM_PICKED:
				return true
			_:
				pass
	return false


func _contains_bubble_placed_without_actor(world: SimWorld, events: Array) -> bool:
	if actor_registry == null or world == null:
		return false
	for event in events:
		if event == null or int(event.event_type) != SimEventScript.EventType.BUBBLE_PLACED:
			continue
		var bubble_id := int(event.payload.get("bubble_id", -1))
		if bubble_id < 0:
			continue
		if world.state.bubbles.get_bubble(bubble_id) == null:
			return true
		if actor_registry.get_actor_view(bubble_id) == null:
			return true
	return false


func _log_explosion_events(stage: String, tick_id: int, events: Array) -> void:
	for event in events:
		if event == null or int(event.event_type) != SimEventScript.EventType.BUBBLE_EXPLODED:
			continue
		var covered_cells: Array = event.payload.get("covered_cells", [])
		LogPresentationScript.info(
			"QQT_EXPLOSION_TRACE stage=%s tick=%d event_tick=%d bubble_id=%d owner=%d cell=(%d,%d) covered_cells=%d fx_children=%d payload_keys=%s" % [
				stage,
				tick_id,
				int(event.tick),
				int(event.payload.get("bubble_id", event.payload.get("entity_id", -1))),
				int(event.payload.get("owner_player_id", -1)),
				int(event.payload.get("cell_x", -1)),
				int(event.payload.get("cell_y", -1)),
				covered_cells.size(),
				fx_layer.get_child_count() if fx_layer != null else -1,
				str(event.payload.keys()),
			],
			"",
			0,
			"presentation.bridge.explosion"
		)


func show_prediction_correction(entity_id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	if spawn_fx_controller != null and spawn_fx_controller.has_method("show_prediction_correction"):
		spawn_fx_controller.show_prediction_correction(_fp_to_world_position(from_pos), _fp_to_world_position(to_pos))
	elif fx_layer != null:
		var marker := CorrectionMarkerViewScript.new()
		marker.configure(_fp_to_world_position(from_pos), _fp_to_world_position(to_pos))
		fx_layer.add_child(marker)

	if actor_registry == null:
		return
	var actor: Node = actor_registry.get_actor_view(entity_id)
	if actor != null and actor is CanvasItem:
		(actor as CanvasItem).modulate = Color(1.0, 0.55, 0.55, 1.0)
		var timer := get_tree().create_timer(0.18)
		timer.timeout.connect(func() -> void:
			if actor != null and is_instance_valid(actor) and actor is CanvasItem:
				(actor as CanvasItem).modulate = Color.WHITE
		)


func _on_explosion_event_routed(event: SimEvent) -> void:
	if event == null:
		return
	_log_explosion_events("presentation_route", int(event.tick), [event])
	var owner_player_id := int(event.payload.get("owner_player_id", -1))
	var bubble_style_id := ""
	var bubble_color := Color.WHITE
	var player_actor := actor_registry.get_actor_view(owner_player_id) if actor_registry != null else null
	if player_actor != null:
		var player_slot := -1
		if player_actor is BattlePlayerActorView:
			player_slot = (player_actor as BattlePlayerActorView).player_slot
		bubble_style_id = String(_bubble_style_by_slot.get(player_slot, ""))
		bubble_color = _bubble_color_by_slot.get(player_slot, bubble_color)
	if spawn_fx_controller != null and spawn_fx_controller.has_method("spawn_explosion"):
		spawn_fx_controller.spawn_explosion(event, cell_size, bubble_style_id, bubble_color)
		return
	if fx_layer == null:
		return

	var cells: Array[Vector2i] = []
	for cell in event.payload.get("covered_cells", []):
		cells.append(cell)

	var view: BattleExplosionActorView = fx_pool.acquire("explosion", fx_layer, func(v: Node):
		(v as BattleExplosionActorView).configure(cells, cell_size, bubble_style_id, bubble_color))
	view.finished.connect(_on_explosion_finished.bind(view), CONNECT_ONE_SHOT)


func _on_cell_destroyed_event_routed(event: SimEvent) -> void:
	if event == null or fx_layer == null:
		return
	var destroyed_cell := Vector2i(
		int(event.payload.get("cell_x", 0)),
		int(event.payload.get("cell_y", 0))
	)
	var fx = fx_pool.acquire("brick_break", fx_layer, func(v: Node):
		(v as BrickBreakFxPlayer).configure(_to_world_center(destroyed_cell), cell_size))
	fx.finished.connect(_on_brick_break_finished.bind(fx), CONNECT_ONE_SHOT)


func _on_item_spawned_event_routed(event: SimEvent) -> void:
	if event == null or fx_layer == null:
		return
	var fx = ItemSpawnFxPlayerScript.new()
	fx.configure(
		_to_world_center(Vector2i(
			int(event.payload.get("cell_x", 0)),
			int(event.payload.get("cell_y", 0))
		)),
		cell_size,
		int(event.payload.get("item_type", 0))
	)
	fx_layer.add_child(fx)


func _on_item_picked_event_routed(event: SimEvent) -> void:
	if event == null or fx_layer == null:
		return
	if int(event.payload.get("player_id", -1)) == _local_player_entity_id:
		_play_sfx(BattleAudioEventConfigScript.SFX_ITEM_PICK)
	var fx = ItemPickupFxPlayerScript.new()
	fx.configure(
		_to_world_center(Vector2i(
			int(event.payload.get("cell_x", 0)),
			int(event.payload.get("cell_y", 0))
		)),
		cell_size,
		int(event.payload.get("item_type", 0))
	)
	fx_layer.add_child(fx)


func _on_bubble_placed_event_routed(event: SimEvent) -> void:
	if event == null:
		return
	if int(event.payload.get("owner_player_id", -1)) != _local_player_entity_id:
		return
	_play_sfx(BattleAudioEventConfigScript.SFX_BUBBLE_PLACE)


func _on_player_revived_event_routed(event: SimEvent) -> void:
	if event == null:
		return
	_play_sfx(BattleAudioEventConfigScript.SFX_JELLY_RESCUED)


func _on_player_trap_executed_event_routed(event: SimEvent) -> void:
	if event == null:
		return
	_play_sfx(BattleAudioEventConfigScript.SFX_JELLY_EXECUTED)


func _play_sfx(audio_id: String, volume_offset_db: float = 0.0) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.call("play_sfx", audio_id, volume_offset_db)


func _to_world_center(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) + 0.5) * cell_size,
		(float(cell.y) + 0.5) * cell_size
	)


func _fp_to_world_position(fp_pos: Vector2i) -> Vector2:
	return Vector2(
		(float(fp_pos.x) / float(WorldMetrics.CELL_UNITS)) * cell_size,
		(float(fp_pos.y) / float(WorldMetrics.CELL_UNITS)) * cell_size
	)


func _on_explosion_finished(view: BattleExplosionActorView) -> void:
	if fx_pool != null:
		fx_pool.release("explosion", view)


func _on_brick_break_finished(fx: BrickBreakFxPlayer) -> void:
	if fx_pool != null:
		fx_pool.release("brick_break", fx)
