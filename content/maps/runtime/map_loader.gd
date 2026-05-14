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
		"match_format_id": String(map_metadata.get("match_format_id", "")),
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


static func build_airdrop_blocked_cells(map_id: String) -> Array[Vector2i]:
	var layout := load_runtime_layout(map_id)
	if layout == null:
		return []
	var blocked: Dictionary = {}
	# Surface footprint cells are not valid air-drop landing cells,
	# regardless of interaction semantics.
	for entry in layout.surface_entries:
		var footprint := entry.get("footprint", Vector2i.ONE) as Vector2i
		if footprint.x <= 0 or footprint.y <= 0:
			continue
		var anchor_cell := entry.get("cell", Vector2i.ZERO) as Vector2i
		var anchor_mode := String(entry.get("anchor_mode", "bottom_right"))
		for cell in _surface_footprint_cells(anchor_cell, footprint, anchor_mode):
			blocked["%d,%d" % [cell.x, cell.y]] = true
	# Channel cells are also blocked for air-drop landing.
	for entry in layout.channel_entries:
		var channel_cell := entry.get("cell", Vector2i.ZERO) as Vector2i
		blocked["%d,%d" % [channel_cell.x, channel_cell.y]] = true
	var result: Array[Vector2i] = []
	for key in blocked.keys():
		var key_str := String(key)
		var parts := key_str.split(",")
		result.append(Vector2i(int(parts[0]), int(parts[1])))
	return result


static func build_decorative_surface_cells(map_id: String) -> Array[Vector2i]:
	# Compatibility alias for legacy callers.
	return build_airdrop_blocked_cells(map_id)


static func _surface_footprint_cells(anchor: Vector2i, size: Vector2i, anchor_mode: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var left: int
	if anchor_mode == "center" or anchor_mode == "bottom_center":
		left = anchor.x - int(floorf(float(size.x - 1) / 2.0))
	elif anchor_mode == "bottom_left":
		left = anchor.x
	else:
		left = anchor.x - size.x + 1
	for fy in range(size.y):
		for fx in range(size.x):
			cells.append(Vector2i(left + fx, anchor.y - fy))
	return cells


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
	_apply_surface_entries_to_grid(grid, layout.surface_entries)
	_apply_channel_entries_to_grid(grid, layout.channel_entries)

	return grid


static func _apply_surface_entries_to_grid(grid: GridState, surface_entries: Array[Dictionary]) -> void:
	if grid == null or surface_entries.is_empty():
		return
	for entry in surface_entries:
		var interaction_kind := String(entry.get("interaction_kind", "solid"))
		if interaction_kind == "none":
			continue
		var anchor_cell := entry.get("cell", Vector2i.ZERO) as Vector2i
		var collision_footprint := entry.get("collision_footprint", Vector2i.ONE) as Vector2i
		var anchor_mode := _resolve_surface_anchor_mode(String(entry.get("anchor_mode", "bottom_right")))
		var movement_pass_mask := clampi(int(entry.get("movement_pass_mask", 0)), 0, 15)
		for cell in _anchored_rect_cells(anchor_cell, collision_footprint, anchor_mode):
			if not grid.is_in_bounds(cell.x, cell.y):
				continue
			grid.set_static_cell(cell.x, cell.y, _make_surface_collision_cell(interaction_kind, movement_pass_mask))


static func _apply_channel_entries_to_grid(grid: GridState, channel_entries: Array[Dictionary]) -> void:
	if grid == null or channel_entries.is_empty():
		return
	for entry in channel_entries:
		var cell := entry.get("cell", Vector2i.ZERO) as Vector2i
		if not grid.is_in_bounds(cell.x, cell.y):
			continue
		var movement_pass_mask := clampi(int(entry.get("movement_pass_mask", TileConstants.PASS_NONE)), 0, 15)
		var allow_place_bubble := bool(entry.get("allow_place_bubble", true))
		var static_cell := grid.get_static_cell(cell.x, cell.y)
		static_cell.movement_pass_mask = movement_pass_mask
		static_cell.allow_place_bubble = allow_place_bubble
		if movement_pass_mask == TileConstants.PASS_ALL:
			static_cell.tile_flags &= ~TileConstants.TILE_BLOCK_MOVE
		elif movement_pass_mask == TileConstants.PASS_NONE:
			static_cell.tile_flags |= TileConstants.TILE_BLOCK_MOVE
		grid.set_static_cell(cell.x, cell.y, static_cell)


static func _make_surface_collision_cell(interaction_kind: String, movement_pass_mask: int) -> CellStatic:
	if interaction_kind == "breakable":
		var cell := TileFactory.make_breakable_block()
		cell.movement_pass_mask = movement_pass_mask
		if movement_pass_mask == TileConstants.PASS_ALL:
			cell.tile_flags &= ~TileConstants.TILE_BLOCK_MOVE
		return cell
	var solid := TileFactory.make_solid_wall()
	solid.movement_pass_mask = movement_pass_mask
	if movement_pass_mask == TileConstants.PASS_ALL:
		solid.tile_flags &= ~TileConstants.TILE_BLOCK_MOVE
	return solid


static func _resolve_surface_anchor_mode(anchor_mode: String) -> String:
	if anchor_mode == "center":
		return "center"
	if anchor_mode == "bottom_center":
		return "bottom_center"
	if anchor_mode == "bottom_left":
		return "bottom_left"
	return "bottom_right"


static func _anchored_rect_cells(anchor_cell: Vector2i, size: Vector2i, anchor_mode: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if size.x <= 0 or size.y <= 0:
		return result
	var left := anchor_cell.x - int(floorf(float(size.x - 1) / 2.0))
	for fy in range(size.y):
		for fx in range(size.x):
			if anchor_mode == "bottom_left":
				result.append(Vector2i(anchor_cell.x + fx, anchor_cell.y - fy))
			elif anchor_mode == "bottom_center":
				result.append(Vector2i(left + fx, anchor_cell.y - fy))
			elif anchor_mode == "center":
				result.append(Vector2i(left + fx, anchor_cell.y - fy))
			else:
				result.append(Vector2i(anchor_cell.x - fx, anchor_cell.y - fy))
	return result


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
	layout.item_pool_id = resource.item_pool_id
	layout.content_hash = resource.content_hash
	layout.tile_theme_id = resource.tile_theme_id
	layout.floor_tile_entries = resource.floor_tile_entries.duplicate(true)
	layout.surface_entries = resource.surface_entries.duplicate(true)
	layout.channel_entries = resource.channel_entries.duplicate(true)
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
		"floor_tile_entries": resource.floor_tile_entries.duplicate(true),
		"surface_entries": resource.surface_entries.duplicate(true),
		"channel_entries": resource.channel_entries.duplicate(true),
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
	layout.item_pool_id = String(metadata.get("item_pool_id", "default_items"))
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
	layout.floor_tile_entries = []
	layout.surface_entries = []
	layout.channel_entries = []
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
	if layout.floor_tile_entries.is_empty():
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
