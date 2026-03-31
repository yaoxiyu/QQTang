class_name MapLoader
extends RefCounted

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapRuntimeLayoutScript = preload("res://content/maps/runtime/map_runtime_layout.gd")


static func load_map_metadata(map_id: String) -> Dictionary:
	var layout := load_runtime_layout(map_id)
	if layout == null:
		return {}
	return {
		"map_id": layout.map_id,
		"display_name": layout.display_name,
		"version": layout.version,
		"width": layout.width,
		"height": layout.height,
		"spawn_points": layout.spawn_points.duplicate(),
		"item_spawn_profile_id": layout.item_spawn_profile_id,
		"content_hash": layout.content_hash,
		"resource_path": MapCatalogScript.get_map_path(map_id),
	}


static func load_runtime_layout(map_id: String) -> MapRuntimeLayout:
	if map_id.is_empty() or not MapCatalogScript.has_map(map_id):
		return null

	var resource_path := MapCatalogScript.get_map_path(map_id)
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		return _build_layout_from_metadata(MapCatalogScript.get_map_metadata(map_id))

	var resource := load(resource_path)
	if resource is MapResource:
		return _build_layout_from_resource(resource)

	return _build_layout_from_metadata(MapCatalogScript.get_map_metadata(map_id))


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
	return layout if _validate_layout(layout) else null


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
