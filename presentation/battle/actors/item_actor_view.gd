class_name BattleItemActorView
extends Node2D

const ItemCatalogScript = preload("res://content/items/catalog/item_catalog.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")
const ROW_Z_STEP := 100
const ITEM_Z_BIAS := 30

var item_id: int = -1
var item_type: int = 0
var item_color: Color = Color(1.0, 0.9, 0.2, 1.0)
var cell_size_px: float = BattleViewMetrics.DEFAULT_CELL_PIXELS
var size_px: float = BattleViewMetrics.item_half_size_px()

var _icon_sprite: Sprite2D = null
var _fallback_body: Polygon2D = null
var _fallback_outline: Line2D = null


func _ready() -> void:
	_ensure_visuals()
	_refresh_visuals()


func apply_view_state(view_state: Dictionary) -> void:
	item_id = int(view_state.get("entity_id", -1))
	item_type = int(view_state.get("item_type", 0))
	cell_size_px = float(view_state.get("cell_size", cell_size_px))
	size_px = BattleViewMetrics.item_half_size_px(cell_size_px)
	position = view_state.get("position", Vector2.ZERO)
	item_color = view_state.get("color", item_color)
	z_as_relative = false
	z_index = _calc_dynamic_z_index(view_state, ITEM_Z_BIAS)
	_refresh_visuals()


func _calc_dynamic_z_index(view_state: Dictionary, z_bias: int) -> int:
	var cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
	return cell.y * ROW_Z_STEP - cell.x + z_bias


func _ensure_visuals() -> void:
	if _icon_sprite == null:
		_icon_sprite = Sprite2D.new()
		_icon_sprite.centered = true
		_icon_sprite.visible = false
		add_child(_icon_sprite)
	if _fallback_body == null:
		_fallback_body = Polygon2D.new()
		add_child(_fallback_body)
	if _fallback_outline == null:
		_fallback_outline = Line2D.new()
		_fallback_outline.default_color = Color.BLACK
		_fallback_outline.width = 2.0
		add_child(_fallback_outline)


func _refresh_visuals() -> void:
	_ensure_visuals()
	var icon := _resolve_item_icon(item_type)
	if icon != null:
		_icon_sprite.texture = icon
		_icon_sprite.scale = _resolve_icon_scale(icon)
		_icon_sprite.visible = true
		_fallback_body.visible = false
		_fallback_outline.visible = false
		return

	_icon_sprite.texture = null
	_icon_sprite.visible = false
	_fallback_body.visible = true
	_fallback_outline.visible = true

	var points := PackedVector2Array([
		Vector2(0, -size_px),
		Vector2(size_px, 0),
		Vector2(0, size_px),
		Vector2(-size_px, 0)
	])
	_fallback_body.polygon = points
	_fallback_body.color = item_color
	var outline_points := PackedVector2Array(points)
	outline_points.append(points[0])
	_fallback_outline.points = outline_points


func _resolve_item_icon(resolved_item_type: int) -> Texture2D:
	var entry := ItemCatalogScript.get_item_entry_by_type(resolved_item_type)
	var icon_path := String(entry.get("icon_path", ""))
	if icon_path.is_empty():
		return null
	var texture := load(icon_path)
	return texture as Texture2D


func _resolve_icon_scale(icon: Texture2D) -> Vector2:
	if icon == null:
		return Vector2.ONE
	var texture_size := icon.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ONE
	var target_size := size_px * 2.2
	var max_dimension : float = max(texture_size.x, texture_size.y)
	var scale_factor : float = target_size / max_dimension
	return Vector2.ONE * scale_factor
