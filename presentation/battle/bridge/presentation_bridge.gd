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

@export var map_view_path: NodePath = ^"../../WorldRoot/MapRoot"
@export var actor_layer_path: NodePath = ^"../../WorldRoot/ActorLayer"
@export var fx_layer_path: NodePath = ^"../../WorldRoot/FxLayer"
@export var spawn_fx_controller_path: NodePath = ^"../../SpawnFxController"
@export var cell_size: float = 48.0
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
var _player_visual_profiles: Dictionary = {}
var _bubble_style_by_slot: Dictionary = {}
var _bubble_color_by_slot: Dictionary = {}

var _last_consumed_tick: int = -1


func _ready() -> void:
	if has_node(map_view_path):
		map_view = get_node(map_view_path)
	if has_node(actor_layer_path):
		actor_layer = get_node(actor_layer_path)
		if actor_layer != null:
			actor_layer.z_as_relative = false
			actor_layer.z_index = 100
	if has_node(fx_layer_path):
		fx_layer = get_node(fx_layer_path)
		if fx_layer != null:
			fx_layer.z_as_relative = false
			fx_layer.z_index = 200
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
	battle_event_router.item_spawned_event_routed.connect(_on_item_spawned_event_routed)
	battle_event_router.item_picked_event_routed.connect(_on_item_picked_event_routed)


func consume_tick_result(_result: Dictionary, world: SimWorld, events: Array = []) -> void:
	if world == null or actor_layer == null:
		return

	var tick_id := int(world.state.match_state.tick)
	if tick_id == _last_consumed_tick:
		return

	_grid_cache = state_to_view_mapper.build_grid_cache(world)
	if map_view != null and map_view.has_method("apply_grid_cache"):
		map_view.apply_grid_cache(_grid_cache, cell_size)
	actor_registry.sync_players(actor_layer, state_to_view_mapper.build_player_views(world))
	actor_registry.sync_bubbles(actor_layer, state_to_view_mapper.build_bubble_views(world))
	actor_registry.sync_items(actor_layer, state_to_view_mapper.build_item_views(world))
	battle_event_router.route_events(events)
	_last_consumed_tick = tick_id


func clear_bridge() -> void:
	_last_consumed_tick = -1
	_grid_cache.clear()
	if map_view != null and map_view.has_method("clear_map"):
		map_view.clear_map()
	if actor_registry != null:
		actor_registry.clear_all()
	if spawn_fx_controller != null and spawn_fx_controller.has_method("clear_fx"):
		spawn_fx_controller.clear_fx()
	elif fx_layer != null:
		for child in fx_layer.get_children():
			child.free()


func shutdown_bridge() -> void:
	clear_bridge()


func dispose() -> void:
	clear_bridge()
	if battle_event_router != null:
		if battle_event_router.explosion_event_routed.is_connected(_on_explosion_event_routed):
			battle_event_router.explosion_event_routed.disconnect(_on_explosion_event_routed)
		if battle_event_router.cell_destroyed_event_routed.is_connected(_on_cell_destroyed_event_routed):
			battle_event_router.cell_destroyed_event_routed.disconnect(_on_cell_destroyed_event_routed)
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


func show_prediction_correction(entity_id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	if spawn_fx_controller != null and spawn_fx_controller.has_method("show_prediction_correction"):
		spawn_fx_controller.show_prediction_correction(_to_world_center(from_pos), _to_world_center(to_pos))
	elif fx_layer != null:
		var marker := CorrectionMarkerViewScript.new()
		marker.configure(_to_world_center(from_pos), _to_world_center(to_pos))
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
	var owner_player_id := int(event.payload.get("owner_player_id", -1))
	var bubble_style_id := ""
	var bubble_color := Color.WHITE
	var player_actor := actor_registry.get_actor_view(owner_player_id) if actor_registry != null else null
	if player_actor != null:
		var player_slot := int(player_actor.get("player_slot"))
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

	var view: BattleExplosionActorView = ExplosionActorViewScript.new()
	view.configure(cells, cell_size, bubble_style_id, bubble_color)
	fx_layer.add_child(view)


func _on_cell_destroyed_event_routed(event: SimEvent) -> void:
	if event == null or fx_layer == null:
		return
	var fx = BrickBreakFxPlayerScript.new()
	fx.configure(
		_to_world_center(Vector2i(
			int(event.payload.get("cell_x", 0)),
			int(event.payload.get("cell_y", 0))
		)),
		cell_size
	)
	fx_layer.add_child(fx)


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


func _to_world_center(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) + 0.5) * cell_size,
		(float(cell.y) + 0.5) * cell_size
	)
