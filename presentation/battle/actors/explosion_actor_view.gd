class_name BattleExplosionActorView
extends Node2D

const BubbleFxRegistryScript = preload("res://presentation/battle/fx/bubble_fx_registry.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const SEGMENT_TEXTURE_PATHS := {
	"center": "res://assets/animation/explosions/normal/segments/center.png",
	"arm_horizontal": "res://assets/animation/explosions/normal/segments/arm_horizontal.png",
	"arm_vertical": "res://assets/animation/explosions/normal/segments/arm_vertical.png",
	"tail_up": "res://assets/animation/explosions/normal/segments/tail_up.png",
	"tail_down": "res://assets/animation/explosions/normal/segments/tail_down.png",
	"tail_left": "res://assets/animation/explosions/normal/segments/tail_left.png",
	"tail_right": "res://assets/animation/explosions/normal/segments/tail_right.png",
}

var cell_size: float = BattleViewMetrics.DEFAULT_CELL_PIXELS
var covered_cells: Array[Vector2i] = []
var lifetime: float = 0.18
var bubble_style_id: String = ""
var bubble_color: Color = Color.WHITE
var _segment_textures: Dictionary = {}


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
		_build_segment_node(cell, segment_type, style)


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


func _build_segment_node(cell: Vector2i, segment_type: String, style: Dictionary) -> void:
	var texture := _get_segment_texture(segment_type)
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(cell.x, cell.y) * cell_size
	sprite.scale = _resolve_texture_scale(texture)
	sprite.modulate = _build_segment_modulate(segment_type, style)
	add_child(sprite)


func _get_segment_texture(segment_key: String) -> Texture2D:
	if _segment_textures.has(segment_key):
		return _segment_textures[segment_key]
	var path := String(SEGMENT_TEXTURE_PATHS.get(segment_key, ""))
	if path.is_empty():
		return null
	var tex := load(path) as Texture2D
	_segment_textures[segment_key] = tex
	return tex


func _resolve_texture_scale(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ONE
	return Vector2(cell_size / texture_size.x, cell_size / texture_size.y)


func _build_segment_modulate(segment_type: String, style: Dictionary) -> Color:
	var modulate := Color(style.get("fill_color", Color.WHITE))
	if segment_type.begins_with("tail_"):
		modulate.a *= float(style.get("tail_alpha", 0.72))
	elif segment_type == "center":
		modulate = modulate.lightened(0.12)
	return modulate
