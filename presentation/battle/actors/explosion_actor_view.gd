class_name BattleExplosionActorView
extends Node2D

const BubbleFxRegistryScript = preload("res://presentation/battle/fx/bubble_fx_registry.gd")

var cell_size: float = 48.0
var covered_cells: Array[Vector2i] = []
var lifetime: float = 0.18
var bubble_style_id: String = ""
var bubble_color: Color = Color.WHITE


func configure(
	p_cells: Array[Vector2i],
	p_cell_size: float,
	p_bubble_style_id: String = "",
	p_bubble_color: Color = Color.WHITE
) -> void:
	covered_cells = p_cells.duplicate()
	cell_size = p_cell_size
	bubble_style_id = p_bubble_style_id
	bubble_color = p_bubble_color
	_rebuild_cells()


func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _rebuild_cells() -> void:
	for child in get_children():
		child.queue_free()
	if covered_cells.is_empty():
		return

	var style := BubbleFxRegistryScript.get_explosion_style(bubble_style_id, bubble_color)
	lifetime = float(style.get("lifetime", lifetime))
	var center_cell := _resolve_center_cell()

	for cell in covered_cells:
		var segment_type := _resolve_segment_type(cell, center_cell)
		var segment_root := Node2D.new()
		segment_root.position = Vector2(cell.x, cell.y) * cell_size
		add_child(segment_root)

		var fill := Polygon2D.new()
		fill.polygon = _build_segment_polygon(segment_type)
		fill.color = _build_segment_fill_color(segment_type, style)
		segment_root.add_child(fill)

		var outline := Line2D.new()
		outline.default_color = Color(style.get("outline_color", Color.WHITE))
		outline.width = 2.0
		outline.closed = true
		outline.points = fill.polygon
		segment_root.add_child(outline)

		var core := Polygon2D.new()
		core.polygon = _build_segment_core_polygon(segment_type)
		core.color = Color(style.get("core_color", Color.WHITE))
		segment_root.add_child(core)


func _resolve_center_cell() -> Vector2i:
	if covered_cells.is_empty():
		return Vector2i.ZERO
	var center_cell := covered_cells[0]
	for cell in covered_cells:
		if _neighbor_count(cell) > _neighbor_count(center_cell):
			center_cell = cell
	return center_cell


func _neighbor_count(cell: Vector2i) -> int:
	var count := 0
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for direction in directions:
		if covered_cells.has(cell + direction):
			count += 1
	return count


func _resolve_segment_type(cell: Vector2i, center_cell: Vector2i) -> String:
	if cell == center_cell:
		return "center"
	if cell.x == center_cell.x:
		if cell.y < center_cell.y:
			return "tail_up" if not covered_cells.has(cell + Vector2i.UP) else "arm_vertical"
		return "tail_down" if not covered_cells.has(cell + Vector2i.DOWN) else "arm_vertical"
	if cell.y == center_cell.y:
		if cell.x < center_cell.x:
			return "tail_left" if not covered_cells.has(cell + Vector2i.LEFT) else "arm_horizontal"
		return "tail_right" if not covered_cells.has(cell + Vector2i.RIGHT) else "arm_horizontal"
	return "center"


func _build_segment_polygon(segment_type: String) -> PackedVector2Array:
	var min_edge := cell_size * 0.18
	var max_edge := cell_size * 0.82
	var center_band_min := cell_size * 0.34
	var center_band_max := cell_size * 0.66
	match segment_type:
		"center":
			return PackedVector2Array([
				Vector2(center_band_min, min_edge),
				Vector2(center_band_max, min_edge),
				Vector2(max_edge, center_band_min),
				Vector2(max_edge, center_band_max),
				Vector2(center_band_max, max_edge),
				Vector2(center_band_min, max_edge),
				Vector2(min_edge, center_band_max),
				Vector2(min_edge, center_band_min),
			])
		"arm_horizontal":
			return PackedVector2Array([
				Vector2(min_edge, center_band_min),
				Vector2(max_edge, center_band_min),
				Vector2(max_edge, center_band_max),
				Vector2(min_edge, center_band_max),
			])
		"arm_vertical":
			return PackedVector2Array([
				Vector2(center_band_min, min_edge),
				Vector2(center_band_max, min_edge),
				Vector2(center_band_max, max_edge),
				Vector2(center_band_min, max_edge),
			])
		"tail_up":
			return PackedVector2Array([
				Vector2(cell_size * 0.5, min_edge),
				Vector2(center_band_max, cell_size * 0.28),
				Vector2(center_band_max, max_edge),
				Vector2(center_band_min, max_edge),
				Vector2(center_band_min, cell_size * 0.28),
			])
		"tail_down":
			return PackedVector2Array([
				Vector2(center_band_min, min_edge),
				Vector2(center_band_max, min_edge),
				Vector2(center_band_max, cell_size * 0.72),
				Vector2(cell_size * 0.5, max_edge),
				Vector2(center_band_min, cell_size * 0.72),
			])
		"tail_left":
			return PackedVector2Array([
				Vector2(min_edge, cell_size * 0.5),
				Vector2(cell_size * 0.28, center_band_min),
				Vector2(max_edge, center_band_min),
				Vector2(max_edge, center_band_max),
				Vector2(cell_size * 0.28, center_band_max),
			])
		"tail_right":
			return PackedVector2Array([
				Vector2(min_edge, center_band_min),
				Vector2(cell_size * 0.72, center_band_min),
				Vector2(max_edge, cell_size * 0.5),
				Vector2(cell_size * 0.72, center_band_max),
				Vector2(min_edge, center_band_max),
			])
		_:
			return PackedVector2Array([
				Vector2(0, 0),
				Vector2(cell_size, 0),
				Vector2(cell_size, cell_size),
				Vector2(0, cell_size),
			])


func _build_segment_core_polygon(segment_type: String) -> PackedVector2Array:
	var center_band_min := cell_size * 0.40
	var center_band_max := cell_size * 0.60
	match segment_type:
		"center":
			return PackedVector2Array([
				Vector2(cell_size * 0.5, cell_size * 0.22),
				Vector2(cell_size * 0.78, cell_size * 0.5),
				Vector2(cell_size * 0.5, cell_size * 0.78),
				Vector2(cell_size * 0.22, cell_size * 0.5),
			])
		"arm_horizontal":
			return PackedVector2Array([
				Vector2(cell_size * 0.22, center_band_min),
				Vector2(cell_size * 0.78, center_band_min),
				Vector2(cell_size * 0.78, center_band_max),
				Vector2(cell_size * 0.22, center_band_max),
			])
		"arm_vertical":
			return PackedVector2Array([
				Vector2(center_band_min, cell_size * 0.22),
				Vector2(center_band_max, cell_size * 0.22),
				Vector2(center_band_max, cell_size * 0.78),
				Vector2(center_band_min, cell_size * 0.78),
			])
		"tail_up":
			return PackedVector2Array([
				Vector2(cell_size * 0.5, cell_size * 0.30),
				Vector2(center_band_max, cell_size * 0.46),
				Vector2(center_band_min, cell_size * 0.46),
			])
		"tail_down":
			return PackedVector2Array([
				Vector2(center_band_min, cell_size * 0.54),
				Vector2(center_band_max, cell_size * 0.54),
				Vector2(cell_size * 0.5, cell_size * 0.70),
			])
		"tail_left":
			return PackedVector2Array([
				Vector2(cell_size * 0.30, cell_size * 0.5),
				Vector2(cell_size * 0.46, center_band_min),
				Vector2(cell_size * 0.46, center_band_max),
			])
		"tail_right":
			return PackedVector2Array([
				Vector2(cell_size * 0.54, center_band_min),
				Vector2(cell_size * 0.70, cell_size * 0.5),
				Vector2(cell_size * 0.54, center_band_max),
			])
		_:
			return PackedVector2Array([
				Vector2(cell_size * 0.25, cell_size * 0.25),
				Vector2(cell_size * 0.75, cell_size * 0.25),
				Vector2(cell_size * 0.75, cell_size * 0.75),
				Vector2(cell_size * 0.25, cell_size * 0.75),
			])


func _build_segment_fill_color(segment_type: String, style: Dictionary) -> Color:
	var fill_color := Color(style.get("fill_color", Color.WHITE))
	if segment_type.begins_with("tail_"):
		fill_color.a *= float(style.get("tail_alpha", 0.72))
	elif segment_type == "center":
		fill_color = fill_color.lightened(0.12)
	return fill_color
