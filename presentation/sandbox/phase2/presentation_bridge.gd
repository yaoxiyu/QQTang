class_name Phase2PresentationBridge
extends Node2D

const ActorRegistryScript = preload("res://presentation/sandbox/phase2/actor_registry.gd")
const StateToViewMapperScript = preload("res://presentation/sandbox/phase2/state_to_view_mapper.gd")
const ExplosionActorViewScript = preload("res://presentation/sandbox/phase2/explosion_actor_view.gd")

@export var actor_layer_path: NodePath = ^"ActorLayer"
@export var fx_layer_path: NodePath = ^"FxLayer"
@export var debug_draw_layer_path: NodePath = ^"DebugDrawLayer"
@export var cell_size: float = 48.0

var actor_layer: Node2D = null
var fx_layer: Node2D = null
var debug_draw_layer: Node2D = null

var _grid_cache: Dictionary = {}
var _actor_registry: Phase2ActorRegistry = null
var _mapper: Phase2StateToViewMapper = null
var _last_explosion_tick: int = -1


func _ready() -> void:
	if has_node(actor_layer_path):
		actor_layer = get_node(actor_layer_path)
	if has_node(fx_layer_path):
		fx_layer = get_node(fx_layer_path)
	if has_node(debug_draw_layer_path):
		debug_draw_layer = get_node(debug_draw_layer_path)

	_actor_registry = ActorRegistryScript.new()
	_mapper = StateToViewMapperScript.new()
	_mapper.cell_size = cell_size


func configure_from_world(world: SimWorld) -> void:
	if _mapper == null:
		return
	_grid_cache = _mapper.build_grid_cache(world)
	_last_explosion_tick = -1
	if _actor_registry != null:
		_actor_registry.clear_all()
	queue_redraw()


func render_world(world: SimWorld, events: Array, _metrics: Dictionary) -> void:
	if _actor_registry == null or _mapper == null or world == null:
		return
	if actor_layer == null:
		return

	_grid_cache = _mapper.build_grid_cache(world)
	queue_redraw()

	_actor_registry.sync_items(actor_layer, _mapper.build_item_views(world))
	_actor_registry.sync_players(actor_layer, _mapper.build_player_views(world))
	_actor_registry.sync_bubbles(actor_layer, _mapper.build_bubble_views(world))
	_render_events(events, int(world.state.match_state.tick))


func _render_events(events: Array, tick_id: int) -> void:
	if fx_layer == null or tick_id == _last_explosion_tick:
		return

	for event in events:
		if event == null:
			continue
		if int(event.event_type) != SimEvent.EventType.BUBBLE_EXPLODED:
			continue

		var cells: Array[Vector2i] = []
		for cell in event.payload.get("covered_cells", []):
			cells.append(cell)

		var view: Phase2ExplosionActorView = ExplosionActorViewScript.new()
		view.configure(cells, cell_size)
		fx_layer.add_child(view)

	_last_explosion_tick = tick_id


func _draw() -> void:
	if _grid_cache.is_empty():
		return

	for cell_data in _grid_cache.get("cells", []):
		var tile_type := int(cell_data.get("tile_type", TileConstants.TileType.EMPTY))
		var x := int(cell_data.get("x", 0))
		var y := int(cell_data.get("y", 0))
		var rect := Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size)

		draw_rect(rect, _tile_color(tile_type), true)
		draw_rect(rect, Color(0.10, 0.12, 0.18, 0.65), false, 1.0)


func _tile_color(tile_type: int) -> Color:
	match tile_type:
		TileConstants.TileType.SOLID_WALL:
			return Color(0.20, 0.22, 0.28, 1.0)
		TileConstants.TileType.BREAKABLE_BLOCK:
			return Color(0.70, 0.50, 0.28, 1.0)
		TileConstants.TileType.SPAWN:
			return Color(0.24, 0.42, 0.26, 1.0)
		_:
			return Color(0.88, 0.88, 0.82, 1.0)
