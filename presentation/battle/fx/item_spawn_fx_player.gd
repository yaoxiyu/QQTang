class_name ItemSpawnFxPlayer
extends Node2D

const ItemCatalogScript = preload("res://content/items/catalog/item_catalog.gd")

var _icon_sprite: Sprite2D = null
var _diamond: Polygon2D = null


func _ready() -> void:
	_ensure_visuals()


func configure(world_position: Vector2, cell_size: float, item_type: int) -> void:
	position = world_position
	_ensure_visuals()
	_apply_item_visual(cell_size, item_type, 0.18, 0.80)
	scale = Vector2(0.3, 0.3)
	modulate = Color(1, 1, 1, 0.2)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14)
	tween.tween_property(self, "modulate:a", 1.0, 0.14)
	tween.finished.connect(queue_free)


func _ensure_visuals() -> void:
	if _icon_sprite == null:
		_icon_sprite = Sprite2D.new()
		_icon_sprite.centered = true
		_icon_sprite.visible = false
		add_child(_icon_sprite)
	if _diamond == null:
		_diamond = Polygon2D.new()
		add_child(_diamond)


func _apply_item_visual(cell_size: float, item_type: int, diamond_ratio: float, icon_ratio: float) -> void:
	var icon := _resolve_item_icon(item_type)
	if icon != null:
		_icon_sprite.texture = icon
		_icon_sprite.scale = _resolve_icon_scale(icon, cell_size, icon_ratio)
		_icon_sprite.visible = true
		_diamond.visible = false
		return
	_icon_sprite.texture = null
	_icon_sprite.visible = false
	_diamond.visible = true
	var half: float = max(cell_size * diamond_ratio, 6.0)
	_diamond.polygon = PackedVector2Array([
		Vector2(0, -half),
		Vector2(half, 0),
		Vector2(0, half),
		Vector2(-half, 0),
	])
	_diamond.color = _resolve_item_color(item_type)


func _resolve_item_icon(item_type: int) -> Texture2D:
	var entry := ItemCatalogScript.get_item_entry_by_type(item_type)
	var icon_path := String(entry.get("icon_path", ""))
	if icon_path.is_empty():
		return null
	return load(icon_path) as Texture2D


func _resolve_icon_scale(icon: Texture2D, cell_size: float, icon_ratio: float) -> Vector2:
	if icon == null:
		return Vector2.ONE
	var texture_size := icon.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ONE
	var target_size : float = max(cell_size * icon_ratio, 10.0)
	var scale_factor : float = target_size / max(texture_size.x, texture_size.y)
	return Vector2.ONE * scale_factor


func _resolve_item_color(item_type: int) -> Color:
	match item_type:
		1:
			return Color(1.0, 0.6, 0.2, 0.85)
		2:
			return Color(0.95, 0.92, 0.35, 0.85)
		3:
			return Color(0.35, 0.92, 0.45, 0.85)
		4:
			return Color(0.45, 0.75, 1.0, 0.85)
		_:
			return Color(1.0, 1.0, 1.0, 0.85)
