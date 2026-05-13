class_name ItemPickupFxPlayer
extends Node2D

const ItemCatalogScript = preload("res://content/items/catalog/item_catalog.gd")

var _sprite: AnimatedSprite2D = null


func _ready() -> void:
	_ensure_sprite()


func configure(world_position: Vector2, cell_size: float, item_type: int) -> void:
	position = world_position
	_ensure_sprite()

	var entry := ItemCatalogScript.get_item_entry_by_type(item_type)
	var trigger_path := String(entry.get("trigger_anim_path", ""))
	if trigger_path.is_empty():
		queue_free()
		return

	var sprite_frames := _build_sprite_frames(trigger_path)
	if sprite_frames == null:
		queue_free()
		return

	_sprite.sprite_frames = sprite_frames
	_sprite.centered = true
	_sprite.play("trigger")
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)


func _build_sprite_frames(trigger_path: String) -> SpriteFrames:
	var dir := DirAccess.open(trigger_path)
	if dir == null:
		return null

	var frame_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".png"):
			frame_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if frame_files.is_empty():
		return null

	frame_files.sort()

	var sf := SpriteFrames.new()
	sf.add_animation("trigger")
	sf.set_animation_speed("trigger", 10.0)
	sf.set_animation_loop("trigger", false)

	for fn in frame_files:
		var texture_path := trigger_path + "/" + fn
		var texture := load(texture_path) as Texture2D
		if texture != null:
			sf.add_frame("trigger", texture)

	return sf


func _on_animation_finished() -> void:
	queue_free()


func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
