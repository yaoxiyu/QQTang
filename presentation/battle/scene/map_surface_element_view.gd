class_name MapSurfaceElementView
extends Node2D

const FIT_CELL_WIDTH := "cell_width"
const FIT_CELL_SIZE := "cell_size"
const FIT_ORIGINAL := "original"
const DEFAULT_DIE_SECONDS := 0.36
const DEFAULT_EDGE_BLEED_PX := 1.0

var cell: Vector2i = Vector2i.ZERO
var footprint: Vector2i = Vector2i.ONE
var anchor_mode: String = "bottom_right"
var offset_px: Vector2 = Vector2.ZERO
var fit_mode: String = FIT_CELL_WIDTH
var cell_size: float = 40.0
var die_seconds: float = DEFAULT_DIE_SECONDS
var edge_bleed_px: float = DEFAULT_EDGE_BLEED_PX

var _sprite: Sprite2D = null
var _stand_texture: Texture2D = null
var _die_texture: Texture2D = null
var _is_dying: bool = false


func configure(entry: Dictionary, p_cell_size: float, stand_texture: Texture2D, die_texture: Texture2D = null) -> void:
	cell = entry.get("cell", Vector2i.ZERO) as Vector2i
	footprint = entry.get("footprint", Vector2i.ONE) as Vector2i
	anchor_mode = String(entry.get("anchor_mode", "bottom_right"))
	offset_px = entry.get("offset_px", Vector2.ZERO) as Vector2
	cell_size = max(p_cell_size, 1.0)
	die_seconds = max(float(entry.get("die_duration_sec", DEFAULT_DIE_SECONDS)), 0.01)
	fit_mode = _resolve_fit_mode(entry)
	edge_bleed_px = max(float(entry.get("edge_bleed_px", _default_edge_bleed_for_fit_mode(fit_mode))), 0.0)
	z_index = _calc_elem_z_index(cell.x, cell.y, footprint.y, int(entry.get("z_bias", 0)))
	_stand_texture = stand_texture
	_die_texture = die_texture
	_ensure_sprite()
	_apply_texture(_stand_texture)


func play_die_and_dispose() -> void:
	if _is_dying:
		return
	_is_dying = true
	if _die_texture != null:
		_apply_texture(_die_texture)
	var tween := create_tween()
	tween.tween_interval(die_seconds)
	tween.tween_callback(queue_free)


func debug_dump_layout() -> Dictionary:
	return {
		"cell": cell,
		"footprint": footprint,
		"fit_mode": fit_mode,
		"scale": _sprite.scale if _sprite != null else Vector2.ONE,
		"position": position,
		"has_die_texture": _die_texture != null,
		"texture_size": _sprite.texture.get_size() if _sprite != null and _sprite.texture != null else Vector2.ZERO,
		"edge_bleed_px": edge_bleed_px,
	}


func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _apply_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	_ensure_sprite()
	_sprite.texture = texture
	_sprite.scale = _resolve_texture_scale(texture)
	_apply_anchor(texture)


func _apply_anchor(texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	var scaled_size := texture_size * _sprite.scale
	var footprint_size := Vector2(float(maxi(footprint.x, 1)) * cell_size, float(maxi(footprint.y, 1)) * cell_size)
	var origin := Vector2(cell.x, cell.y) * cell_size
	match anchor_mode:
		"bottom_center":
			origin += Vector2((footprint_size.x - scaled_size.x) * 0.5, footprint_size.y - scaled_size.y)
		"bottom_left_of_footprint":
			origin += Vector2(0.0, footprint_size.y - scaled_size.y)
		"bottom_right":
			origin += Vector2(footprint_size.x - scaled_size.x, footprint_size.y - scaled_size.y)
		_:
			pass
	position = origin + offset_px


func _resolve_texture_scale(texture: Texture2D) -> Vector2:
	return Vector2.ONE


func _resolve_fit_mode(entry: Dictionary) -> String:
	var explicit_fit := String(entry.get("fit_mode", "")).strip_edges()
	if not explicit_fit.is_empty():
		return explicit_fit
	if String(entry.get("render_role", "surface")) == "occluder":
		return FIT_ORIGINAL
	return FIT_CELL_WIDTH


func _default_edge_bleed_for_fit_mode(resolved_fit_mode: String) -> float:
	if resolved_fit_mode == FIT_ORIGINAL:
		return 0.0
	return DEFAULT_EDGE_BLEED_PX


func _calc_elem_z_index(cell_x: int, cell_y: int, footprint_h: int = 1, z_bias: int = 0) -> int:
	var base_row := cell_y + footprint_h - 1
	return base_row * 100 - cell_x + z_bias
