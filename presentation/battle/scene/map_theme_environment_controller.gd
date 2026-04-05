class_name MapThemeEnvironmentController
extends Node

@export var environment_root_path: NodePath = ^"../WorldRoot/EnvironmentRoot"

var _environment_root: Node = null
var _current_environment_instance: Node = null


func _ready() -> void:
	if has_node(environment_root_path):
		_environment_root = get_node(environment_root_path)


func apply_map_theme(map_theme: MapThemeDef) -> void:
	_ensure_environment_root()
	_clear_current_environment()
	if map_theme == null or map_theme.environment_scene == null or _environment_root == null:
		return

	var environment_instance := map_theme.environment_scene.instantiate()
	if environment_instance == null:
		return

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
