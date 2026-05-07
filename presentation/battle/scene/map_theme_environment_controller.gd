class_name MapThemeEnvironmentController
extends Node

const MapThemeMaterialRegistryScript = preload("res://presentation/battle/scene/map_theme_material_registry.gd")
const BattleViewMetrics = preload("res://presentation/battle/battle_view_metrics.gd")

@export var environment_root_path: NodePath = ^"../WorldRoot/EnvironmentRoot"

var _environment_root: Node = null
var _current_environment_instance: Node = null
var _current_background_sprite: Sprite2D = null


func _ready() -> void:
	if has_node(environment_root_path):
		_environment_root = get_node(environment_root_path)


func apply_map_theme(map_theme: MapThemeDef) -> void:
	_ensure_environment_root()
	_clear_current_environment()
	if map_theme == null or _environment_root == null:
		return

	_apply_environment_background(map_theme)
	if map_theme.environment_scene != null:
		var environment_instance := map_theme.environment_scene.instantiate()
		if environment_instance != null:
			_current_environment_instance = environment_instance
			_environment_root.add_child(_current_environment_instance)
			_apply_optional_theme_hooks(map_theme, _current_environment_instance)


func clear_environment() -> void:
	_clear_current_environment()


func _ensure_environment_root() -> void:
	if _environment_root != null and is_instance_valid(_environment_root):
		return
	if has_node(environment_root_path):
		_environment_root = get_node(environment_root_path)


func _clear_current_environment() -> void:
	if _current_background_sprite != null and is_instance_valid(_current_background_sprite):
		_current_background_sprite.queue_free()
	_current_background_sprite = null
	if _current_environment_instance == null:
		return
	if is_instance_valid(_current_environment_instance):
		_current_environment_instance.queue_free()
	_current_environment_instance = null


func _apply_optional_theme_hooks(map_theme: MapThemeDef, environment_instance: Node) -> void:
	if environment_instance.has_method("apply_theme"):
		environment_instance.call("apply_theme", map_theme)
	if environment_instance.has_method("apply_theme_metadata"):
		environment_instance.call("apply_theme_metadata", map_theme.theme_id, map_theme.tile_palette)


func _apply_environment_background(map_theme: MapThemeDef) -> void:
	var materials := MapThemeMaterialRegistryScript.get_theme_materials(String(map_theme.theme_id))
	var texture := materials.get("environment_background", null) as Texture2D
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "EnvironmentBackground"
	sprite.centered = false
	sprite.texture = texture
	sprite.position = Vector2.ZERO
	var texture_size := texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var background_size := BattleViewMetrics.DEFAULT_CELL_PIXELS * 7.0
		sprite.scale = Vector2(background_size / texture_size.x, background_size / texture_size.y)
	sprite.z_as_relative = false
	sprite.z_index = -100
	_current_background_sprite = sprite
	_environment_root.add_child(_current_background_sprite)
