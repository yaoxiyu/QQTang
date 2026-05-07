class_name BattleExplosionActorView
extends Node2D

const BubbleFxRegistryScript = preload("res://presentation/battle/fx/bubble_fx_registry.gd")
const BubbleLoaderScript = preload("res://content/bubbles/runtime/bubble_loader.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const SEGMENT_TEXTURE_PATHS := {
	"center": "res://assets/animation/explosions/normal/segments/center.png",
	"arm_right": "res://assets/animation/explosions/normal/segments/arm_right.png",
	"arm_up": "res://assets/animation/explosions/normal/segments/arm_up.png",
	"arm_left": "res://assets/animation/explosions/normal/segments/arm_left.png",
	"arm_down": "res://assets/animation/explosions/normal/segments/arm_down.png",
	"tail_up": "res://assets/animation/explosions/normal/segments/tail_up.png",
	"tail_down": "res://assets/animation/explosions/normal/segments/tail_down.png",
	"tail_left": "res://assets/animation/explosions/normal/segments/tail_left.png",
	"tail_right": "res://assets/animation/explosions/normal/segments/tail_right.png",
	"type2_cell": "res://assets/animation/explosions/normal/segments/type2_cell.png",
}
const SEGMENT_FRAME_BASES := {
	"center": "res://assets/animation/explosions/normal/segments/center",
	"arm_right": "res://assets/animation/explosions/normal/segments/arm_right",
	"arm_up": "res://assets/animation/explosions/normal/segments/arm_up",
	"arm_left": "res://assets/animation/explosions/normal/segments/arm_left",
	"arm_down": "res://assets/animation/explosions/normal/segments/arm_down",
	"tail_up": "res://assets/animation/explosions/normal/segments/tail_up",
	"tail_down": "res://assets/animation/explosions/normal/segments/tail_down",
	"tail_left": "res://assets/animation/explosions/normal/segments/tail_left",
	"tail_right": "res://assets/animation/explosions/normal/segments/tail_right",
	"type2_cell": "res://assets/animation/explosions/normal/segments/type2_cell",
}
const SEGMENT_ANIMATION_NAME := "default"
const SEGMENT_ANIMATION_FPS := 14.0

var cell_size: float = BattleViewMetrics.DEFAULT_CELL_PIXELS
var covered_cells: Array[Vector2i] = []
var lifetime: float = 0.18
var bubble_style_id: String = ""
var bubble_color: Color = Color.WHITE
var bubble_type: int = 1
var _segment_textures: Dictionary = {}
var _segment_frames_cache: Dictionary = {}


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
	bubble_type = _resolve_bubble_type(bubble_style_id)
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
	lifetime = max(float(style.get("lifetime", lifetime)), _max_segment_lifetime())
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
	if bubble_type == 2:
		return "type2_cell"
	if cell == center_cell:
		return "center"
	if cell.x == center_cell.x:
		if cell.y < center_cell.y:
			return "tail_up" if not covered_cells.has(cell + Vector2i.UP) else "arm_up"
		return "tail_down" if not covered_cells.has(cell + Vector2i.DOWN) else "arm_down"
	if cell.y == center_cell.y:
		if cell.x < center_cell.x:
			return "tail_left" if not covered_cells.has(cell + Vector2i.LEFT) else "arm_left"
		return "tail_right" if not covered_cells.has(cell + Vector2i.RIGHT) else "arm_right"
	return "center"


func _build_segment_node(cell: Vector2i, segment_type: String, style: Dictionary) -> void:
	var frames := _get_segment_frames(segment_type)
	if frames != null:
		var animated_sprite := AnimatedSprite2D.new()
		animated_sprite.sprite_frames = frames
		animated_sprite.animation = SEGMENT_ANIMATION_NAME
		animated_sprite.centered = false
		animated_sprite.position = Vector2(cell.x, cell.y) * cell_size
		var texture := frames.get_frame_texture(SEGMENT_ANIMATION_NAME, 0)
		animated_sprite.scale = _resolve_texture_scale(texture)
		animated_sprite.modulate = _build_segment_modulate(segment_type, style)
		add_child(animated_sprite)
		animated_sprite.play(SEGMENT_ANIMATION_NAME)
		return

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


func _get_segment_frames(segment_key: String) -> SpriteFrames:
	if _segment_frames_cache.has(segment_key):
		return _segment_frames_cache[segment_key]
	var base_path := String(SEGMENT_FRAME_BASES.get(segment_key, ""))
	if base_path.is_empty():
		_segment_frames_cache[segment_key] = null
		return null
	var frames := SpriteFrames.new()
	frames.clear_all()
	if not frames.has_animation(SEGMENT_ANIMATION_NAME):
		frames.add_animation(SEGMENT_ANIMATION_NAME)
	frames.set_animation_loop(SEGMENT_ANIMATION_NAME, false)
	frames.set_animation_speed(SEGMENT_ANIMATION_NAME, SEGMENT_ANIMATION_FPS)
	var loaded_count := 0
	for i in range(0, 32):
		var frame_path := "%s_%02d.png" % [base_path, i]
		if not ResourceLoader.exists(frame_path):
			break
		var texture := load(frame_path) as Texture2D
		if texture == null:
			break
		frames.add_frame(SEGMENT_ANIMATION_NAME, texture)
		loaded_count += 1
	if loaded_count <= 0:
		_segment_frames_cache[segment_key] = null
		return null
	_segment_frames_cache[segment_key] = frames
	return frames


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
	return Vector2.ONE


func _resolve_bubble_type(p_bubble_style_id: String) -> int:
	if p_bubble_style_id.strip_edges().is_empty():
		return 1
	var metadata := BubbleLoaderScript.load_metadata(p_bubble_style_id)
	return int(metadata.get("type", 1))


func _max_segment_lifetime() -> float:
	var max_frames := 1
	var keys := ["type2_cell"] if bubble_type == 2 else [
		"center",
		"arm_right",
		"arm_up",
		"arm_left",
		"arm_down",
		"tail_right",
		"tail_up",
		"tail_left",
		"tail_down",
	]
	for key in keys:
		var frames := _get_segment_frames(key)
		if frames == null:
			continue
		max_frames = maxi(max_frames, frames.get_frame_count(SEGMENT_ANIMATION_NAME))
	return float(max_frames) / SEGMENT_ANIMATION_FPS


func _build_segment_modulate(segment_type: String, style: Dictionary) -> Color:
	var modulate := Color.WHITE
	if segment_type.begins_with("tail_"):
		modulate.a *= float(style.get("tail_alpha", 0.72))
	return modulate
