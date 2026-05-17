class_name PlayerIdentityMarkerSlotView
extends Node2D

const AnimDirSpriteFramesCacheScript = preload("res://presentation/battle/actors/anim_dir_sprite_frames_cache.gd")

const VISIBILITY_ALWAYS := "always"
const VISIBILITY_LOCAL_ONLY := "local_only"
const VISIBILITY_REMOTE_ONLY := "remote_only"
const VISIBILITY_TEAM_ONLY := "team_only"

const DEFAULT_ANIM_NAME := "stand"
const DEFAULT_ANIM_FPS := 10.0
const DEFAULT_OFFSET := Vector2(0.0, -0.95)

var marker_definitions: Array[Dictionary] = []

var _sprite: AnimatedSprite2D = null
var _active_marker_id: String = ""


func _ready() -> void:
	_ensure_sprite()


func set_marker_definitions(definitions: Array[Dictionary]) -> void:
	marker_definitions = definitions.duplicate(true)
	_active_marker_id = ""
	_ensure_sprite()
	_sprite.visible = false


func apply_actor_state(view_state: Dictionary) -> void:
	_ensure_sprite()
	var selected := _select_marker(view_state)
	if selected.is_empty():
		_sprite.visible = false
		_active_marker_id = ""
		return

	_apply_marker_visual(selected)
	_apply_marker_anchor(selected, view_state)


func _select_marker(view_state: Dictionary) -> Dictionary:
	if marker_definitions.is_empty():
		return {}
	for marker in marker_definitions:
		if _marker_matches(marker, view_state):
			return marker
	return {}


func _marker_matches(marker: Dictionary, view_state: Dictionary) -> bool:
	var visibility := String(marker.get("visibility", VISIBILITY_ALWAYS))
	var is_local_player := bool(view_state.get("is_local_player", false))
	match visibility:
		VISIBILITY_LOCAL_ONLY:
			if not is_local_player:
				return false
		VISIBILITY_REMOTE_ONLY:
			if is_local_player:
				return false
		VISIBILITY_TEAM_ONLY:
			var expected_team_ids: Array = marker.get("team_ids", [])
			if expected_team_ids.is_empty():
				return false
			var team_id := int(view_state.get("team_id", -1))
			if not expected_team_ids.has(team_id):
				return false
		_:
			pass

	var require_alive := bool(marker.get("require_alive", false))
	if require_alive and not bool(view_state.get("alive", true)):
		return false

	return true


func _apply_marker_visual(marker: Dictionary) -> void:
	var marker_id := String(marker.get("id", ""))
	var anim_dir := String(marker.get("anim_dir", ""))
	var anim_name := String(marker.get("anim_name", DEFAULT_ANIM_NAME))
	var fps := float(marker.get("fps", DEFAULT_ANIM_FPS))
	var loop := bool(marker.get("loop", true))

	if anim_dir.is_empty():
		_sprite.visible = false
		_active_marker_id = ""
		return

	if marker_id != _active_marker_id:
		var frames := AnimDirSpriteFramesCacheScript.load_frames(anim_dir, anim_name, fps, loop)
		if frames == null:
			_sprite.visible = false
			_active_marker_id = ""
			return
		_sprite.sprite_frames = frames
		_sprite.animation = anim_name
		_sprite.play(anim_name)
		_sprite.speed_scale = 1.0
		_active_marker_id = marker_id

	_sprite.visible = true


func _apply_marker_anchor(marker: Dictionary, view_state: Dictionary) -> void:
	var offset_cells: Vector2 = marker.get("offset_cells", DEFAULT_OFFSET)
	var cell_size := float(view_state.get("cell_size", 40.0))
	var actor_half_height_cells := float(view_state.get("actor_half_height_cells", 0.0))
	position = Vector2(
		offset_cells.x * cell_size,
		(offset_cells.y - actor_half_height_cells) * cell_size
	)

	z_as_relative = true
	z_index = int(marker.get("z_index", 20))


func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.visible = false
	add_child(_sprite)
