class_name BreakableBlockView
extends Node2D

@onready var _sprite: Sprite2D = $Sprite2D


func set_texture(texture: Texture2D) -> void:
	if _sprite == null:
		return
	_sprite.texture = texture


func set_cell(cell: Vector2i, cell_size: float) -> void:
	position = Vector2(cell.x, cell.y) * cell_size
	if _sprite == null or _sprite.texture == null:
		return
	_sprite.centered = false
	_sprite.scale = Vector2.ONE
