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
	var texture_size := _sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		_sprite.scale = Vector2.ONE
		return
	_sprite.scale = Vector2(cell_size / texture_size.x, cell_size / texture_size.y)
