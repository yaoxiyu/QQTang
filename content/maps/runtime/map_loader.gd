class_name MapLoader
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapRuntimeLayoutScript = preload("res://content/maps/runtime/map_runtime_layout.gd")


static func load_map_config(map_id: String) -> Dictionary:
	if map_id.is_empty() or not MapCatalogScript.has_map(map_id):
		push_error("MapLoader.load_map_config failed: unknown map_id=%s" % map_id)
		return {}

	var map_resource := load_map_resource(map_id)
	if map_resource != null:
		return _build_config_from_resource(map_resource)

	var def_path := MapCatalogScript.get_map_def_path(map_id)
	if def_path.is_empty():
		push_error("MapLoader.load_map_config failed: missing map def path for map_id=%s" % map_id)
		return {}

	var map_script := load(def_path)
	if map_script == null:
		push_error("MapLoader.load_map_config failed: unable to load map def script path=%s" % def_path)
		return {}
	if not map_script.has_method("build"):
		push_error("MapLoader.load_map_config failed: map def has no build() path=%s" % def_path)
		return {}

	var config_value = map_script.build()
	if not (config_value is Dictionary):
		push_error("MapLoader.load_map_config failed: build() did not return Dictionary path=%s" % def_path)
		return {}

	var config: Dictionary = config_value
	if not _validate_map_config(config):
		push_error("MapLoader.load_map_config failed: invalid map config map_id=%s" % map_id)
		return {}

	return config.duplicate(true)


static func load_map_metadata(map_id: String) -> Dictionary:
	var map_resource := load_map_resource(map_id)
	if map_resource != null:
		return map_resource.to_metadata()
	var layout := load_runtime_layout(map_id)
	if layout == null:
		return {}
	var map_metadata := MapCatalogScript.get_map_metadata(map_id)
	return {
		"map_id": layout.map_id,
		"display_name": layout.display_name,
		"version": layout.version,
		"width": layout.width,
		"height": layout.height,
		"spawn_points": layout.spawn_points.duplicate(),
		"item_spawn_profile_id": layout.item_spawn_profile_id,
		"content_hash": layout.content_hash,
		"bound_mode_id": String(map_metadata.get("bound_mode_id", "")),
		"bound_rule_set_id": String(map_metadata.get("bound_rule_set_id", "")),
		"match_format_id": String(map_metadata.get("match_format_id", "2v2")),
		"required_team_count": int(map_metadata.get("required_team_count", 2)),
		"max_player_count": int(map_metadata.get("max_player_count", layout.spawn_points.size())),
		"custom_room_enabled": bool(map_metadata.get("custom_room_enabled", true)),
		"matchmaking_casual_enabled": bool(map_metadata.get("matchmaking_casual_enabled", true)),
		"matchmaking_ranked_enabled": bool(map_metadata.get("matchmaking_ranked_enabled", false)),
		"sort_order": int(map_metadata.get("sort_order", 0)),
		"resource_path": MapCatalogScript.get_map_path(map_id),
		"is_formal": bool(map_metadata.get("is_formal", true)),
		"debug_only": bool(map_metadata.get("debug_only", false)),
	}


static func load_runtime_layout(map_id: String) -> MapRuntimeLayout:
	var map_resource := load_map_resource(map_id)
	if map_resource != null:
		return _build_layout_from_resource(map_resource)
	var config := load_map_config(map_id)
	if config.is_empty():
		return null
	return _build_layout_from_config(config)


static func build_grid_state(map_id: String) -> GridState:
	var layout := load_runtime_layout(map_id)
	if layout == null:
		return null
	return build_grid_state_from_layout(layout)


static func build_grid_state_from_layout(layout: MapRuntimeLayout) -> GridState:
	if layout == null or layout.width <= 0 or layout.height <= 0:
		return null

	var grid := GridState.new()
	grid.initialize(layout.width, layout.height)

	for cell in layout.solid_cells:
		grid.set_static_cell(cell.x, cell.y, TileFactory.make_solid_wall())
	for cell in layout.breakable_cells:
		grid.set_static_cell(cell.x, cell.y, TileFactory.make_breakable_block())
	for cell in layout.mechanism_cells:
		grid.set_static_cell(cell.x, cell.y, TileFactory.make_mechanism())
	for index in range(layout.spawn_points.size()):
		var spawn: Vector2i = layout.spawn_points[index]
		grid.set_static_cell(spawn.x, spawn.y, TileFactory.make_spawn(index))

	return grid


static func has_map_metadata(map_id: String) -> bool:
	return load_runtime_layout(map_id) != null


static func load_map_resource(map_id: String) -> MapResource:
	if map_id.is_empty() or not MapCatalogScript.has_map(map_id):
		return null
	var resource_path := MapCatalogScript.get_map_path(map_id)
	if resource_path.is_empty() or not resource_path.ends_with(".tres"):
		return null
	var resource := load(resource_path)
	if resource == null or not resource is MapResource:
		push_error("MapLoader.load_map_resource failed: invalid map resource path=%s" % resource_path)
		return null
	return resource


static func _build_layout_from_resource(resource: MapResource) -> MapRuntimeLayout:
	if resource == null:
		return null
	var layout := MapRuntimeLayoutScript.new()
	layout.map_id = resource.map_id
	layout.display_name = resource.display_name
	layout.version = resource.version
	layout.width = resource.width
	layout.height = resource.height
	layout.solid_cells = resource.solid_cells.duplicate()
	layout.breakable_cells = resource.breakable_cells.duplicate()
	layout.mechanism_cells = resource.mechanism_cells.duplicate()
	layout.spawn_points = resource.spawn_points.duplicate()
	layout.item_spawn_profile_id = resource.item_spawn_profile_id
	layout.content_hash = resource.content_hash
	layout.tile_theme_id = resource.tile_theme_id
	layout.foreground_overlay_entries = resource.foreground_overlay_entries.duplicate(true)
	return layout if _validate_layout(layout) else null


static func _build_config_from_resource(resource: MapResource) -> Dictionary:
	if resource == null:
		return {}
	return {
		"map_id": resource.map_id,
		"display_name": resource.display_name,
		"width": resource.width,
		"height": resource.height,
		"tile_size": 32,
		"spawn_points": resource.spawn_points.duplicate(),
		"static_blocks": resource.solid_cells.duplicate(),
		"breakable_blocks": resource.breakable_cells.duplicate(),
		"foreground_overlay_entries": resource.foreground_overlay_entries.duplicate(true),
	}


static func _build_layout_from_metadata(metadata: Dictionary) -> MapRuntimeLayout:
	if metadata.is_empty():
		return null
	var layout := MapRuntimeLayoutScript.new()
	layout.map_id = String(metadata.get("map_id", ""))
	layout.display_name = String(metadata.get("display_name", ""))
	layout.version = int(metadata.get("version", 1))
	layout.width = int(metadata.get("width", 0))
	layout.height = int(metadata.get("height", 0))
	layout.spawn_points = metadata.get("spawn_points", []).duplicate()
	layout.item_spawn_profile_id = String(metadata.get("item_spawn_profile_id", "default_items"))
	layout.content_hash = String(metadata.get("content_hash", ""))
	return layout if _validate_layout(layout) else null


static func _build_layout_from_config(config: Dictionary) -> MapRuntimeLayout:
	if config.is_empty():
		return null
	var layout := MapRuntimeLayoutScript.new()
	layout.map_id = String(config.get("map_id", ""))
	layout.display_name = String(config.get("display_name", ""))
	layout.version = 1
	layout.width = int(config.get("width", 0))
	layout.height = int(config.get("height", 0))
	layout.solid_cells = _to_vector2i_array(config.get("static_blocks", []))
	layout.breakable_cells = _to_vector2i_array(config.get("breakable_blocks", []))
	layout.mechanism_cells = []
	layout.spawn_points = _to_vector2i_array(config.get("spawn_points", []))
	layout.item_spawn_profile_id = "default_items"
	layout.content_hash = "map_def_%s" % layout.map_id
	layout.tile_theme_id = ""
	return layout if _validate_layout(layout) else null


static func _validate_layout(layout: MapRuntimeLayout) -> bool:
	if layout == null:
		return false
	if layout.map_id.is_empty() or layout.width <= 0 or layout.height <= 0:
		return false
	if layout.content_hash.is_empty():
		return false
	if layout.spawn_points.is_empty():
		return false
	for cell in layout.solid_cells:
		if not _is_in_bounds(layout, cell):
			return false
	for cell in layout.breakable_cells:
		if not _is_in_bounds(layout, cell):
			return false
	for cell in layout.mechanism_cells:
		if not _is_in_bounds(layout, cell):
			return false
	for cell in layout.spawn_points:
		if not _is_in_bounds(layout, cell):
			return false
	return true


static func _is_in_bounds(layout: MapRuntimeLayout, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < layout.width and cell.y >= 0 and cell.y < layout.height


static func _validate_map_config(config: Dictionary) -> bool:
	var map_id := String(config.get("map_id", ""))
	var display_name := String(config.get("display_name", ""))
	var width := int(config.get("width", 0))
	var height := int(config.get("height", 0))
	var tile_size := int(config.get("tile_size", 0))

	if map_id.is_empty() or display_name.is_empty():
		return false
	if width <= 0 or height <= 0 or tile_size <= 0:
		return false
	if not config.has("spawn_points") or not config.has("static_blocks") or not config.has("breakable_blocks"):
		return false

	var spawn_points = config.get("spawn_points", [])
	var static_blocks = config.get("static_blocks", [])
	var breakable_blocks = config.get("breakable_blocks", [])
	if not (spawn_points is Array and static_blocks is Array and breakable_blocks is Array):
		return false
	if (spawn_points as Array).size() < 2:
		return false

	if not _all_cells_in_bounds(spawn_points as Array, width, height):
		return false
	if not _all_cells_in_bounds(static_blocks as Array, width, height):
		return false
	if not _all_cells_in_bounds(breakable_blocks as Array, width, height):
		return false
	if _has_overlap(static_blocks as Array, breakable_blocks as Array):
		return false
	return true


static func _all_cells_in_bounds(cells: Array, width: int, height: int) -> bool:
	for cell in cells:
		if not (cell is Vector2i):
			return false
		var pos: Vector2i = cell
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			return false
	return true


static func _has_overlap(a_cells: Array, b_cells: Array) -> bool:
	var occupied := {}
	for cell in a_cells:
		if cell is Vector2i:
			occupied[cell] = true
	for cell in b_cells:
		if cell is Vector2i and occupied.has(cell):
			return true
	return false


static func _to_vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value in values:
		if value is Vector2i:
			result.append(value)
	return result
