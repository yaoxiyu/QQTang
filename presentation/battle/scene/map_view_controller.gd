class_name BattleMapViewController
extends Node2D

const TilePresentationLoaderScript = preload("res://content/tiles/runtime/tile_presentation_loader.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const MapThemeMaterialRegistryScript = preload("res://presentation/battle/scene/map_theme_material_registry.gd")
const MapSurfaceElementViewScript = preload("res://presentation/battle/scene/map_surface_element_view.gd")

@export var ground_layer_path: NodePath = ^"GroundLayer"
@export var surface_layer_path: NodePath = ^"SurfaceLayer"
@export var static_block_layer_path: NodePath = ^"StaticBlockLayer"
@export var breakable_block_layer_path: NodePath = ^"BreakableBlockLayer"
@export var occluder_layer_path: NodePath = ^"../OccluderLayer"
@export var actor_layer_path: NodePath = ^"../ActorLayer"

var cell_size: float = BattleViewMetrics.DEFAULT_CELL_PIXELS

var ground_layer: Node2D = null
var surface_layer: Node2D = null
var static_block_layer: Node2D = null
var breakable_block_layer: Node2D = null
var occluder_layer: Node2D = null
var actor_layer: Node2D = null

var _grid_cache: Dictionary = {}
var _runtime_layout: MapRuntimeLayout = null
var _map_theme: MapThemeDef = null
var _theme_materials: Dictionary = {}
var _ground_views_by_cell: Dictionary = {}
var _spawn_marker_views_by_cell: Dictionary = {}
var _surface_views: Array[Node] = []
var _breakable_views_by_cell: Dictionary = {}
var _static_views_by_cell: Dictionary = {}
var _occluder_views: Array[Node] = []
var _animation_frames_cache: Dictionary = {}
var _sprite_frames_cache: Dictionary = {}
var _warmup_samples: Dictionary = {}
var _destroy_latency_logged_once: bool = false
var _tile_palette: Dictionary = {
	"ground": Color(0.88, 0.88, 0.82, 1.0),
	"solid": Color(0.20, 0.22, 0.28, 1.0),
	"breakable": Color(0.70, 0.50, 0.28, 1.0),
	"spawn": Color(0.24, 0.42, 0.26, 1.0),
	"grid_line": Color(0.10, 0.12, 0.18, 0.35),
	"occluder": Color(0.31, 0.48, 0.32, 1.0),
}


func _ready() -> void:
	_bind_layers()


func configure_map_presentation(layout: MapRuntimeLayout, map_theme: MapThemeDef, p_cell_size: float) -> void:
	_bind_layers()
	_runtime_layout = layout
	_map_theme = map_theme
	cell_size = p_cell_size
	if _map_theme != null:
		_theme_materials = MapThemeMaterialRegistryScript.get_theme_materials(String(_map_theme.theme_id))
		apply_tile_palette(_map_theme.tile_palette)
	_clear_runtime_layers()
	_rebuild_ground_tiles()
	_rebuild_static_blocks()
	_rebuild_breakable_blocks()
	_rebuild_surface_entries()
	_rebuild_occluders()
	_schedule_surface_gpu_warmup()


func apply_grid_cache(grid_cache: Dictionary, p_cell_size: float) -> void:
	_grid_cache = grid_cache.duplicate(true)
	cell_size = p_cell_size
	_sync_ground_tiles_from_grid_cache()
	_sync_breakable_views_from_grid_cache()


func clear_map() -> void:
	_grid_cache.clear()
	_runtime_layout = null
	_map_theme = null
	_theme_materials.clear()
	_animation_frames_cache.clear()
	_sprite_frames_cache.clear()
	_warmup_samples.clear()
	_destroy_latency_logged_once = false
	_clear_runtime_layers()


func apply_map_theme(map_theme: MapThemeDef) -> void:
	if map_theme == null:
		return
	_map_theme = map_theme
	_theme_materials = MapThemeMaterialRegistryScript.get_theme_materials(String(map_theme.theme_id))
	apply_tile_palette(map_theme.tile_palette)
	_rebuild_ground_tiles()
	_rebuild_static_blocks()


func apply_tile_palette(tile_palette: Dictionary) -> void:
	if tile_palette.is_empty():
		return
	_tile_palette = _tile_palette.duplicate(true)
	for key in ["ground", "solid", "breakable", "spawn", "grid_line", "occluder"]:
		if tile_palette.has(key):
			_tile_palette[key] = tile_palette[key]


func handle_cell_destroyed(cell: Vector2i) -> void:
	if not _breakable_views_by_cell.has(cell):
		return
	var view : Node2D = _breakable_views_by_cell[cell]
	_breakable_views_by_cell.erase(cell)
	if view == null or not is_instance_valid(view):
		return
	var destroy_start_ms := Time.get_ticks_msec()
	if view.has_method("on_destroyed"):
		view.on_destroyed()
	elif view.has_method("play_die_and_dispose"):
		view.play_die_and_dispose()
	elif view.has_method("play_break_and_dispose"):
		view.play_break_and_dispose()
	else:
		view.queue_free()
	if not _destroy_latency_logged_once:
		_destroy_latency_logged_once = true
		var destroy_elapsed_ms := Time.get_ticks_msec() - destroy_start_ms
		print("[SURFACE_WARMUP] first_destroy_dispatch_ms=%d cell=(%d,%d)" % [destroy_elapsed_ms, cell.x, cell.y])


func handle_cell_triggered(cell: Vector2i) -> void:
	if not _breakable_views_by_cell.has(cell):
		return
	var view : Node2D = _breakable_views_by_cell[cell]
	if view == null or not is_instance_valid(view):
		return
	if view.has_method("on_triggered"):
		view.on_triggered()
	elif view.has_method("play_trigger_animation"):
		view.play_trigger_animation()


func debug_dump_map_state() -> Dictionary:
	return {
		"grid_cells": _grid_cache.get("cells", []).size(),
		"cell_size": cell_size,
		"static_block_views": _static_views_by_cell.size(),
		"breakable_block_views": _breakable_views_by_cell.size(),
		"occluder_views": _occluder_views.size(),
	}


func _bind_layers() -> void:
	if ground_layer == null and has_node(ground_layer_path):
		ground_layer = get_node(ground_layer_path) as Node2D
	if surface_layer == null and has_node(surface_layer_path):
		surface_layer = get_node(surface_layer_path) as Node2D
	if static_block_layer == null and has_node(static_block_layer_path):
		static_block_layer = get_node(static_block_layer_path) as Node2D
	if breakable_block_layer == null and has_node(breakable_block_layer_path):
		breakable_block_layer = get_node(breakable_block_layer_path) as Node2D
	if occluder_layer == null and has_node(occluder_layer_path):
		occluder_layer = get_node(occluder_layer_path) as Node2D
	if actor_layer == null and has_node(actor_layer_path):
		actor_layer = get_node(actor_layer_path) as Node2D


func _clear_runtime_layers() -> void:
	_clear_layer(ground_layer)
	_clear_layer(surface_layer)
	_clear_layer(static_block_layer)
	_clear_layer(breakable_block_layer)
	_clear_layer(occluder_layer)
	_ground_views_by_cell.clear()
	_spawn_marker_views_by_cell.clear()
	_surface_views.clear()
	_static_views_by_cell.clear()
	_breakable_views_by_cell.clear()
	_occluder_views.clear()


func _clear_layer(layer: Node) -> void:
	if layer == null:
		return
	for child in layer.get_children():
		child.queue_free()


func _rebuild_static_blocks() -> void:
	_clear_layer(static_block_layer)
	_static_views_by_cell.clear()
	if _runtime_layout == null or static_block_layer == null:
		return
	if not _runtime_layout.surface_entries.is_empty():
		return
	var solid_texture := _theme_materials.get("solid_base", null) as Texture2D
	for cell in _runtime_layout.solid_cells:
		var node: Node2D = null
		if solid_texture != null:
			node = _build_textured_cell_sprite(solid_texture, cell)
		elif _map_theme != null:
			var presentation_id := String(_map_theme.solid_presentation_id)
			var presentation := TilePresentationLoaderScript.load_tile_presentation(presentation_id)
			if presentation != null and presentation.tile_scene != null:
				var view := presentation.tile_scene.instantiate()
				if view != null and view is Node2D:
					node = view as Node2D
					node.position = Vector2(cell.x, cell.y) * cell_size
					if node.has_method("configure"):
						node.configure(
							cell_size,
							_resolve_palette_color("solid", Color(0.20, 0.22, 0.28, 1.0)),
							float(presentation.height_px)
						)
		if node == null:
			continue
		static_block_layer.add_child(node)
		_static_views_by_cell[cell] = node


func _rebuild_breakable_blocks() -> void:
	_clear_layer(breakable_block_layer)
	_breakable_views_by_cell.clear()
	if _runtime_layout == null or _map_theme == null or breakable_block_layer == null:
		return
	if not _runtime_layout.surface_entries.is_empty():
		return
	var presentation_id := String(_map_theme.breakable_presentation_id)
	var presentation := TilePresentationLoaderScript.load_tile_presentation(presentation_id)
	if presentation == null or presentation.tile_scene == null:
		return
	var breakable_texture := _theme_materials.get("breakable_block", null) as Texture2D
	for cell in _runtime_layout.breakable_cells:
		var view := presentation.tile_scene.instantiate()
		if view == null or not view is Node2D:
			continue
		var node := view as Node2D
		node.position = Vector2(cell.x, cell.y) * cell_size
		if node.has_method("configure"):
			node.configure(
				cell_size,
				_resolve_palette_color("breakable", Color(0.70, 0.50, 0.28, 1.0)),
				float(presentation.height_px)
			)
		if breakable_texture != null and node.has_method("set_texture"):
			node.set_texture(breakable_texture)
		breakable_block_layer.add_child(node)
		_breakable_views_by_cell[cell] = node


func _rebuild_occluders() -> void:
	_clear_layer(occluder_layer)
	_occluder_views.clear()
	if _runtime_layout == null or occluder_layer == null:
		return
	for entry in _runtime_layout.surface_entries:
		if String(entry.get("render_role", "surface")) != "occluder":
			continue
		var stand_path := String(entry.get("texture_path", "")).strip_edges()
		var stand_frames := _resolve_animation_frames(stand_path)
		var texture := _load_texture_with_gif_fallback(stand_path, stand_frames)
		if texture == null:
			continue
		var node: Node2D = _build_surface_element_view(entry, texture)
		occluder_layer.add_child(node)
		_occluder_views.append(node)


func _rebuild_surface_entries() -> void:
	_clear_layer(surface_layer)
	_surface_views.clear()
	if _runtime_layout == null or surface_layer == null:
		return
	var entries := _runtime_layout.surface_entries.duplicate(true)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left_key := a.get("sort_key", Vector3i.ZERO) as Vector3i
		var right_key := b.get("sort_key", Vector3i.ZERO) as Vector3i
		if left_key.x != right_key.x:
			return left_key.x < right_key.x
		if left_key.y != right_key.y:
			return left_key.y < right_key.y
		return left_key.z < right_key.z
	)
	for entry in entries:
		if String(entry.get("render_role", "surface")) == "occluder":
			continue
		var stand_path := String(entry.get("texture_path", "")).strip_edges()
		var stand_frames := _resolve_animation_frames(stand_path)
		var texture := _load_texture_with_gif_fallback(stand_path, stand_frames)
		if texture == null:
			continue
		var node: Node2D = _build_surface_element_view(entry, texture)
		surface_layer.add_child(node)
		_surface_views.append(node)
		if String(entry.get("interaction_kind", "solid")) == "breakable":
			var cell := entry.get("cell", Vector2i.ZERO) as Vector2i
			_breakable_views_by_cell[cell] = node


func _rebuild_ground_tiles() -> void:
	_clear_layer(ground_layer)
	_ground_views_by_cell.clear()
	_spawn_marker_views_by_cell.clear()
	if _runtime_layout == null or ground_layer == null:
		return
	for entry in _runtime_layout.floor_tile_entries:
		var texture := load(String(entry.get("texture_path", ""))) as Texture2D
		var rect := entry.get("rect", Rect2i()) as Rect2i
		if texture == null or rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(rect.position.x, rect.position.y) * cell_size
		var target_size := Vector2(float(rect.size.x) * cell_size, float(rect.size.y) * cell_size)
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			sprite.scale = Vector2(
				target_size.x / texture_size.x,
				target_size.y / texture_size.y
			)
		else:
			sprite.scale = Vector2.ONE
		sprite.z_as_relative = false
		sprite.z_index = BattleDepth.ground_z(rect.position)
		ground_layer.add_child(sprite)
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				var cell := Vector2i(x, y)
				_ground_views_by_cell[cell] = sprite


func _sync_ground_tiles_from_grid_cache() -> void:
	if ground_layer == null or _grid_cache.is_empty():
		return
	var alive_spawn_cells := {}
	for cell_data in _grid_cache.get("cells", []):
		var cell := Vector2i(int(cell_data.get("x", 0)), int(cell_data.get("y", 0)))
		var tile_type := int(cell_data.get("tile_type", TileConstants.TileType.EMPTY))
		if tile_type == TileConstants.TileType.SPAWN:
			alive_spawn_cells[cell] = true
			_ensure_spawn_marker_view(cell)
		elif _spawn_marker_views_by_cell.has(cell):
			var marker := _spawn_marker_views_by_cell[cell] as Node
			_spawn_marker_views_by_cell.erase(cell)
			if marker != null and is_instance_valid(marker):
				marker.queue_free()
	for cell_variant in _spawn_marker_views_by_cell.keys():
		var existing_cell := cell_variant as Vector2i
		if alive_spawn_cells.has(existing_cell):
			continue
		var spawn_view := _spawn_marker_views_by_cell[existing_cell] as Node
		_spawn_marker_views_by_cell.erase(existing_cell)
		if spawn_view != null and is_instance_valid(spawn_view):
			spawn_view.queue_free()


func _sync_breakable_views_from_grid_cache() -> void:
	if breakable_block_layer == null or _map_theme == null:
		return
	var alive_breakable_cells := {}
	var presentation_id := String(_map_theme.breakable_presentation_id)
	var presentation := TilePresentationLoaderScript.load_tile_presentation(presentation_id)
	if presentation == null or presentation.tile_scene == null:
		return
	var breakable_texture := _theme_materials.get("breakable_block", null) as Texture2D
	for cell_data in _grid_cache.get("cells", []):
		if int(cell_data.get("tile_type", TileConstants.TileType.EMPTY)) != TileConstants.TileType.BREAKABLE_BLOCK:
			continue
		var cell := Vector2i(int(cell_data.get("x", 0)), int(cell_data.get("y", 0)))
		alive_breakable_cells[cell] = true
		if _breakable_views_by_cell.has(cell):
			continue
		var view := presentation.tile_scene.instantiate()
		if view == null or not view is Node2D:
			continue
		var node := view as Node2D
		node.position = Vector2(cell.x, cell.y) * cell_size
		if node.has_method("configure"):
			node.configure(
				cell_size,
				_resolve_palette_color("breakable", Color(0.70, 0.50, 0.28, 1.0)),
				float(presentation.height_px)
			)
		if breakable_texture != null and node.has_method("set_texture"):
			node.set_texture(breakable_texture)
		breakable_block_layer.add_child(node)
		_breakable_views_by_cell[cell] = node

	var stale_cells: Array[Vector2i] = []
	for cell_variant in _breakable_views_by_cell.keys():
		var cell := cell_variant as Vector2i
		if alive_breakable_cells.has(cell):
			continue
		stale_cells.append(cell)

	for cell in stale_cells:
		handle_cell_destroyed(cell)


func _ensure_ground_view(cell: Vector2i) -> void:
	if _ground_views_by_cell.has(cell):
		return
	var ground_texture := _select_ground_texture(cell)
	if ground_texture == null:
		return
	var sprite := _build_textured_cell_sprite(ground_texture, cell)
	sprite.z_as_relative = false
	sprite.z_index = BattleDepth.ground_z(cell)
	ground_layer.add_child(sprite)
	_ground_views_by_cell[cell] = sprite
func _ensure_spawn_marker_view(cell: Vector2i) -> void:
	if _spawn_marker_views_by_cell.has(cell):
		return
	var spawn_texture := _theme_materials.get("spawn_marker", null) as Texture2D
	if spawn_texture == null:
		return
	var sprite := _build_textured_cell_sprite(spawn_texture, cell)
	sprite.z_as_relative = false
	sprite.z_index = BattleDepth.spawn_marker_z(cell)
	ground_layer.add_child(sprite)
	_spawn_marker_views_by_cell[cell] = sprite


func _select_ground_texture(cell: Vector2i) -> Texture2D:
	var base_texture := _theme_materials.get("ground", null) as Texture2D
	var variants := _theme_materials.get("ground_variants", []) as Array
	if variants.is_empty():
		return base_texture
	var hash_value := _stable_cell_hash(cell)
	if hash_value % 11 == 0:
		return variants[0] as Texture2D
	if hash_value % 17 == 0 and variants.size() > 1:
		return variants[1] as Texture2D
	return base_texture


func _build_textured_cell_sprite(texture: Texture2D, cell: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(cell.x, cell.y) * cell_size
	sprite.scale = _resolve_texture_scale(texture)
	return sprite


func _build_surface_element_view(entry: Dictionary, texture: Texture2D) -> Node2D:
	var die_path := String(entry.get("die_texture_path", "")).strip_edges()
	var trigger_path := String(entry.get("trigger_texture_path", "")).strip_edges()
	var stand_path := String(entry.get("texture_path", "")).strip_edges()
	var stand_frames := _resolve_animation_frames(stand_path)
	var die_frames := _resolve_animation_frames(die_path)
	var trigger_frames := _resolve_animation_frames(trigger_path)
	var stand_fps: float = max(float(entry.get("stand_fps", 12.0)), 1.0)
	var die_fps: float = max(float(entry.get("die_fps", 12.0)), 1.0)
	var trigger_fps: float = max(float(entry.get("trigger_fps", 12.0)), 1.0)
	var stand_sprite_frames := _resolve_sprite_frames_cached(stand_path, stand_frames, stand_fps, true)
	var die_sprite_frames := _resolve_sprite_frames_cached(die_path, die_frames, die_fps, false)
	var trigger_sprite_frames := _resolve_sprite_frames_cached(trigger_path, trigger_frames, trigger_fps, false)
	var die_texture := _load_texture_with_gif_fallback(die_path, die_frames)
	var trigger_texture := _load_texture_with_gif_fallback(trigger_path, trigger_frames)
	var view: Node2D = MapSurfaceElementViewScript.new()
	view.configure(
		entry,
		cell_size,
		texture,
		die_texture,
		trigger_texture,
		stand_frames,
		die_frames,
		trigger_frames,
		stand_sprite_frames,
		die_sprite_frames,
		trigger_sprite_frames
	)
	return view


func _resolve_sprite_frames_cached(path: String, frames: Array[Texture2D], fps: float, loop_enabled: bool) -> SpriteFrames:
	if frames.is_empty():
		return null
	var key := "%s|fps=%.3f|loop=%s" % [path.strip_edges(), fps, "true" if loop_enabled else "false"]
	if _sprite_frames_cache.has(key):
		var cached: Variant = _sprite_frames_cache[key]
		if cached is SpriteFrames:
			return cached as SpriteFrames
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("active")
	sprite_frames.set_animation_speed("active", fps)
	sprite_frames.set_animation_loop("active", loop_enabled)
	for frame in frames:
		if frame != null:
			sprite_frames.add_frame("active", frame)
	if sprite_frames.get_frame_count("active") <= 0:
		return null
	_sprite_frames_cache[key] = sprite_frames
	_register_warmup_sample(path, frames[0])
	return sprite_frames


func _register_warmup_sample(path: String, texture: Texture2D) -> void:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty() or texture == null:
		return
	if not _warmup_samples.has(normalized_path):
		_warmup_samples[normalized_path] = texture


func _schedule_surface_gpu_warmup() -> void:
	if _warmup_samples.is_empty():
		return
	call_deferred("_run_surface_gpu_warmup")


func _run_surface_gpu_warmup() -> void:
	if not is_inside_tree():
		return
	var samples: Array[Texture2D] = []
	for value in _warmup_samples.values():
		if value is Texture2D:
			samples.append(value as Texture2D)
	if samples.is_empty():
		return
	var warmup_root := Node2D.new()
	warmup_root.name = "SurfaceWarmupRoot"
	warmup_root.visible = true
	warmup_root.modulate = Color(1.0, 1.0, 1.0, 0.001)
	warmup_root.position = Vector2(-100000.0, -100000.0)
	add_child(warmup_root)
	var warmup_start_ms := Time.get_ticks_msec()
	for texture in samples:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = texture
		warmup_root.add_child(sprite)
	await get_tree().process_frame
	warmup_root.queue_free()
	var warmup_elapsed_ms := Time.get_ticks_msec() - warmup_start_ms
	print("[SURFACE_WARMUP] textures=%d gpu_warmup_ms=%d" % [samples.size(), warmup_elapsed_ms])


func _load_texture_with_gif_fallback(texture_path: String, frames: Array[Texture2D] = []) -> Texture2D:
	var normalized_path := texture_path.strip_edges()
	if normalized_path.is_empty():
		return null
	if _is_gif_path(normalized_path):
		if frames.size() > 0:
			return frames[0]
		return null
	return load(normalized_path) as Texture2D


func _is_gif_path(path: String) -> bool:
	return path.to_lower().ends_with(".gif")


func _resolve_animation_frames(texture_path: String) -> Array[Texture2D]:
	var normalized_path := texture_path.strip_edges()
	if normalized_path.is_empty() or not _is_gif_path(normalized_path):
		return []
	if _animation_frames_cache.has(normalized_path):
		var cached = _animation_frames_cache[normalized_path]
		if cached is Array:
			var result: Array[Texture2D] = []
			for frame in cached:
				if frame is Texture2D:
					result.append(frame)
			return result
		return []
	var base_dir := normalized_path.get_base_dir()
	var stem := normalized_path.get_file().get_basename()
	var anim_dir := "%s/anim/%s" % [base_dir, stem]
	var frames: Array[Texture2D] = []
	var dir := DirAccess.open(anim_dir)
	if dir != null:
		var files := dir.get_files()
		files.sort()
		for file_name in files:
			if not file_name.to_lower().ends_with(".png"):
				continue
			var frame_texture := load("%s/%s" % [anim_dir, file_name]) as Texture2D
			if frame_texture != null:
				frames.append(frame_texture)
	_animation_frames_cache[normalized_path] = frames.duplicate()
	return frames

func _resolve_texture_scale(texture: Texture2D) -> Vector2:
	return Vector2.ONE


func _stable_cell_hash(cell: Vector2i) -> int:
	var hash_value := int((cell.x * 73856093) ^ (cell.y * 19349663))
	return absi(hash_value)


func _resolve_palette_color(key: String, fallback: Color) -> Color:
	var color_value = _tile_palette.get(key, fallback)
	if color_value is Color:
		return color_value
	return fallback
